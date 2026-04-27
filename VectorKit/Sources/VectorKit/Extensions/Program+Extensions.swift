//
//  Program+Extensions.swift
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
import AppKit
import os.log

// swiftlint:disable file_length
extension Program {
    private static let wineBinaryOverrideEnvironmentKey = "VECTOR_WINE_BIN_OVERRIDE"
    private static let wineserverBinaryOverrideEnvironmentKey = "VECTOR_WINESERVER_BIN_OVERRIDE"
    private static let steamExecutable = "steam.exe"
    private static let steamBootstrapMarkerFilename = ".vector-steam-bootstrap-v3"
    private static let steamHTMLCacheResetMarkerFilename = ".vector-steam-htmlcache-reset-v4"
    private static let gameModeLaunchersDirectoryName = ".vector-gamemode-launchers"
    private static let steamBootstrapExitArgument = "-exitsteam"
    private static let steamSafeLaunchArguments = [
        "-cef-disable-gpu"
    ]
    private static let steamLegacyExtraLaunchArguments = [
        "-cef-disable-breakpad",
        "-cef-force-32bit",
        "-nocrashmonitor",
        "-noshaders"
    ]
    private static let steamBootstrapArgumentPrefix = [
        "-forcesteamupdate",
        "-forcepackagedownload",
        "-exitsteam"
    ]
    private static let steamPinnedBootstrapArgumentPrefix = [
        "-noverifyfiles",
        "-nobootstrapupdate",
        "-skipinitialbootstrap",
        "-norepairfiles"
    ]

    public func run() {
        if NSEvent.modifierFlags.contains(.shift) {
            self.runInTerminal()
        } else {
            self.runInWine()
        }
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    func runInWine() {
        Task.detached(priority: .userInitiated) {
            do {
                VectorNotifications.notifyLaunchStarted(
                    programName: self.name,
                    bottleName: self.bottle.settings.name
                )
                await BottleGamingModeManager.prepareProfilesForLaunch(for: self.bottle)

                var arguments = self.runtimeArguments()
                var launchURL = self.resolvedLaunchExecutableURL(arguments: &arguments)
                _ = await VectorLaunchDoctor.prepareForLaunch(programURL: launchURL, bottle: self.bottle)
                arguments = self.runtimeArguments()
                launchURL = self.resolvedLaunchExecutableURL(arguments: &arguments)
                let environment = self.runtimeEnvironment()
                let activeSteamAppID = self.bottle.settings.activeSteamAppID
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let shouldLaunchSilentHillFViaSteam =
                    self.shouldLaunchSilentHillFViaSteam(activeSteamAppID: activeSteamAppID)
                let shouldLaunchMinecraftDungeonsViaSteam =
                    self.shouldLaunchMinecraftDungeonsViaSteam(activeSteamAppID: activeSteamAppID)
                let silentHillFSteamExecutable =
                    shouldLaunchSilentHillFViaSteam ? self.steamLaunchExecutableURL() : nil
                let minecraftDungeonsSteamExecutable =
                    shouldLaunchMinecraftDungeonsViaSteam ? self.steamLaunchExecutableURL() : nil
                let shouldForceDirectLaunch = self.shouldApplyMinecraftDungeonsCompatibility(
                    activeSteamAppID: activeSteamAppID
                ) && minecraftDungeonsSteamExecutable == nil

                self.prepareLaunchCompatibilityShims()
                guard await self.shouldProceedWithLaunchPreflight() else { return }
                await self.prepareMinecraftDungeonsDirectLaunch(
                    environment: environment,
                    shouldForceDirectLaunch: shouldForceDirectLaunch
                )
                if minecraftDungeonsSteamExecutable != nil {
                    await self.ensureMinecraftDungeonsAppDefaults(environment: environment)
                }
                if !self.isSteamProgram {
                    try await self.resetSteamWineserver(environment: environment)
                }
                if self.isSteamProgram {
                    try await self.runSteamInWine(arguments: arguments, environment: environment)
                } else if let steamExecutable = silentHillFSteamExecutable {
                    _ = try await Wine.runProgramWithTerminationStatus(
                        at: steamExecutable,
                        args: self.silentHillFSteamLaunchArguments(),
                        bottle: self.bottle,
                        environment: environment
                    )
                } else if let steamExecutable = minecraftDungeonsSteamExecutable {
                    _ = try await Wine.runProgramWithTerminationStatus(
                        at: steamExecutable,
                        args: self.minecraftDungeonsSteamLaunchArguments(),
                        bottle: self.bottle,
                        environment: environment
                    )
                } else if shouldForceDirectLaunch {
                    let status = try await Wine.runProgramDirectWithTerminationStatus(
                        at: launchURL,
                        args: arguments,
                        bottle: self.bottle,
                        environment: environment
                    )
                    if status != 0 {
                        throw NSError(
                            domain: "Vector.DirectLaunch",
                            code: Int(status),
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "\(launchURL.lastPathComponent) exited with status \(status)."
                            ]
                        )
                    }
                } else if self.bottle.settings.nativeGameModeLaunchesEnabled && !shouldLaunchSilentHillFViaSteam {
                    try self.runInNativeGameMode(launchURL: launchURL, arguments: arguments, environment: environment)
                } else if shouldLaunchSilentHillFViaSteam {
                    let status = try await Wine.runProgramDirectWithTerminationStatus(
                        at: launchURL,
                        args: arguments,
                        bottle: self.bottle,
                        environment: environment
                    )
                    if status != 0 {
                        throw NSError(
                            domain: "Vector.DirectLaunch",
                            code: Int(status),
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "\(launchURL.lastPathComponent) exited with status \(status)."
                            ]
                        )
                    }
                } else {
                    try await Wine.runProgram(
                        at: launchURL,
                        args: arguments,
                        bottle: self.bottle,
                        environment: environment
                    )
                }
                await DispatchPatchService.shared.reportTelemetry(
                    for: self.bottle,
                    programPath: launchURL.path(percentEncoded: false),
                    success: true
                )
                VectorNotifications.notifyLaunchSucceeded(
                    programName: self.name,
                    bottleName: self.bottle.settings.name
                )
            } catch {
                await DispatchPatchService.shared.reportTelemetry(
                    for: self.bottle,
                    programPath: self.url.path(percentEncoded: false),
                    success: false,
                    crashSignature: error.localizedDescription
                )
                VectorNotifications.notifyLaunchFailed(
                    programName: self.name,
                    bottleName: self.bottle.settings.name,
                    reason: error.localizedDescription
                )
                await MainActor.run {
                    self.showRunError(message: error.localizedDescription)
                }
            }
        }
    }
    // swiftlint:enable function_body_length cyclomatic_complexity

    private func prepareMinecraftDungeonsDirectLaunch(
        environment: [String: String],
        shouldForceDirectLaunch: Bool
    ) async {
        guard shouldForceDirectLaunch else {
            return
        }

        await ensureMinecraftDungeonsAppDefaults(environment: environment)
    }

    private func runInNativeGameMode(launchURL: URL, arguments: [String], environment: [String: String]) throws {
        let launcherURL = try buildNativeGameModeLauncher(
            launchURL: launchURL,
            arguments: arguments,
            environment: environment
        )

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/open")
        process.arguments = ["-n", launcherURL.path(percentEncoded: false)]
        process.qualityOfService = .userInitiated
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "Vector.GameModeLaunch",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Failed to launch native Game Mode wrapper."
                ]
            )
        }
    }

    // swiftlint:disable function_body_length
    private func buildNativeGameModeLauncher(
        launchURL: URL,
        arguments: [String],
        environment: [String: String]
    ) throws -> URL {
        let launcherRoot = bottle.url.appending(path: Self.gameModeLaunchersDirectoryName)
        let sanitizedName = name
            .replacingOccurrences(of: ".exe", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let launcherName = sanitizedName.isEmpty ? "Game" : sanitizedName
        let appURL = launcherRoot.appending(path: launcherName).appendingPathExtension("app")
        let contentsURL = appURL.appending(path: "Contents")
        let macOSURL = contentsURL.appending(path: "MacOS")

        try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)

        let argumentString = arguments.joined(separator: " ")
        let runCommand = Wine.generateRunCommand(
            at: launchURL,
            bottle: bottle,
            args: argumentString,
            environment: environment
        )
        let launcherScript = """
        #!/bin/bash
        \(runCommand)
        """

        let launcherExecutableURL = macOSURL.appending(path: "launch")
        try launcherScript.write(to: launcherExecutableURL, atomically: false, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: launcherExecutableURL.path(percentEncoded: false)
        )

        let bundleIdentifierSuffix = String(UInt64(bitPattern: Int64(url.path(percentEncoded: false).hashValue)))
        let plistContents = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleExecutable</key>
            <string>launch</string>
            <key>CFBundleIdentifier</key>
            <string>com.isaacmarovitz.Vector.GameMode.\(bundleIdentifierSuffix)</string>
            <key>CFBundleName</key>
            <string>\(launcherName)</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleSupportedPlatforms</key>
            <array>
                <string>MacOSX</string>
            </array>
            <key>LSMinimumSystemVersion</key>
            <string>14.0</string>
            <key>LSApplicationCategoryType</key>
            <string>public.app-category.games</string>
            <key>LSSupportsGameMode</key>
            <true/>
            <key>GCSupportsGameMode</key>
            <true/>
        </dict>
        </plist>
        """

        try plistContents.write(
            to: contentsURL.appending(path: "Info").appendingPathExtension("plist"),
            atomically: false,
            encoding: .utf8
        )

        return appURL
    }
    // swiftlint:enable function_body_length

    public func generateTerminalCommand() -> String {
        var arguments = runtimeArguments()
        let launchURL = resolvedLaunchExecutableURL(arguments: &arguments)
        let argumentString = arguments.joined(separator: " ")
        return Wine.generateRunCommand(
            at: launchURL, bottle: bottle, args: argumentString, environment: runtimeEnvironment()
        )
    }

    public func runInTerminal() {
        let wineCmd = generateTerminalCommand().replacingOccurrences(of: "\\", with: "\\\\")

        let script = """
        tell application "Terminal"
            activate
            do script "\(wineCmd)"
        end tell
        """

        Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else { return }
            appleScript.executeAndReturnError(&error)

            if let error = error {
                Logger.wineKit.error("Failed to run terminal script \(error)")
                guard let description = error["NSAppleScriptErrorMessage"] as? String else { return }
                VectorNotifications.notifyLaunchFailed(
                    programName: self.name,
                    bottleName: self.bottle.settings.name,
                    reason: description
                )
                await self.showRunError(message: String(describing: description))
            } else {
                VectorNotifications.notifyLaunchSucceeded(
                    programName: self.name,
                    bottleName: self.bottle.settings.name
                )
            }
        }
    }

    @MainActor private func showRunError(message: String) {
        let alert = NSAlert()
        alert.messageText = String(localized: "alert.message")
        alert.informativeText = String(localized: "alert.info")
        + " \(self.url.lastPathComponent): "
        + message
        alert.alertStyle = .critical
        alert.addButton(withTitle: String(localized: "button.ok"))
        alert.runModal()
    }

    private func runtimeEnvironment() -> [String: String] {
        var environment = generateEnvironment()
        applyBottleRuntimeSelection(to: &environment)
        applySteamUIRuntimeFallback(to: &environment)
        applyProfileEnvironment(to: &environment)
        applyInstallerCompatibilityEnvironmentOverrides(to: &environment)
        applyMediaPlaybackEnvironmentOverrides(to: &environment)
        applyHighOnLife2EnvironmentOverrides(to: &environment)
        applyParcelSimulatorEnvironmentOverrides(to: &environment)
        applyMinecraftDungeonsEnvironmentOverrides(to: &environment)
        applyContentWarningEnvironmentOverrides(to: &environment)
        applyTitanfall2EnvironmentOverrides(to: &environment)
        applyOriginEnvironmentOverrides(to: &environment)
        applySilentHillFEnvironmentOverrides(to: &environment)
        applyElectronWindowEnvironmentOverrides(to: &environment)
        if isSteamProgram {
            sanitizeSteamEnvironment(&environment, usingCompatibilityRuntime: isUsingSteamCompatibilityRuntime)
        }

        let normalizedPath = url.path(percentEncoded: false).lowercased()
        let runtimeSelection = bottle.settings.runtimeSelection
        let allowsSteamCompatibilityRuntime =
            runtimeSelection == .compatibility
            || (runtimeSelection == .auto && !VectorWineInstaller.isCrossOverBottleURL(bottle.url))
        let shouldUseSteamCompatRuntime =
            allowsSteamCompatibilityRuntime
            &&
            isUsingSteamCompatibilityRuntime
            &&
            isSteamProgram
            && (normalizedPath.contains("/program files (x86)/steam/")
                || normalizedPath.contains("/program files/steam/"))
        if shouldUseSteamCompatRuntime {
            if isSteamProgram {
                applySteamCompatibilityDLLOverrides(&environment)
            }
            injectSteamCompatibilityWineOverride(&environment)
        }
        applySteamEnvironmentOverrides(to: &environment)
        applyDLSSRuntimeTranslationEnvironmentOverrides(to: &environment)
        applySmartGraphicsBackendSelection(to: &environment)
        return environment
    }

    private func runtimeArguments() -> [String] {
        var arguments = settings.arguments.split { $0.isWhitespace }.map(String.init)

        guard isSteamProgram else {
            appendUnique(arguments: &arguments, newArguments: d3d11CompatibilityArguments())
            appendUnique(arguments: &arguments, newArguments: profileArguments())
            appendUnique(arguments: &arguments, newArguments: minecraftDungeonsCompatibilityArguments())
            appendUnique(arguments: &arguments, newArguments: electronWindowArguments())
            normalizeGraphicsAPIArguments(arguments: &arguments)
            return arguments
        }

        normalizeSteamAppLaunchArguments(
            arguments: &arguments,
            fallbackAppID: bottle.settings.activeSteamAppID
        )
        if steamLaunchesSpecificApp(arguments: arguments) {
            // Do not inject Steam client bootstrap/safe flags into app-launch commands.
            return steamRecoveryArguments(from: arguments)
        }

        resetSteamHTMLCacheIfNeeded()
        appendUnique(
            arguments: &arguments,
            newArguments: steamLaunchArguments()
        )
        if shouldApplySteamLegacyBootstrap() {
            appendUnique(arguments: &arguments, newArguments: steamBootstrapCompatibilityArguments())
        }

        if !bottle.settings.steamForceNoBrowser {
            removeArgument(arguments: &arguments, argumentToRemove: "-no-browser")
        }

        arguments = steamRecoveryArguments(from: arguments)
        normalizeGraphicsAPIArguments(arguments: &arguments)
        return arguments
    }

    private var isSteamProgram: Bool {
        url.lastPathComponent.caseInsensitiveCompare(Self.steamExecutable) == .orderedSame
    }

    private func appendUnique(arguments: inout [String], newArguments: [String]) {
        for argument in newArguments
        where !arguments.contains(where: { $0.caseInsensitiveCompare(argument) == .orderedSame }) {
            arguments.append(argument)
        }
    }

    private func removeArgument(arguments: inout [String], argumentToRemove: String) {
        arguments.removeAll { $0.caseInsensitiveCompare(argumentToRemove) == .orderedSame }
    }

    private func shouldRunSteamPostBootstrapPass(from arguments: [String]) -> Bool {
        guard isSteamProgram else {
            return false
        }

        return arguments.contains {
            $0.caseInsensitiveCompare(Self.steamBootstrapExitArgument) == .orderedSame
        }
    }

    private var isUsingSteamCompatibilityRuntime: Bool {
        VectorWineInstaller.steamCompatibilityWineBinary() != nil
    }

    private var isSteamCompatRuntimeActiveForLaunch: Bool {
        guard isSteamProgram else {
            return false
        }
        guard isUsingSteamCompatibilityRuntime else {
            return false
        }

        switch bottle.settings.runtimeSelection {
        case .compatibility:
            return true
        case .auto:
            return !VectorWineInstaller.isCrossOverBottleURL(bottle.url)
        case .bundled:
            // Even when bundled is selected, Steam UI launches are promoted to
            // compatibility runtime to avoid older bundled-runtime CEF breakage.
            return !steamSettingsLaunchesApp()
        case .crossover, .custom:
            return false
        }
    }

    private func steamLaunchArguments() -> [String] {
        guard bottle.settings.steamUseSafeLaunchFlags else {
            return []
        }

        // On compatibility runtime, forced legacy CEF flags can destabilize
        // modern Steam UI startup (blank/no window). Keep launch args lean.
        if isSteamCompatRuntimeActiveForLaunch {
            if bottle.settings.steamForceNoBrowser {
                return ["-no-browser"]
            }
            return []
        }

        var arguments = Self.steamSafeLaunchArguments
        if bottle.settings.steamUseLegacyExtraFlags && shouldApplySteamLegacyBootstrap() {
            arguments.append(contentsOf: Self.steamLegacyExtraLaunchArguments)
        }
        if bottle.settings.steamForceNoBrowser {
            arguments.append("-no-browser")
        }
        return arguments
    }

    private func shouldApplySteamLegacyBootstrap() -> Bool {
        guard !isSteamCompatRuntimeActiveForLaunch else {
            return false
        }

        return bottle.settings.steamUseLegacyBootstrap
    }

    private func steamBootstrapCompatibilityArguments() -> [String] {
        let archiveURL = steamPackageArchiveURL()

        guard let markerURL = steamBootstrapMarkerURL() else {
            return Self.steamPinnedBootstrapArgumentPrefix + ["-overridepackageurl", archiveURL]
        }

        let markerPath = markerURL.path(percentEncoded: false)
        if FileManager.default.fileExists(atPath: markerPath) {
            return Self.steamPinnedBootstrapArgumentPrefix + ["-overridepackageurl", archiveURL]
        }

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning("Failed to create Steam bootstrap marker at \(markerPath, privacy: .public)")
        }

        return Self.steamBootstrapArgumentPrefix + ["-overridepackageurl", archiveURL]
    }

    private func steamBootstrapMarkerURL() -> URL? {
        steamMarkerURL(filename: Self.steamBootstrapMarkerFilename)
    }

    private func steamHTMLCacheResetMarkerURL() -> URL? {
        steamMarkerURL(filename: Self.steamHTMLCacheResetMarkerFilename)
    }

    private func steamMarkerURL(filename: String) -> URL? {
        let steamDirectory = url.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: steamDirectory.path(percentEncoded: false)) else {
            return nil
        }

        return steamDirectory.appending(path: filename)
    }

    private func resetSteamHTMLCacheIfNeeded() {
        guard bottle.settings.steamResetHTMLCacheOnLaunch else {
            return
        }

        guard let markerURL = steamHTMLCacheResetMarkerURL() else {
            return
        }

        let markerPath = markerURL.path(percentEncoded: false)
        if FileManager.default.fileExists(atPath: markerPath) {
            return
        }

        clearSteamHTMLCache()

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning("Failed to create Steam cache reset marker at \(markerPath, privacy: .public)")
        }
    }

    private func clearSteamHTMLCache() {
        let usersDirectory = bottle.url
            .appending(path: "drive_c")
            .appending(path: "users")

        guard let userDirectories = try? FileManager.default.contentsOfDirectory(
            at: usersDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for userDirectory in userDirectories {
            let htmlCacheDirectory = userDirectory
                .appending(path: "AppData")
                .appending(path: "Local")
                .appending(path: "Steam")
                .appending(path: "htmlcache")

            let cachePath = htmlCacheDirectory.path(percentEncoded: false)
            guard FileManager.default.fileExists(atPath: cachePath) else {
                continue
            }

            do {
                try FileManager.default.removeItem(at: htmlCacheDirectory)
            } catch {
                Logger.wineKit.warning(
                    "Failed to remove Steam htmlcache at \(cachePath, privacy: .public)"
                )
                Logger.wineKit.warning(
                    "Steam htmlcache removal error: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func injectSteamCompatibilityWineOverride(_ environment: inout [String: String]) {
        guard let wineBinary = VectorWineInstaller.steamCompatibilityWineBinary(),
              let wineserverBinary = VectorWineInstaller.steamCompatibilityWineserverBinary() else {
            return
        }

        environment[Self.wineBinaryOverrideEnvironmentKey] = wineBinary.path(percentEncoded: false)
        environment[Self.wineserverBinaryOverrideEnvironmentKey] = wineserverBinary.path(percentEncoded: false)
    }

    private func runSteamInWine(arguments: [String], environment: [String: String]) async throws {
        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        if activeSteamAppID == "1672970", steamSettingsLaunchesApp() {
            await ensureSteamClientBuiltinsForGameD3DOverrides(environment: environment)
        } else {
            await clearSteamWebHelperBuiltinsIfNeeded(environment: environment)
        }
        await ensureGlobalMediaPlaybackDefaults(environment: environment)
        await ensureHighOnLife2AppDefaults(environment: environment)
        await ensureParcelSimulatorAppDefaults(environment: environment)
        await ensureMinecraftDungeonsAppDefaults(environment: environment)
        await ensureContentWarningAppDefaults(environment: environment)
        await ensureOriginAppDefaults(environment: environment)
        await ensureTitanfall2AppDefaults(environment: environment)
        await ensureSilentHillFAppDefaults(environment: environment)
        try await resetSteamWineserver(environment: environment)
        var launchStatus = try await Wine.runProgramDirectWithTerminationStatus(
            at: self.url,
            args: arguments,
            bottle: self.bottle,
            environment: environment
        )

        if shouldRunSteamPostBootstrapPass(from: arguments) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let postBootstrapArguments = runtimeArguments()
            launchStatus = try await Wine.runProgramDirectWithTerminationStatus(
                at: self.url,
                args: postBootstrapArguments,
                bottle: self.bottle,
                environment: environment
            )
        }

        guard launchStatus != 0 else {
            return
        }

        let latestArguments = runtimeArguments()
        let recoveryArguments = steamRecoveryArguments(from: latestArguments)
        guard !isSameArguments(lhs: recoveryArguments, rhs: latestArguments) else {
            return
        }

        Logger.wineKit.warning(
            "Steam exited with status \(launchStatus, privacy: .public). Retrying with reduced compatibility arguments."
        )
        try await resetSteamWineserver(environment: environment)
        try? await Task.sleep(nanoseconds: 500_000_000)
        _ = try await Wine.runProgramDirectWithTerminationStatus(
            at: self.url,
            args: recoveryArguments,
            bottle: self.bottle,
            environment: environment
        )
    }
}
// swiftlint:enable file_length
