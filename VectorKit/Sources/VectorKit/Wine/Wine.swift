//
//  Wine.swift
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

import CryptoKit
import Foundation
import os.log
// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
public class Wine {
    private static let wineBinaryOverrideEnvironmentKey = "VECTOR_WINE_BIN_OVERRIDE"
    private static let wineserverBinaryOverrideEnvironmentKey = "VECTOR_WINESERVER_BIN_OVERRIDE"
    static let steamGraphicsIsolationEnvKey =
        "VECTOR_STEAM_CLIENT_DISABLE_GRAPHICS_OVERRIDES"
    private static let dxmtNVExtensionsEnvironmentKey = "DXMT_ENABLE_NVEXT"
    private static let dlssTranslationMarkerEnvironmentKey = "VECTOR_DLSS_TRANSLATION_ACTIVE"
    private static let wineDebugLevelDefaultsKey = "wineDebugLevel"
    private static let fallbackWineDebugLevel = "-all"
    private static let dxvkStateCacheFolderName = "DXVKStateCache"
    // Keep this list intentionally narrow to avoid stomping bottle-managed runtimes.
    private static let runtimeSystemDLLMirrorAllowList = [
        "dxgi.dll",
        "d3d11.dll",
        "d3d10core.dll",
        "d3d9.dll",
        "d3d12.dll",
        "d3d12core.dll",
        "vulkan-1.dll",
        // Media playback stack used by intros/cutscenes in many titles.
        "mf.dll",
        "mfplat.dll",
        "mfreadwrite.dll",
        "mfplay.dll",
        "evr.dll",
        "quartz.dll",
        "devenum.dll",
        "wmvcore.dll",
        "msmpeg2vdec.dll",
        "msmpeg2adec.dll",
        "winegstreamer.dll"
    ]
    private static let dxmtFallbackReleaseVersion = "v0.74"
    private static let dxmtFallbackPayloadURL: URL = {
        guard let url = URL(
            string: "https://github.com/3Shain/dxmt/releases/download/v0.74/dxmt-v0.74-builtin.tar.gz"
        ) else {
            fatalError("Invalid DXMT fallback payload URL")
        }
        return url
    }()
    private static let dxmtLatestReleaseAPIURL: URL = {
        guard let url = URL(string: "https://api.github.com/repos/3Shain/dxmt/releases/latest") else {
            fatalError("Invalid DXMT latest release API URL")
        }
        return url
    }()
    private static let dxmtInstallCoordinator = DXMTPayloadInstallCoordinator()
    private static let steamClientGraphicsDLLOverrideNames: Set<String> = [
        "dxgi",
        "d3d9",
        "d3d10",
        "d3d10core",
        "d3d11",
        "d3d12",
        "d3d12core",
        "nvapi",
        "nvapi64"
    ]

    /// URL to the installed `DXVK` folder
    private static let dxvkFolder: URL = VectorWineInstaller.libraryFolder.appending(path: "DXVK")
    /// URL to the installed `DXMT` payload folder
    private static let dxmtFolder: URL = VectorWineInstaller.libraryFolder.appending(path: "DXMT")
    /// Path to the `wine64` binary
    public static let wineBinary: URL = VectorWineInstaller.binFolder.appending(path: "wine64")
    /// Parth to the `wineserver` binary
    private static let wineserverBinary: URL = VectorWineInstaller.binFolder.appending(path: "wineserver")
    /// Run a process on a executable file given by the `executableURL`
    private static func runProcess(
        name: String? = nil, args: [String], environment: [String: String], executableURL: URL, directory: URL? = nil,
        fileHandle: FileHandle?
    ) throws -> AsyncStream<ProcessOutput> {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = args
        process.currentDirectoryURL = directory ?? executableURL.deletingLastPathComponent()
        process.environment = environment
        process.qualityOfService = .userInitiated

        return try process.runStream(
            name: name ?? args.joined(separator: " "), fileHandle: fileHandle
        )
    }

    /// Run a `wine` process with the given arguments and environment variables returning a stream of output
    private static func runWineProcess(
        name: String? = nil, args: [String], environment: [String: String] = [:],
        directory: URL? = nil, fileHandle: FileHandle?
    ) throws -> AsyncStream<ProcessOutput> {
        var environment = environment
        let executableURL = resolveExecutable(
            from: &environment,
            overrideKey: wineBinaryOverrideEnvironmentKey,
            fallback: wineBinary
        )

        return try runProcess(
            name: name, args: args, environment: environment, executableURL: executableURL,
            directory: directory, fileHandle: fileHandle
        )
    }

    /// Run a `wineserver` process with the given arguments and environment variables returning a stream of output
    private static func runWineserverProcess(
        name: String? = nil, args: [String], environment: [String: String] = [:],
        fileHandle: FileHandle?
    ) throws -> AsyncStream<ProcessOutput> {
        var environment = environment
        let executableURL = resolveExecutable(
            from: &environment,
            overrideKey: wineserverBinaryOverrideEnvironmentKey,
            fallback: wineserverBinary
        )

        return try runProcess(
            name: name, args: args, environment: environment, executableURL: executableURL,
            fileHandle: fileHandle
        )
    }

    /// Run a `wine` process with the given arguments and environment variables returning a stream of output
    public static func runWineProcess(
        name: String? = nil, args: [String], bottle: Bottle, environment: [String: String] = [:],
        directory: URL? = nil
    ) throws -> AsyncStream<ProcessOutput> {
        let fileHandle = try makeFileHandle()
        fileHandle.writeApplicaitonInfo()
        fileHandle.writeInfo(for: bottle)

        return try runWineProcess(
            name: name, args: args,
            environment: constructWineEnvironment(for: bottle, environment: environment),
            directory: directory,
            fileHandle: fileHandle
        )
    }

    /// Run a `wineserver` process with the given arguments and environment variables returning a stream of output
    public static func runWineserverProcess(
        name: String? = nil, args: [String], bottle: Bottle, environment: [String: String] = [:]
    ) throws -> AsyncStream<ProcessOutput> {
        let fileHandle = try makeFileHandle()
        fileHandle.writeApplicaitonInfo()
        fileHandle.writeInfo(for: bottle)

        return try runWineserverProcess(
            name: name, args: args,
            environment: constructWineServerEnvironment(for: bottle, environment: environment),
            fileHandle: fileHandle
        )
    }

    /// Execute a `wine start /unix {url}` command returning the output result
    public static func runProgram(
        at url: URL, args: [String] = [], bottle: Bottle, environment: [String: String] = [:]
    ) async throws {
        _ = try await runProgramWithTerminationStatus(
            at: url,
            args: args,
            bottle: bottle,
            environment: environment
        )
    }

    /// Execute a `wine start /unix {url}` command and return the launcher process termination status
    public static func runProgramWithTerminationStatus(
        at url: URL, args: [String] = [], bottle: Bottle, environment: [String: String] = [:]
    ) async throws -> Int32 {
        syncRuntimeSystemDLLMirrorIfNeeded(for: bottle, environment: environment)

        if shouldEnableDLSSRuntimeTranslation(for: bottle, environment: environment) {
            try await enableDLSSRuntimeTranslation(bottle: bottle, environment: environment)
        } else if shouldEnableDXMT(for: bottle, environment: environment) {
            do {
                try await enableDXMT(bottle: bottle, environment: environment)
            } catch {
                guard shouldFallbackToDXVK(environment: environment) else {
                    throw error
                }
                Logger.wineKit.warning(
                    "DXMT setup failed; falling back to DXVK. Reason: \(error.localizedDescription, privacy: .public)"
                )
                try enableDXVK(bottle: bottle)
            }
        } else if shouldEnableDXVK(for: bottle, environment: environment) {
            try enableDXVK(bottle: bottle)
        }

        var terminationStatus: Int32 = 0
        for await output in try Self.runWineProcess(
            name: url.lastPathComponent,
            args: ["start", "/unix", url.path(percentEncoded: false)] + args,
            bottle: bottle, environment: environment
        ) {
            if case .terminated(let process) = output {
                terminationStatus = process.terminationStatus
            }
        }

        return terminationStatus
    }

    public static func generateRunCommand(
        at url: URL, bottle: Bottle, args: String, environment: [String: String]
    ) -> String {
        var env = constructWineEnvironment(for: bottle, environment: environment)
        let executableURL = resolveExecutable(
            from: &env,
            overrideKey: wineBinaryOverrideEnvironmentKey,
            fallback: wineBinary
        )

        var wineCmd = "\(executableURL.esc) start /unix \(url.esc) \(args)"
        for environment in env {
            wineCmd = "\(environment.key)=\"\(environment.value)\" " + wineCmd
        }

        return wineCmd
    }

    public static func generateTerminalEnvironmentCommand(bottle: Bottle) -> String {
        var cmd = """
        export PATH=\"\(VectorWineInstaller.binFolder.path):$PATH\"
        export WINE=\"wine64\"
        alias wine=\"wine64\"
        alias winecfg=\"wine64 winecfg\"
        alias msiexec=\"wine64 msiexec\"
        alias regedit=\"wine64 regedit\"
        alias regsvr32=\"wine64 regsvr32\"
        alias wineboot=\"wine64 wineboot\"
        alias wineconsole=\"wine64 wineconsole\"
        alias winedbg=\"wine64 winedbg\"
        alias winefile=\"wine64 winefile\"
        alias winepath=\"wine64 winepath\"
        """

        let env = constructWineEnvironment(for: bottle, environment: constructWineEnvironment(for: bottle))
        for environment in env {
            cmd += "\nexport \(environment.key)=\"\(environment.value)\""
        }

        return cmd
    }

    /// Run a `wineserver` command with the given arguments and return the output result
    private static func runWineserver(
        _ args: [String], bottle: Bottle, environment: [String: String] = [:]
    ) async throws -> String {
        var result: [ProcessOutput] = []

        for await output in try Self.runWineserverProcess(args: args, bottle: bottle, environment: environment) {
            result.append(output)
        }

        return result.compactMap { output -> String? in
            switch output {
            case .started, .terminated:
                return nil
            case .message(let message), .error(let message):
                return message
            }
        }.joined()
    }

    @discardableResult
    /// Run a `wine` command with the given arguments and return the output result
    public static func runWine(_ args: [String], bottle: Bottle?, environment: [String: String] = [:],
                               collectOutput: Bool = true) async throws -> String {
        var result: [String] = []
        let fileHandle = try makeFileHandle()
        fileHandle.writeApplicaitonInfo()
        var environment = environment
        if let bottle = bottle {
            fileHandle.writeInfo(for: bottle)
            syncRuntimeSystemDLLMirrorIfNeeded(for: bottle, environment: environment)
            environment = constructWineEnvironment(for: bottle, environment: environment)
        }
        for await output in try runWineProcess(args: args, environment: environment, fileHandle: fileHandle) {
            switch output {
            case .started, .terminated:
                break
            case .message(let message), .error(let message):
                if collectOutput {
                    result.append(message)
                }
            }
        }
        return collectOutput ? result.joined() : ""
    }

    public static func killBottle(bottle: Bottle) throws {
        Task.detached(priority: .userInitiated) {
            _ = try await runWineserver(["-k"], bottle: bottle)

            if let steamWineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() {
                _ = try? await runWineserver(
                    ["-k"],
                    bottle: bottle,
                    environment: [wineserverBinaryOverrideEnvironmentKey: steamWineserver.path(percentEncoded: false)]
                )
            }
        }
    }

    public static func enableDXVK(bottle: Bottle) throws {
        try FileManager.default.replaceDLLs(
            in: bottle.url.appending(path: "drive_c").appending(path: "windows").appending(path: "system32"),
            withContentsIn: Wine.dxvkFolder.appending(path: "x64")
        )
        try FileManager.default.replaceDLLs(
            in: bottle.url.appending(path: "drive_c").appending(path: "windows").appending(path: "syswow64"),
            withContentsIn: Wine.dxvkFolder.appending(path: "x32")
        )
    }

    public static func isDXMTPayloadReady() -> Bool {
        payloadLayoutIsValid(at: dxmtFolder)
    }

    public static func ensureDXMTPayloadInstalled() async throws {
        try await dxmtInstallCoordinator.run {
            if payloadLayoutIsValid(at: dxmtFolder) {
                return
            }
            try await installDXMTPayload()
        }
    }

    public static func enableDXMT(bottle: Bottle, environment: [String: String] = [:]) async throws {
        try await ensureDXMTPayloadInstalled()
        try installDXMTPayloadIntoRuntime(for: bottle, environment: environment)
        try installDXMTPayloadIntoBottle(bottle)
    }

    public static func enableDLSSRuntimeTranslation(
        bottle: Bottle,
        environment: [String: String] = [:]
    ) async throws {
        try await enableDXMT(bottle: bottle, environment: environment)
        try ensureDLSSRuntimePayloadReady(for: bottle, environment: environment)
    }

    private static func shouldEnableDXMT(for bottle: Bottle, environment: [String: String]) -> Bool {
        if let resolvedBackend = resolvedBackendMode(for: bottle, environment: environment) {
            switch resolvedBackend {
            case .auto:
                break
            case .dxmt:
                return true
            case .dxvk, .wined3d, .d3dMetal:
                return false
            }
        }

        if bottle.settings.graphicsBackendMode == .dxmt {
            return true
        }

        if shouldEnableDLSSRuntimeTranslation(for: bottle, environment: environment) {
            return true
        }

        if let dxmtNVExtensions = environment[dxmtNVExtensionsEnvironmentKey],
           isTruthyEnvironmentValue(dxmtNVExtensions) {
            return true
        }

        guard let overrides = environment["WINEDLLOVERRIDES"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !overrides.isEmpty else {
            return false
        }

        return overrides.contains("dxgi")
            && overrides.contains("d3d10core")
            && overrides.contains("d3d11")
            && overrides.contains("=b")
    }

    private static func shouldEnableDLSSRuntimeTranslation(
        for bottle: Bottle,
        environment: [String: String]
    ) -> Bool {
        if bottle.settings.dlssRuntimeTranslationEnabled {
            return true
        }

        let environmentFlags = [
            environment[dxmtNVExtensionsEnvironmentKey],
            environment[dlssTranslationMarkerEnvironmentKey]
        ]

        return environmentFlags.contains { value in
            guard let value else { return false }
            return isTruthyEnvironmentValue(value)
        }
    }

    // swiftlint:disable function_body_length
    private static func installDXMTPayload() async throws {
        let fileManager = FileManager.default
        let payloadInfo = try await fetchLatestDXMTPayloadInfo()

        let temporaryDirectory = fileManager.temporaryDirectory
            .appending(path: "vector-dxmt-\(UUID().uuidString)")
        let archiveURL = temporaryDirectory.appending(path: payloadInfo.archiveFilename)
        let extractDirectory = temporaryDirectory.appending(path: "extract")
        defer {
            try? fileManager.removeItem(at: temporaryDirectory)
        }

        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let request = URLRequest(
            url: payloadInfo.archiveURL,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 180
        )
        let (downloadedURL, response) = try await URLSession(configuration: .ephemeral).download(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "Vector.DXMT",
                code: 502,
                userInfo: [NSLocalizedDescriptionKey: "Failed to download DXMT runtime payload."]
            )
        }
        try fileManager.moveItem(at: downloadedURL, to: archiveURL)

        if let sha256Digest = payloadInfo.sha256,
           try !validateSHA256(of: archiveURL, expected: sha256Digest) {
            throw NSError(
                domain: "Vector.DXMT",
                code: 498,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "DXMT payload checksum validation failed."
                ]
            )
        }

        try fileManager.createDirectory(at: extractDirectory, withIntermediateDirectories: true)
        try Tar.untar(tarBall: archiveURL, toURL: extractDirectory)
        let extractedRoot = try locateDXMTPayloadRoot(in: extractDirectory)

        let targetX64Windows = dxmtFolder.appending(path: "x86_64-windows")
        let targetX86Windows = dxmtFolder.appending(path: "i386-windows")
        let targetX64Unix = dxmtFolder.appending(path: "x86_64-unix")

        try syncDirectory(
            from: extractedRoot.appending(path: "x86_64-windows"),
            to: targetX64Windows
        )
        try syncDirectory(
            from: extractedRoot.appending(path: "i386-windows"),
            to: targetX86Windows
        )
        try syncDirectory(
            from: extractedRoot.appending(path: "x86_64-unix"),
            to: targetX64Unix
        )
    }
    // swiftlint:enable function_body_length

    private static func installDXMTPayloadIntoRuntime(for bottle: Bottle, environment: [String: String]) throws {
        let runtimeWineFolder = resolveRuntimeWineFolder(for: bottle, environment: environment)
        let runtime64Windows = runtimeWineFolder.appending(path: "x86_64-windows")
        let runtime32Windows = runtimeWineFolder.appending(path: "i386-windows")
        let runtimeUnix = runtimeWineFolder.appending(path: "x86_64-unix")

        try FileManager.default.replaceDLLs(
            in: runtime64Windows,
            withContentsIn: dxmtFolder.appending(path: "x86_64-windows"),
            makeOriginalCopy: true
        )
        try FileManager.default.replaceDLLs(
            in: runtime32Windows,
            withContentsIn: dxmtFolder.appending(path: "i386-windows"),
            makeOriginalCopy: true
        )

        let winemetalSource = dxmtFolder
            .appending(path: "x86_64-unix")
            .appending(path: "winemetal.so")
        let winemetalDestination = runtimeUnix.appending(path: "winemetal.so")
        try replaceOrCopyFile(at: winemetalDestination, with: winemetalSource)
    }

    private static func installDXMTPayloadIntoBottle(_ bottle: Bottle) throws {
        let windowsDirectory = bottle.url.appending(path: "drive_c").appending(path: "windows")
        let system32Directory = windowsDirectory.appending(path: "system32")
        let syswow64Directory = windowsDirectory.appending(path: "syswow64")
        try FileManager.default.replaceDLLs(
            in: system32Directory,
            withContentsIn: dxmtFolder.appending(path: "x86_64-windows")
        )
        try FileManager.default.replaceDLLs(
            in: syswow64Directory,
            withContentsIn: dxmtFolder.appending(path: "i386-windows")
        )
    }

    private static func payloadLayoutIsValid(at root: URL) -> Bool {
        let requiredPaths = [
            root.appending(path: "x86_64-windows").appending(path: "dxgi.dll"),
            root.appending(path: "x86_64-windows").appending(path: "d3d11.dll"),
            root.appending(path: "x86_64-windows").appending(path: "d3d10core.dll"),
            root.appending(path: "i386-windows").appending(path: "dxgi.dll"),
            root.appending(path: "i386-windows").appending(path: "d3d11.dll"),
            root.appending(path: "i386-windows").appending(path: "d3d10core.dll"),
            root.appending(path: "x86_64-unix").appending(path: "winemetal.so")
        ]

        return requiredPaths.allSatisfy { path in
            FileManager.default.fileExists(atPath: path.path(percentEncoded: false))
        }
    }

    private static func fetchLatestDXMTPayloadInfo() async throws -> DXMTPayloadInfo {
        do {
            let request = URLRequest(
                url: dxmtLatestReleaseAPIURL,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                timeoutInterval: 30
            )
            let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw NSError(domain: "Vector.DXMT", code: 503)
            }

            let release = try JSONDecoder().decode(DXMTReleaseResponse.self, from: data)
            if let payloadAsset = release.assets.first(where: { asset in
                asset.name.contains("builtin")
                    && asset.name.hasSuffix(".tar.gz")
                    && URL(string: asset.browserDownloadURL) != nil
            }), let archiveURL = URL(string: payloadAsset.browserDownloadURL) {
                let digest = payloadAsset.digest?
                    .replacingOccurrences(of: "sha256:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                return DXMTPayloadInfo(
                    releaseTag: release.tagName,
                    archiveURL: archiveURL,
                    archiveFilename: payloadAsset.name,
                    sha256: digest?.isEmpty == false ? digest : nil
                )
            }
        } catch {
            Logger.wineKit.warning(
                "DXMT release metadata fetch failed: \(error.localizedDescription, privacy: .public)"
            )
        }

        return DXMTPayloadInfo(
            releaseTag: dxmtFallbackReleaseVersion,
            archiveURL: dxmtFallbackPayloadURL,
            archiveFilename: dxmtFallbackPayloadURL.lastPathComponent,
            sha256: nil
        )
    }

    private static func locateDXMTPayloadRoot(in root: URL) throws -> URL {
        if payloadLayoutIsValid(at: root) {
            return root
        }

        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        while let candidate = enumerator?.nextObject() as? URL {
            if payloadLayoutIsValid(at: candidate) {
                return candidate
            }
        }

        throw NSError(
            domain: "Vector.DXMT",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "DXMT payload layout is invalid."]
        )
    }

    private static func syncDirectory(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: source, to: destination)
    }

    private static func replaceOrCopyFile(at destination: URL, with source: URL) throws {
        let fileManager = FileManager.default
        let destinationPath = destination.path(percentEncoded: false)
        if fileManager.fileExists(atPath: destinationPath) {
            try fileManager.removeItem(at: destination)
        } else {
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    private static func validateSHA256(of fileURL: URL, expected: String) throws -> Bool {
        let digest = try computeSHA256(of: fileURL)
        return digest.caseInsensitiveCompare(expected) == .orderedSame
    }

    private static func resolveRuntimeWineFolder(for bottle: Bottle, environment: [String: String]) -> URL {
        var resolvedEnvironment: [String: String] = [:]
        applyRuntimeSelectionOverrides(for: bottle, environment: &resolvedEnvironment)
        resolvedEnvironment.merge(environment, uniquingKeysWith: { $1 })

        let runtimeWineBinary: URL
        if let overridePath = resolvedEnvironment[wineBinaryOverrideEnvironmentKey],
           !overridePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            runtimeWineBinary = URL(filePath: overridePath)
        } else {
            runtimeWineBinary = wineBinary
        }

        let runtimeRoot = runtimeWineBinary.deletingLastPathComponent().deletingLastPathComponent()
        let runtimeWineFolder = runtimeRoot.appending(path: "lib").appending(path: "wine")
        if FileManager.default.fileExists(atPath: runtimeWineFolder.path(percentEncoded: false)) {
            return runtimeWineFolder
        }

        return VectorWineInstaller.libraryFolder
            .appending(path: "Wine")
            .appending(path: "lib")
            .appending(path: "wine")
    }

    private struct DLLFileFingerprint {
        let byteCount: UInt64
        let sha256: String
    }

    private struct DLLMirrorCopyRecord {
        let dllName: String
        let sourcePath: String
        let destinationPath: String
        let runtimeFingerprint: DLLFileFingerprint
    }

    private struct DLLMirrorMismatchRecord {
        let dllName: String
        let sourcePath: String
        let destinationPath: String
        let runtimeFingerprint: DLLFileFingerprint
        let bottleFingerprint: DLLFileFingerprint
    }

    private struct DLLMirrorSyncResult {
        var copied: [DLLMirrorCopyRecord] = []
        var mismatches: [DLLMirrorMismatchRecord] = []
        var repaired: [DLLMirrorMismatchRecord] = []
        var verifiedPairs: Int = 0

        mutating func merge(_ other: DLLMirrorSyncResult) {
            copied.append(contentsOf: other.copied)
            mismatches.append(contentsOf: other.mismatches)
            repaired.append(contentsOf: other.repaired)
            verifiedPairs += other.verifiedPairs
        }
    }

    private static func syncRuntimeSystemDLLMirrorIfNeeded(for bottle: Bottle, environment: [String: String]) {
        do {
            try syncRuntimeSystemDLLMirror(for: bottle, environment: environment, modeOverride: nil)
        } catch {
            let bottleName = bottle.settings.name
            let errorDescription = error.localizedDescription
            Logger.wineKit.warning(
                "system32 mirror failed (\(bottleName, privacy: .public)): \(errorDescription, privacy: .public)"
            )
        }
    }

    private static func syncRuntimeSystemDLLMirror(
        for bottle: Bottle,
        environment: [String: String],
        modeOverride: RuntimeDLLSyncMode?
    ) throws {
        let syncMode = modeOverride ?? bottle.settings.runtimeDLLSyncMode
        let runtimeWineFolder = resolveRuntimeWineFolder(for: bottle, environment: environment)
        let runtime64Windows = runtimeWineFolder.appending(path: "x86_64-windows")
        let runtime32Windows = runtimeWineFolder.appending(path: "i386-windows")

        let windowsDirectory = bottle.url.appending(path: "drive_c").appending(path: "windows")
        let system32Directory = windowsDirectory.appending(path: "system32")
        let syswow64Directory = windowsDirectory.appending(path: "syswow64")

        var hashCache: [String: DLLFileFingerprint] = [:]
        var aggregated = DLLMirrorSyncResult()

        let result64 = try syncDLLSet(
            named: runtimeSystemDLLMirrorAllowList,
            from: runtime64Windows,
            to: system32Directory,
            mode: syncMode,
            hashCache: &hashCache
        )
        aggregated.merge(result64)

        let result32 = try syncDLLSet(
            named: runtimeSystemDLLMirrorAllowList,
            from: runtime32Windows,
            to: syswow64Directory,
            mode: syncMode,
            hashCache: &hashCache
        )
        aggregated.merge(result32)

        for copy in aggregated.copied {
            logDLLMirrorCopy(copy)
        }

        for mismatch in aggregated.mismatches {
            logDLLMirrorMismatch(mismatch)
        }

        for repaired in aggregated.repaired {
            logDLLMirrorRepair(repaired)
        }

        guard !(aggregated.copied.isEmpty && aggregated.mismatches.isEmpty && aggregated.repaired.isEmpty) else {
            return
        }

        logDLLSyncSummary(for: bottle, mode: syncMode, result: aggregated)
    }

    private static func syncDLLSet(
        named dllNames: [String],
        from sourceDirectory: URL,
        to destinationDirectory: URL,
        mode: RuntimeDLLSyncMode,
        hashCache: inout [String: DLLFileFingerprint]
    ) throws -> DLLMirrorSyncResult {
        let fileManager = FileManager.default
        var result = DLLMirrorSyncResult()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        for dllName in dllNames {
            let sourceURL = sourceDirectory.appending(path: dllName)
            let destinationURL = destinationDirectory.appending(path: dllName)
            let sourcePath = sourceURL.path(percentEncoded: false)
            let destinationPath = destinationURL.path(percentEncoded: false)

            guard fileManager.fileExists(atPath: sourcePath) else {
                continue
            }

            if !fileManager.fileExists(atPath: destinationPath) {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                let runtimeFingerprint = try fileFingerprint(at: sourceURL, hashCache: &hashCache)
                result.copied.append(
                    DLLMirrorCopyRecord(
                        dllName: dllName,
                        sourcePath: sourcePath,
                        destinationPath: destinationPath,
                        runtimeFingerprint: runtimeFingerprint
                    )
                )
                continue
            }

            guard mode != .missingOnly else {
                continue
            }

            result.verifiedPairs += 1

            let runtimeFingerprint = try fileFingerprint(at: sourceURL, hashCache: &hashCache)
            let bottleFingerprint = try fileFingerprint(at: destinationURL, hashCache: &hashCache)
            guard runtimeFingerprint.sha256 != bottleFingerprint.sha256 else {
                continue
            }

            let mismatchRecord = DLLMirrorMismatchRecord(
                dllName: dllName,
                sourcePath: sourcePath,
                destinationPath: destinationPath,
                runtimeFingerprint: runtimeFingerprint,
                bottleFingerprint: bottleFingerprint
            )

            if mode == .verifyAndRepair {
                try replaceOrCopyFile(at: destinationURL, with: sourceURL)
                result.repaired.append(mismatchRecord)
            } else {
                result.mismatches.append(mismatchRecord)
            }
        }

        return result
    }

    private static func fileFingerprint(
        at fileURL: URL,
        hashCache: inout [String: DLLFileFingerprint]
    ) throws -> DLLFileFingerprint {
        let path = fileURL.path(percentEncoded: false)
        if let cached = hashCache[path] {
            return cached
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let byteCount = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        let sha256 = try computeSHA256(of: fileURL)

        let fingerprint = DLLFileFingerprint(byteCount: byteCount, sha256: sha256)
        hashCache[path] = fingerprint
        return fingerprint
    }

    private static func computeSHA256(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1_048_576) ?? Data()
            if chunk.isEmpty {
                break
            }
            hasher.update(data: chunk)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func shortHash(_ hash: String) -> String {
        String(hash.prefix(12))
    }

    private static func logDLLMirrorCopy(_ copy: DLLMirrorCopyRecord) {
        let fingerprint = shortHash(copy.runtimeFingerprint.sha256)
        let message =
            "DLL copied \(copy.dllName) [missing] sha=\(fingerprint) bytes=\(copy.runtimeFingerprint.byteCount) " +
            "\(copy.sourcePath) -> \(copy.destinationPath)"
        Logger.wineKit.info("\(message, privacy: .public)")
    }

    private static func logDLLMirrorMismatch(_ mismatch: DLLMirrorMismatchRecord) {
        let runtimeHash = shortHash(mismatch.runtimeFingerprint.sha256)
        let bottleHash = shortHash(mismatch.bottleFingerprint.sha256)
        let message =
            "DLL mismatch \(mismatch.dllName) [verify-only] runtime=\(runtimeHash) " +
            "bottle=\(bottleHash) \(mismatch.destinationPath)"
        Logger.wineKit.warning("\(message, privacy: .public)")
    }

    private static func logDLLMirrorRepair(_ repaired: DLLMirrorMismatchRecord) {
        let runtimeHash = shortHash(repaired.runtimeFingerprint.sha256)
        let bottleHash = shortHash(repaired.bottleFingerprint.sha256)
        let message =
            "DLL repaired \(repaired.dllName) runtime=\(runtimeHash) was=\(bottleHash) " +
            "\(repaired.sourcePath) -> \(repaired.destinationPath)"
        Logger.wineKit.info("\(message, privacy: .public)")
    }

    private static func logDLLSyncSummary(
        for bottle: Bottle,
        mode: RuntimeDLLSyncMode,
        result: DLLMirrorSyncResult
    ) {
        let message =
            "DLL sync summary \(bottle.settings.name): copied=\(result.copied.count) " +
            "verified=\(result.verifiedPairs) mismatches=\(result.mismatches.count) " +
            "repaired=\(result.repaired.count) mode=\(mode.rawValue)"
        Logger.wineKit.debug("\(message, privacy: .public)")
    }

    private static func ensureDLSSRuntimePayloadReady(
        for bottle: Bottle,
        environment: [String: String]
    ) throws {
        let dxmtPayloadPaths = [
            dxmtFolder.appending(path: "x86_64-windows").appending(path: "nvapi64.dll"),
            dxmtFolder.appending(path: "x86_64-windows").appending(path: "nvngx.dll")
        ]
        try assertFilesExist(
            at: dxmtPayloadPaths,
            failureReason: "DXMT payload is missing NVAPI/NVNGX translation DLLs."
        )

        let runtimeWineFolder = resolveRuntimeWineFolder(for: bottle, environment: environment)
        let runtimePaths = [
            runtimeWineFolder.appending(path: "x86_64-windows").appending(path: "nvapi64.dll"),
            runtimeWineFolder.appending(path: "x86_64-windows").appending(path: "nvngx.dll")
        ]
        try assertFilesExist(
            at: runtimePaths,
            failureReason: "Runtime Wine folder is missing DLSS translation DLLs."
        )

        let windowsDirectory = bottle.url.appending(path: "drive_c").appending(path: "windows")
        let bottlePaths = [
            windowsDirectory.appending(path: "system32").appending(path: "nvapi64.dll"),
            windowsDirectory.appending(path: "system32").appending(path: "nvngx.dll")
        ]
        try assertFilesExist(
            at: bottlePaths,
            failureReason: "Bottle system32 is missing DLSS translation DLLs."
        )
    }

    private static func assertFilesExist(at paths: [URL], failureReason: String) throws {
        let fileManager = FileManager.default
        let missingPaths = paths.filter { path in
            !fileManager.fileExists(atPath: path.path(percentEncoded: false))
        }

        guard missingPaths.isEmpty else {
            let joinedMissingPaths = missingPaths
                .map { $0.path(percentEncoded: false) }
                .joined(separator: ", ")
            throw NSError(
                domain: "Vector.DXMT",
                code: 417,
                userInfo: [
                    NSLocalizedDescriptionKey: "\(failureReason) Missing: \(joinedMissingPaths)"
                ]
            )
        }
    }

    private static func isTruthyEnvironmentValue(_ rawValue: String) -> Bool {
        ["1", "true", "yes", "on"].contains(
            rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }

    /// Construct an environment merging the bottle values with the given values
    private static func constructWineEnvironment(
        for bottle: Bottle, environment: [String: String] = [:]
    ) -> [String: String] {
        var result: [String: String] = [
            "WINEPREFIX": bottle.url.path,
            "WINEDEBUG": resolvedWineDebugLevel()
        ]
        applyRuntimeSelectionOverrides(for: bottle, environment: &result)
        bottle.settings.environmentVariables(wineEnv: &result)
        if !environment.isEmpty {
            result.merge(environment, uniquingKeysWith: { $1 })
        }
        applySteamClientGraphicsOverrideIsolation(to: &result)
        applyPerformanceDefaults(for: bottle, environment: &result)
        return result
    }

    private static func applySteamClientGraphicsOverrideIsolation(to environment: inout [String: String]) {
        defer {
            environment.removeValue(forKey: steamGraphicsIsolationEnvKey)
        }

        guard let rawValue = environment[steamGraphicsIsolationEnvKey],
              isTruthyEnvironmentValue(rawValue) else {
            return
        }

        let sanitizedOverrides = stripDLLOverrideGroups(
            from: environment["WINEDLLOVERRIDES"],
            containingAny: steamClientGraphicsDLLOverrideNames
        )
        if sanitizedOverrides.isEmpty {
            environment.removeValue(forKey: "WINEDLLOVERRIDES")
        } else {
            environment["WINEDLLOVERRIDES"] = sanitizedOverrides
        }
    }

    private static func stripDLLOverrideGroups(
        from overrides: String?,
        containingAny blockedNames: Set<String>
    ) -> String {
        guard let overrides,
              !overrides.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        return overrides
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { group in
                !dllOverrideGroup(group, containsAny: blockedNames)
            }
            .joined(separator: ";")
    }

    private static func dllOverrideGroup(_ group: String, containsAny blockedNames: Set<String>) -> Bool {
        guard let equalsIndex = group.firstIndex(of: "=") else {
            return false
        }

        let dllNames = group[..<equalsIndex]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        return dllNames.contains { blockedNames.contains($0) }
    }

    /// Construct an environment merging the bottle values with the given values
    private static func constructWineServerEnvironment(
        for bottle: Bottle, environment: [String: String] = [:]
    ) -> [String: String] {
        var result: [String: String] = [
            "WINEPREFIX": bottle.url.path,
            "WINEDEBUG": resolvedWineDebugLevel()
        ]
        applyRuntimeSelectionOverrides(for: bottle, environment: &result)
        guard !environment.isEmpty else { return result }
        result.merge(environment, uniquingKeysWith: { $1 })
        return result
    }

    private static func resolveExecutable(
        from environment: inout [String: String], overrideKey: String, fallback: URL
    ) -> URL {
        defer {
            environment.removeValue(forKey: overrideKey)
        }

        guard let overridePath = environment[overrideKey],
              !overridePath.isEmpty else {
            return fallback
        }

        let overrideURL = URL(filePath: overridePath)
        let path = overrideURL.path(percentEncoded: false)
        guard FileManager.default.isExecutableFile(atPath: path) else {
            Logger.wineKit.warning("Invalid Wine executable override at \(path, privacy: .public)")
            return fallback
        }

        return overrideURL
    }
}

public extension Wine {
    static func repairRuntimeSystemDLLMirror(
        for bottle: Bottle,
        environment: [String: String] = [:]
    ) throws {
        try syncRuntimeSystemDLLMirror(
            for: bottle,
            environment: environment,
            modeOverride: .verifyAndRepair
        )
    }

    /// Execute `wine {path_to_exe} {args...}` and return launcher process termination status
    static func runProgramDirectWithTerminationStatus(
        at url: URL, args: [String] = [], bottle: Bottle, environment: [String: String] = [:]
    ) async throws -> Int32 {
        syncRuntimeSystemDLLMirrorIfNeeded(for: bottle, environment: environment)

        if shouldEnableDLSSRuntimeTranslation(for: bottle, environment: environment) {
            try await enableDLSSRuntimeTranslation(bottle: bottle, environment: environment)
        } else if shouldEnableDXMT(for: bottle, environment: environment) {
            do {
                try await enableDXMT(bottle: bottle, environment: environment)
            } catch {
                guard shouldFallbackToDXVK(environment: environment) else {
                    throw error
                }
                Logger.wineKit.warning(
                    "DXMT setup failed; falling back to DXVK. Reason: \(error.localizedDescription, privacy: .public)"
                )
                try enableDXVK(bottle: bottle)
            }
        } else if shouldEnableDXVK(for: bottle, environment: environment) {
            try enableDXVK(bottle: bottle)
        }

        var terminationStatus: Int32 = 0
        for await output in try Self.runWineProcess(
            name: url.lastPathComponent,
            args: [url.path(percentEncoded: false)] + args,
            bottle: bottle,
            environment: environment,
            directory: url.deletingLastPathComponent()
        ) {
            if case .terminated(let process) = output {
                terminationStatus = process.terminationStatus
            }
        }

        return terminationStatus
    }
}

private extension Wine {
    static func resolvedWineDebugLevel() -> String {
        guard let configuredLevel = UserDefaults.standard.string(forKey: wineDebugLevelDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !configuredLevel.isEmpty else {
            return fallbackWineDebugLevel
        }
        return configuredLevel
    }

    static func applyPerformanceDefaults(for bottle: Bottle, environment: inout [String: String]) {
        guard isDXVKEnabledForPerformanceDefaults(for: bottle, environment: environment) else {
            return
        }

        if environment["DXVK_LOG_LEVEL"] == nil {
            environment["DXVK_LOG_LEVEL"] = "none"
        }
        applyDXVKStateCacheDefaults(for: bottle, environment: &environment)
    }

    static func isDXVKEnabledForPerformanceDefaults(
        for bottle: Bottle,
        environment: [String: String]
    ) -> Bool {
        if let resolvedBackend = resolvedBackendMode(for: bottle, environment: environment) {
            return resolvedBackend == .dxvk
        }

        switch bottle.settings.graphicsBackendMode {
        case .auto:
            return bottle.settings.dxvk
        case .dxvk:
            return true
        case .dxmt, .wined3d, .d3dMetal:
            return false
        }
    }

    static func applyDXVKStateCacheDefaults(
        for bottle: Bottle,
        environment: inout [String: String]
    ) {
        guard bottle.settings.shaderCacheEnabled else {
            if environment["DXVK_STATE_CACHE"] == nil {
                environment["DXVK_STATE_CACHE"] = "0"
            }
            if environment["DXVK_STATE_CACHE"] == "0" {
                environment.removeValue(forKey: "DXVK_STATE_CACHE_PATH")
            }
            return
        }

        if environment["DXVK_STATE_CACHE"] == nil {
            environment["DXVK_STATE_CACHE"] = "1"
        }
        guard environment["DXVK_STATE_CACHE"] != "0" else {
            return
        }

        let cacheDirectory = resolveDXVKStateCacheDirectory(for: bottle)
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            if environment["DXVK_STATE_CACHE_PATH"] == nil {
                environment["DXVK_STATE_CACHE_PATH"] = cacheDirectory.path(percentEncoded: false)
            }
        } catch {
            let cachePath = cacheDirectory.path(percentEncoded: false)
            Logger.wineKit.warning(
                "Failed to create DXVK state cache directory at \(cachePath, privacy: .public)"
            )
            Logger.wineKit.warning(
                "DXVK state cache setup error: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    static func resolveDXVKStateCacheDirectory(for bottle: Bottle) -> URL {
        let configuredPath = bottle.settings.shaderCachePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if configuredPath.isEmpty {
            return bottle.url.appending(path: dxvkStateCacheFolderName)
        }
        if configuredPath.hasPrefix("/") {
            return URL(filePath: configuredPath)
        }
        return bottle.url.appending(path: configuredPath)
    }
}

private struct DXMTPayloadInfo: Sendable {
    let releaseTag: String
    let archiveURL: URL
    let archiveFilename: String
    let sha256: String?
}

private struct DXMTReleaseResponse: Decodable {
    let tagName: String
    let assets: [DXMTReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}

private struct DXMTReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String
    let digest: String?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case digest
    }
}

private actor DXMTPayloadInstallCoordinator {
    private var inFlightTask: Task<Void, Error>?

    func run(_ operation: @escaping @Sendable () async throws -> Void) async throws {
        if let inFlightTask {
            return try await inFlightTask.value
        }

        let task = Task {
            try await operation()
        }
        inFlightTask = task
        defer {
            inFlightTask = nil
        }

        try await task.value
    }
}
