//
//  WebView2RuntimeInstaller.swift
//  Vector
//
//  This file is part of Vector.
//
//  Vector is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Vector is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Vector.
//  If not, see https://www.gnu.org/licenses/.
//

import Foundation
import VectorKit

enum WebView2RuntimeInstallResult: Sendable {
    case alreadyInstalled
    case installed

    var note: String {
        switch self {
        case .alreadyInstalled:
            return "WebView2 runtime already installed"
        case .installed:
            return "downloaded and installed WebView2 runtime"
        }
    }
}

enum WebView2RuntimeInstaller {
    private static let installerDownloadURL: URL = {
        guard let url = URL(string: "https://go.microsoft.com/fwlink/?LinkId=2124701") else {
            fatalError("Invalid WebView2 installer URL")
        }
        return url
    }()
    private static let installerFileName = "MicrosoftEdgeWebView2RuntimeInstallerX64.exe"

    private static var cacheDirectory: URL {
        VectorWineInstaller.libraryFolder
            .appending(path: "Installers")
            .appending(path: "WebView2")
    }

    private static var cachedInstallerURL: URL {
        cacheDirectory.appending(path: installerFileName)
    }

    static func installIfNeeded(for bottle: Bottle) async throws -> WebView2RuntimeInstallResult {
        if hasRuntime(in: bottle) {
            return .alreadyInstalled
        }

        let installerURL = try await cachedInstaller()
        let environment = runtimeOverrideEnvironment()
        await shutDownKnownWineservers(for: bottle)

        _ = try await Wine.runWine(
            [installerURL.path(percentEncoded: false), "/silent", "/install"],
            bottle: bottle,
            environment: environment,
            collectOutput: false
        )
        await waitForInstallerCompletion(for: bottle, environment: environment)

        guard hasRuntime(in: bottle) else {
            throw NSError(
                domain: "Vector.WebView2RuntimeInstaller",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "WebView2 installer completed, but no runtime installation was detected."
                ]
            )
        }

        return .installed
    }

    private static func cachedInstaller() async throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        if isUsableCachedInstaller(cachedInstallerURL) {
            return cachedInstallerURL
        }

        let (temporaryURL, _) = try await URLSession.shared.download(from: installerDownloadURL)
        if fileManager.fileExists(atPath: cachedInstallerURL.path(percentEncoded: false)) {
            try fileManager.removeItem(at: cachedInstallerURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: cachedInstallerURL)
        return cachedInstallerURL
    }

    private static func isUsableCachedInstaller(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize else {
            return false
        }
        return fileSize > 1_000_000
    }

    private static func runtimeOverrideEnvironment() -> [String: String] {
        guard let wine = VectorWineInstaller.steamCompatibilityWineBinary(),
              let wineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() else {
            return [:]
        }

        return [
            "VECTOR_WINE_BIN_OVERRIDE": wine.path(percentEncoded: false),
            "VECTOR_WINESERVER_BIN_OVERRIDE": wineserver.path(percentEncoded: false)
        ]
    }

    private static func shutDownKnownWineservers(for bottle: Bottle) async {
        for wineserver in wineserverCandidates(for: bottle) {
            let environment = [
                "VECTOR_WINESERVER_BIN_OVERRIDE": wineserver.path(percentEncoded: false)
            ]
            await runWineserver(["-k"], bottle: bottle, environment: environment)
            await runWineserver(["-w"], bottle: bottle, environment: environment)
        }
    }

    private static func waitForInstallerCompletion(for bottle: Bottle, environment: [String: String]) async {
        await runWineserver(["-w"], bottle: bottle, environment: environment)
    }

    private static func runWineserver(_ args: [String], bottle: Bottle, environment: [String: String]) async {
        guard let stream = try? Wine.runWineserverProcess(args: args, bottle: bottle, environment: environment) else {
            return
        }

        for await _ in stream { }
    }

    private static func wineserverCandidates(for bottle: Bottle) -> [URL] {
        var candidates = [
            VectorWineInstaller.binFolder.appending(path: "wineserver")
        ]

        if let compatibilityWineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() {
            candidates.append(compatibilityWineserver)
        }

        if let crossOverWineserver = VectorWineInstaller.crossOverWineserverBinary() {
            candidates.append(crossOverWineserver)
        }

        let customPath = bottle.settings.customWineserverBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !customPath.isEmpty {
            candidates.append(URL(filePath: customPath))
        }

        var seenPaths = Set<String>()
        return candidates.filter { candidate in
            let path = candidate.path(percentEncoded: false)
            guard !seenPaths.contains(path) else {
                return false
            }
            seenPaths.insert(path)
            return true
        }
    }

    static func hasRuntime(in bottle: Bottle) -> Bool {
        runtimeSearchRoots(for: bottle).contains { root in
            containsWebView2Executable(in: root)
        }
    }

    private static func runtimeSearchRoots(for bottle: Bottle) -> [URL] {
        let driveC = bottle.url.appending(path: "drive_c")
        var roots = [
            driveC
                .appending(path: "Program Files (x86)")
                .appending(path: "Microsoft")
                .appending(path: "EdgeWebView")
                .appending(path: "Application"),
            driveC
                .appending(path: "Program Files")
                .appending(path: "Microsoft")
                .appending(path: "EdgeWebView")
                .appending(path: "Application"),
            driveC
                .appending(path: "Program Files (x86)")
                .appending(path: "Microsoft")
                .appending(path: "EdgeCore"),
            driveC
                .appending(path: "Program Files")
                .appending(path: "Microsoft")
                .appending(path: "EdgeCore")
        ]

        let usersRoot = driveC.appending(path: "users")
        if let users = try? FileManager.default.contentsOfDirectory(
            at: usersRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            roots.append(contentsOf: users.map { user in
                user
                    .appending(path: "AppData")
                    .appending(path: "Local")
                    .appending(path: "Microsoft")
                    .appending(path: "EdgeWebView")
                    .appending(path: "Application")
            })
        }

        return roots
    }

    private static func containsWebView2Executable(in root: URL) -> Bool {
        guard let versionDirectories = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        return versionDirectories.contains { versionDirectory in
            let versionName = versionDirectory.lastPathComponent
            guard isVersionDirectoryName(versionName) else {
                return false
            }

            let executableNames = ["msedgewebview2.exe", "msedge.exe"]
            return executableNames.contains { executableName in
                FileManager.default.fileExists(
                    atPath: versionDirectory.appending(path: executableName).path(percentEncoded: false)
                )
            }
        }
    }

    private static func isVersionDirectoryName(_ name: String) -> Bool {
        guard name.first?.isNumber == true, name.contains(".") else {
            return false
        }

        return name.allSatisfy { character in
            character.isNumber || character == "."
        }
    }
}
