//
//  Winetricks+Silent.swift
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

struct WinetricksRunResult: Sendable {
    let command: String
    let status: Int32
    let output: String

    var outputSummary: String {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else {
            return "no output"
        }
        if trimmedOutput.count <= 700 {
            return trimmedOutput
        }
        return String(trimmedOutput.suffix(700))
    }
}

enum WinetricksRunError: LocalizedError {
    case missingResource(String)
    case commandFailed(command: String, status: Int32, output: String)
    case timedOut(command: String, timeout: TimeInterval, output: String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let resource):
            return "\(resource) is missing."
        case .commandFailed(let command, let status, let output):
            return "Winetricks \(command) exited with status \(status). \(output)"
        case .timedOut(let command, let timeout, let output):
            return "Winetricks \(command) timed out after \(Int(timeout))s. \(output)"
        }
    }
}

extension Winetricks {
    static func runCommandSilently(
        command: String,
        bottle: Bottle,
        timeoutSeconds: TimeInterval = 1_800
    ) async throws -> WinetricksRunResult {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else {
            throw WinetricksRunError.missingResource("Winetricks command")
        }

        let scriptURL = try writeScript(
            command: trimmedCommand,
            bottle: bottle,
            unattended: true,
            waitForWineserverShutdown: false
        )
        VectorNotifications.notifyMaintenanceStarted(
            task: "Winetricks (\(trimmedCommand))",
            bottleName: bottle.settings.name
        )

        do {
            let result = try await Task.detached(priority: .utility) {
                try runScriptSynchronously(
                    scriptURL: scriptURL,
                    command: trimmedCommand,
                    timeoutSeconds: timeoutSeconds
                )
            }.value
            VectorNotifications.notifyMaintenanceCompleted(
                task: "Winetricks (\(trimmedCommand))",
                bottleName: bottle.settings.name
            )
            return result
        } catch {
            VectorNotifications.notifyMaintenanceFailed(
                task: "Winetricks (\(trimmedCommand))",
                bottleName: bottle.settings.name,
                reason: error.localizedDescription
            )
            throw error
        }
    }

    static func writeScript(
        command: String,
        bottle: Bottle,
        unattended: Bool,
        waitForWineserverShutdown: Bool
    ) throws -> URL {
        guard let resourcesURL = Bundle.main.url(forResource: "cabextract", withExtension: nil)?
            .deletingLastPathComponent() else {
            throw WinetricksRunError.missingResource("cabextract resources")
        }
        guard FileManager.default.isExecutableFile(atPath: winetricksURL.path(percentEncoded: false)) else {
            throw WinetricksRunError.missingResource("winetricks")
        }

        let runtime = resolveRuntimeBinaries(for: bottle)
        let runtimeBinDirectory = runtime.wine.deletingLastPathComponent().path(percentEncoded: false)
        let cleanSystemPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        let escapedPath = [
            runtimeBinDirectory,
            resourcesURL.path(percentEncoded: false),
            cleanSystemPath
        ].map(shellEscapedForDoubleQuotes).joined(separator: ":")
        let shutdownCommands = wineserverShutdownCommands(
            for: wineserverCandidates(selected: runtime.wineserver, bottle: bottle),
            waitForExit: waitForWineserverShutdown
        )
        let unattendedFlag = unattended ? "-q " : ""

        let scriptURL = FileManager.default.temporaryDirectory
            .appending(path: "vector-winetricks-\(UUID().uuidString).sh")
        let scriptContents = """
        #!/bin/zsh
        vector_cleanup() { rm -f -- "$0"; }
        trap vector_cleanup EXIT
        WINEPREFIX="\(shellEscapedForDoubleQuotes(bottle.url.path))"
        WINE="\(shellEscapedForDoubleQuotes(runtime.wine.path(percentEncoded: false)))"
        WINESERVER="\(shellEscapedForDoubleQuotes(runtime.wineserver.path(percentEncoded: false)))"
        WINELOADER="$WINE"
        PATH="\(escapedPath)"
        WINEDEBUG="-all"
        export PATH WINE WINELOADER WINESERVER WINEPREFIX WINEDEBUG
        unset VECTOR_WINE_BIN_OVERRIDE
        unset VECTOR_WINESERVER_BIN_OVERRIDE
        unset VECTOR_STEAM_WINE_BIN
        unset VECTOR_STEAM_WINESERVER_BIN
        \(shutdownCommands)
        sleep 1
        "\(shellEscapedForDoubleQuotes(winetricksURL.path(percentEncoded: false)))" \(unattendedFlag)\(command)
        exit $?
        """

        try scriptContents.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: scriptURL.path(percentEncoded: false)
        )
        return scriptURL
    }

    private static func runScriptSynchronously(
        scriptURL: URL,
        command: String,
        timeoutSeconds: TimeInterval
    ) throws -> WinetricksRunResult {
        let process = Process()
        let pipe = Pipe()
        let outputBuffer = LockedData()
        let semaphore = DispatchSemaphore(value: 0)

        process.executableURL = URL(filePath: "/bin/zsh")
        process.arguments = [scriptURL.path(percentEncoded: false)]
        process.standardOutput = pipe
        process.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            outputBuffer.append(data)
        }
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        try process.run()
        let timeoutResult = semaphore.wait(timeout: .now() + timeoutSeconds)
        if timeoutResult == .timedOut {
            process.terminate()
            let output = outputBuffer.stringValue
            try? FileManager.default.removeItem(at: scriptURL)
            throw WinetricksRunError.timedOut(command: command, timeout: timeoutSeconds, output: output)
        }

        pipe.fileHandleForReading.readabilityHandler = nil
        outputBuffer.append(pipe.fileHandleForReading.readDataToEndOfFile())
        try? FileManager.default.removeItem(at: scriptURL)

        let output = outputBuffer.stringValue
        let result = WinetricksRunResult(command: command, status: process.terminationStatus, output: output)
        guard process.terminationStatus == 0 else {
            throw WinetricksRunError.commandFailed(
                command: command,
                status: process.terminationStatus,
                output: result.outputSummary
            )
        }
        return result
    }

    private static func shellEscapedForDoubleQuotes(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
    }

    private static func wineserverShutdownCommands(for candidates: [URL], waitForExit: Bool) -> String {
        candidates.map { wineserverURL in
            let path = shellEscapedForDoubleQuotes(wineserverURL.path(percentEncoded: false))
            let waitCommand = waitForExit ? "\"\(path)\" -w >/dev/null 2>&1 || true" : ""
            return """
            if [ -x "\(path)" ]; then
                "\(path)" -k >/dev/null 2>&1 || true
                \(waitCommand)
            fi
            """
        }
        .joined(separator: "\n")
    }

    private static func wineserverCandidates(selected: URL, bottle: Bottle) -> [URL] {
        var candidates = [
            VectorWineInstaller.binFolder.appending(path: "wineserver")
        ]

        if let compatibilityWineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() {
            candidates.append(compatibilityWineserver)
        }

        if let crossOverWineserver = VectorWineInstaller.crossOverWineserverBinary() {
            candidates.append(crossOverWineserver)
        }

        let customWineserverPath = bottle.settings.customWineserverBinaryPath
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !customWineserverPath.isEmpty {
            candidates.append(URL(filePath: customWineserverPath))
        }

        candidates.append(selected)

        var seenPaths = Set<String>()
        return candidates.filter { url in
            let path = url.path(percentEncoded: false)
            guard !path.isEmpty, !seenPaths.contains(path) else {
                return false
            }
            seenPaths.insert(path)
            return true
        }
    }

    private static func resolveRuntimeBinaries(for bottle: Bottle) -> (wine: URL, wineserver: URL) {
        let bundledWine = VectorWineInstaller.binFolder.appending(path: "wine64")
        let bundledWineserver = VectorWineInstaller.binFolder.appending(path: "wineserver")

        if let compatibilityWine = VectorWineInstaller.steamCompatibilityWineBinary(),
           let compatibilityWineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() {
            switch bottle.settings.runtimeSelection {
            case .custom, .crossover:
                break
            case .auto:
                if !VectorWineInstaller.isCrossOverBottleURL(bottle.url) {
                    return (compatibilityWine, compatibilityWineserver)
                }
            case .bundled, .compatibility:
                return (compatibilityWine, compatibilityWineserver)
            }
        }

        if bottle.settings.runtimeSelection == .crossover
            || (bottle.settings.runtimeSelection == .auto && VectorWineInstaller.isCrossOverBottleURL(bottle.url)),
           let crossOverWine = VectorWineInstaller.crossOverWineBinary(),
           let crossOverWineserver = VectorWineInstaller.crossOverWineserverBinary() {
            return (crossOverWine, crossOverWineserver)
        }

        if bottle.settings.runtimeSelection == .custom {
            let customWinePath = bottle.settings.customWineBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let customWineserverPath = bottle.settings.customWineserverBinaryPath
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let customWineURL = URL(filePath: customWinePath)
            let customWineserverURL = URL(filePath: customWineserverPath)
            if FileManager.default.isExecutableFile(atPath: customWineURL.path(percentEncoded: false)),
               FileManager.default.isExecutableFile(atPath: customWineserverURL.path(percentEncoded: false)) {
                return (customWineURL, customWineserverURL)
            }
        }

        return (bundledWine, bundledWineserver)
    }
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    var stringValue: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
