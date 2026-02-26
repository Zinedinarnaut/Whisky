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

import Foundation
import os.log

public class Wine {
    private static let wineBinaryOverrideEnvironmentKey = "VECTOR_WINE_BIN_OVERRIDE"
    private static let wineserverBinaryOverrideEnvironmentKey = "VECTOR_WINESERVER_BIN_OVERRIDE"
    private static let wineDebugLevelDefaultsKey = "wineDebugLevel"
    private static let fallbackWineDebugLevel = "-all"
    private static let dxvkStateCacheFolderName = "DXVKStateCache"

    /// URL to the installed `DXVK` folder
    private static let dxvkFolder: URL = VectorWineInstaller.libraryFolder.appending(path: "DXVK")
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
        fileHandle: FileHandle?
    ) throws -> AsyncStream<ProcessOutput> {
        var environment = environment
        let executableURL = resolveExecutable(
            from: &environment,
            overrideKey: wineBinaryOverrideEnvironmentKey,
            fallback: wineBinary
        )

        return try runProcess(
            name: name, args: args, environment: environment, executableURL: executableURL,
            fileHandle: fileHandle
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
        name: String? = nil, args: [String], bottle: Bottle, environment: [String: String] = [:]
    ) throws -> AsyncStream<ProcessOutput> {
        let fileHandle = try makeFileHandle()
        fileHandle.writeApplicaitonInfo()
        fileHandle.writeInfo(for: bottle)

        return try runWineProcess(
            name: name, args: args,
            environment: constructWineEnvironment(for: bottle, environment: environment),
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
        if bottle.settings.dxvk {
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
    public static func runWine(
        _ args: [String], bottle: Bottle?, environment: [String: String] = [:]
    ) async throws -> String {
        var result: [String] = []
        let fileHandle = try makeFileHandle()
        fileHandle.writeApplicaitonInfo()
        var environment = environment

        if let bottle = bottle {
            fileHandle.writeInfo(for: bottle)
            environment = constructWineEnvironment(for: bottle, environment: environment)
        }

        for await output in try runWineProcess(args: args, environment: environment, fileHandle: fileHandle) {
            switch output {
            case .started, .terminated:
                break
            case .message(let message), .error(let message):
                result.append(message)
            }
        }

        return result.joined()
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

    /// Construct an environment merging the bottle values with the given values
    private static func constructWineEnvironment(
        for bottle: Bottle, environment: [String: String] = [:]
    ) -> [String: String] {
        var result: [String: String] = [
            "WINEPREFIX": bottle.url.path,
            "WINEDEBUG": resolvedWineDebugLevel()
        ]
        bottle.settings.environmentVariables(wineEnv: &result)
        applyPerformanceDefaults(for: bottle, environment: &result)
        guard !environment.isEmpty else { return result }
        result.merge(environment, uniquingKeysWith: { $1 })
        return result
    }

    /// Construct an environment merging the bottle values with the given values
    private static func constructWineServerEnvironment(
        for bottle: Bottle, environment: [String: String] = [:]
    ) -> [String: String] {
        var result: [String: String] = [
            "WINEPREFIX": bottle.url.path,
            "WINEDEBUG": resolvedWineDebugLevel()
        ]
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
        guard bottle.settings.dxvk else {
            return
        }

        environment["DXVK_LOG_LEVEL"] = "none"
        environment["DXVK_STATE_CACHE"] = "1"

        let cacheDirectory = bottle.url.appending(path: dxvkStateCacheFolderName)
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            environment["DXVK_STATE_CACHE_PATH"] = cacheDirectory.path(percentEncoded: false)
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
}
