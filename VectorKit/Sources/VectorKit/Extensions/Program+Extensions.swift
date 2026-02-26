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

extension Program {
    private static let wineBinaryOverrideEnvironmentKey = "VECTOR_WINE_BIN_OVERRIDE"
    private static let wineserverBinaryOverrideEnvironmentKey = "VECTOR_WINESERVER_BIN_OVERRIDE"
    private static let steamExecutable = "steam.exe"
    private static let steamPackageArchiveURL =
        "http://web.archive.org/web/20250306194830if_/media.steampowered.com/client"
    private static let steamBootstrapMarkerFilename = ".vector-steam-bootstrap-v1"
    private static let steamHTMLCacheResetMarkerFilename = ".vector-steam-htmlcache-reset-v2"
    private static let steamDisableSafeFlagsDefaultsKey = "steamDisableAutoSafeLaunchFlags"
    private static let steamUseLegacyBootstrapDefaultsKey = "steamUseLegacyBootstrap"
    private static let steamForceNoBrowserDefaultsKey = "steamForceNoBrowser"
    private static let steamUseLegacyExtraFlagsDefaultsKey = "steamUseLegacyExtraFlags"
    private static let steamSafeLaunchArguments = [
        "-cef-disable-gpu",
        "-cef-disable-gpu-compositing",
        "-cef-disable-d3d11",
        "-no-cef-sandbox"
    ]
    private static let steamLegacyExtraLaunchArguments = [
        "-cef-disable-breakpad",
        "-cef-force-32bit",
        "-nocrashmonitor",
        "-noshaders"
    ]
    private static let steamBootstrapArguments = [
        "-forcesteamupdate",
        "-forcepackagedownload",
        "-overridepackageurl",
        steamPackageArchiveURL,
        "-exitsteam"
    ]
    private static let steamPinnedBootstrapArguments = [
        "-noverifyfiles",
        "-nobootstrapupdate",
        "-skipinitialbootstrap",
        "-norepairfiles",
        "-overridepackageurl",
        steamPackageArchiveURL
    ]

    public func run() {
        if NSEvent.modifierFlags.contains(.shift) {
            self.runInTerminal()
        } else {
            self.runInWine()
        }
    }

    func runInWine() {
        let arguments = runtimeArguments()
        let environment = runtimeEnvironment()

        Task.detached(priority: .userInitiated) {
            do {
                try await Wine.runProgram(
                    at: self.url, args: arguments, bottle: self.bottle, environment: environment
                )
            } catch {
                await MainActor.run {
                    self.showRunError(message: error.localizedDescription)
                }
            }
        }
    }

    public func generateTerminalCommand() -> String {
        let arguments = runtimeArguments().joined(separator: " ")
        return Wine.generateRunCommand(
            at: self.url, bottle: bottle, args: arguments, environment: runtimeEnvironment()
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
                await self.showRunError(message: String(describing: description))
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
        guard isSteamProgram else {
            return environment
        }

        sanitizeSteamEnvironment(&environment, usingCompatibilityRuntime: isUsingSteamCompatibilityRuntime)
        injectSteamCompatibilityWineOverride(&environment)
        return environment
    }

    private func runtimeArguments() -> [String] {
        var arguments = settings.arguments.split { $0.isWhitespace }.map(String.init)

        guard isSteamProgram else {
            return arguments
        }

        resetSteamHTMLCacheIfNeeded()
        appendUnique(
            arguments: &arguments,
            newArguments: steamLaunchArguments()
        )
        if shouldApplySteamLegacyBootstrap() {
            appendUnique(arguments: &arguments, newArguments: steamBootstrapCompatibilityArguments())
        }

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

    private var isUsingSteamCompatibilityRuntime: Bool {
        VectorWineInstaller.steamCompatibilityWineBinary() != nil
    }

    private func steamLaunchArguments() -> [String] {
        if UserDefaults.standard.bool(forKey: Self.steamDisableSafeFlagsDefaultsKey) {
            return []
        }

        var arguments = Self.steamSafeLaunchArguments
        if UserDefaults.standard.bool(forKey: Self.steamUseLegacyExtraFlagsDefaultsKey) {
            arguments.append(contentsOf: Self.steamLegacyExtraLaunchArguments)
        }
        if UserDefaults.standard.bool(forKey: Self.steamForceNoBrowserDefaultsKey) {
            arguments.append("-no-browser")
        }
        return arguments
    }

    private func shouldApplySteamLegacyBootstrap() -> Bool {
        guard !isUsingSteamCompatibilityRuntime else {
            return false
        }

        return UserDefaults.standard.bool(forKey: Self.steamUseLegacyBootstrapDefaultsKey)
    }

    private func steamBootstrapCompatibilityArguments() -> [String] {
        guard let markerURL = steamBootstrapMarkerURL() else {
            return Self.steamPinnedBootstrapArguments
        }

        let markerPath = markerURL.path(percentEncoded: false)
        if FileManager.default.fileExists(atPath: markerPath) {
            return Self.steamPinnedBootstrapArguments
        }

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning("Failed to create Steam bootstrap marker at \(markerPath, privacy: .public)")
        }

        return Self.steamBootstrapArguments
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

    private func sanitizeSteamEnvironment(
        _ environment: inout [String: String],
        usingCompatibilityRuntime: Bool
    ) {
        if usingCompatibilityRuntime {
            // Preserve bottle graphics env so game processes launched by Steam keep DXVK/D3D11 support.
            return
        }

        environment["LC_ALL"] = "C"
        environment["LANG"] = "C"
        environment.removeValue(forKey: "LANGUAGE")
        environment["DXVK_ASYNC"] = "0"
        environment["DXVK_HUD"] = "0"
        environment["DXVK_LOG_LEVEL"] = "none"
        environment["WINEDLLOVERRIDES"] = ""
        environment["ROSETTA_ADVERTISE_AVX"] = "0"
    }

    private func injectSteamCompatibilityWineOverride(_ environment: inout [String: String]) {
        guard let wineBinary = VectorWineInstaller.steamCompatibilityWineBinary(),
              let wineserverBinary = VectorWineInstaller.steamCompatibilityWineserverBinary() else {
            return
        }

        environment[Self.wineBinaryOverrideEnvironmentKey] = wineBinary.path(percentEncoded: false)
        environment[Self.wineserverBinaryOverrideEnvironmentKey] = wineserverBinary.path(percentEncoded: false)
    }
}
