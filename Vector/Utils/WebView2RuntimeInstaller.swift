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

// swiftlint:disable:next type_body_length
enum WebView2RuntimeInstaller {
    typealias ProgressHandler = (String) async -> Void

    private static let installerDownloadURL: URL = {
        guard let url = URL(string: "https://go.microsoft.com/fwlink/?LinkId=2124701") else {
            fatalError("Invalid WebView2 installer URL")
        }
        return url
    }()
    private static let installerFileName = "MicrosoftEdgeWebView2RuntimeInstallerX64.exe"
    private static let downloadTimeout: TimeInterval = 120
    private static let installerTimeout: TimeInterval = 300
    private static let wineserverTimeout: TimeInterval = 25

    private static var cacheDirectory: URL {
        VectorWineInstaller.libraryFolder
            .appending(path: "Installers")
            .appending(path: "WebView2")
    }

    private static var cachedInstallerURL: URL {
        cacheDirectory.appending(path: installerFileName)
    }

    static func installIfNeeded(
        for bottle: Bottle,
        progress: ProgressHandler? = nil
    ) async throws -> WebView2RuntimeInstallResult {
        await progress?("Checking for an existing WebView2 runtime")
        if hasRuntime(in: bottle) {
            await progress?("WebView2 runtime is already installed")
            return .alreadyInstalled
        }

        let installerURL = try await cachedInstaller(progress: progress)
        let environment = runtimeOverrideEnvironment()
        await progress?("Stopping stale Wine services before WebView2 setup")
        await shutDownKnownWineservers(for: bottle)

        await progress?("Running the WebView2 installer")
        try await withTimeout(seconds: installerTimeout, reason: "WebView2 installer timed out.") {
            _ = try await Wine.runWine(
                [installerURL.path(percentEncoded: false), "/silent", "/install"],
                bottle: bottle,
                environment: environment,
                collectOutput: false
            )
        }
        await progress?("Waiting for WebView2 setup to finish")
        try await waitForInstallerCompletion(for: bottle, environment: environment)

        await progress?("Validating WebView2 runtime installation")
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

    private static func cachedInstaller(progress: ProgressHandler?) async throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        if isUsableCachedInstaller(cachedInstallerURL) {
            await progress?("Using cached WebView2 installer")
            return cachedInstallerURL
        }

        await progress?("Downloading WebView2 runtime installer")
        let request = URLRequest(
            url: installerDownloadURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: downloadTimeout
        )
        let (temporaryURL, response) = try await URLSession(configuration: .ephemeral).download(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<400).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "Vector.WebView2RuntimeInstaller",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to download WebView2 installer."]
            )
        }
        if fileManager.fileExists(atPath: cachedInstallerURL.path(percentEncoded: false)) {
            try fileManager.removeItem(at: cachedInstallerURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: cachedInstallerURL)
        guard isUsableCachedInstaller(cachedInstallerURL) else {
            throw NSError(
                domain: "Vector.WebView2RuntimeInstaller",
                code: 3,
                userInfo: [
                    NSLocalizedDescriptionKey: "Downloaded WebView2 installer was incomplete or not executable."
                ]
            )
        }
        return cachedInstallerURL
    }

    private static func isUsableCachedInstaller(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize else {
            return false
        }
        guard fileSize > 1_000_000,
              let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer {
            try? fileHandle.close()
        }

        guard let header = try? fileHandle.read(upToCount: 2) else {
            return false
        }
        return header == Data([0x4D, 0x5A])
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

    private static func waitForInstallerCompletion(for bottle: Bottle, environment: [String: String]) async throws {
        try await withTimeout(seconds: wineserverTimeout, reason: "WebView2 wineserver wait timed out.") {
            await runWineserver(["-w"], bottle: bottle, environment: environment)
        }
    }

    private static func runWineserver(_ args: [String], bottle: Bottle, environment: [String: String]) async {
        do {
            try await withTimeout(seconds: wineserverTimeout, reason: "wineserver timed out.") {
                guard let stream = try? Wine.runWineserverProcess(
                    args: args,
                    bottle: bottle,
                    environment: environment
                ) else {
                    return
                }

                for await _ in stream { }
            }
        } catch {
            return
        }
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

    private static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        reason: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(
                    domain: "Vector.WebView2RuntimeInstaller",
                    code: 408,
                    userInfo: [NSLocalizedDescriptionKey: reason]
                )
            }

            guard let result = try await group.next() else {
                throw NSError(
                    domain: "Vector.WebView2RuntimeInstaller",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "WebView2 installer task ended unexpectedly."]
                )
            }
            group.cancelAll()
            return result
        }
    }
}
