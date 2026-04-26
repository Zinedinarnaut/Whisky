//
//  Winetricks.swift
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
import VectorKit

enum WinetricksCategories: String {
    case apps
    case benchmarks
    case dlls
    case fonts
    case games
    case settings
}

struct WinetricksVerb: Identifiable {
    var id = UUID()

    var name: String
    var description: String
}

struct WinetricksCategory {
    var category: WinetricksCategories
    var verbs: [WinetricksVerb]
}

class Winetricks {
    static let winetricksURL: URL = VectorWineInstaller.libraryFolder
        .appending(path: "winetricks")

    // swiftlint:disable function_body_length
    static func runCommand(command: String, bottle: Bottle) async {
        guard let resourcesURL = Bundle.main.url(forResource: "cabextract", withExtension: nil)?
            .deletingLastPathComponent() else { return }
        let runtime = resolveRuntimeBinaries(for: bottle)
        let runtimeBinDirectory = runtime.wine.deletingLastPathComponent().path(percentEncoded: false)
        let bundledWineserverPath = VectorWineInstaller.binFolder
            .appending(path: "wineserver")
            .path(percentEncoded: false)
        let compatibilityWineserverPath = VectorWineInstaller.steamCompatibilityWineserverBinary()?
            .path(percentEncoded: false)
        let escapedPrefixPath = shellEscapedForDoubleQuotes(bottle.url.path)
        let escapedBundledWineserverPath = shellEscapedForDoubleQuotes(bundledWineserverPath)

        var preKillCommands: [String] = [
            "WINEPREFIX=\"\(escapedPrefixPath)\" \"\(escapedBundledWineserverPath)\" -k >/dev/null 2>&1 || true"
        ]
        if let compatibilityWineserverPath {
            let escapedCompatibilityWineserverPath = shellEscapedForDoubleQuotes(compatibilityWineserverPath)
            let compatibilityKillCommand =
                "WINEPREFIX=\"\(escapedPrefixPath)\" \"\(escapedCompatibilityWineserverPath)\" "
                + "-k >/dev/null 2>&1 || true"
            preKillCommands.append(
                compatibilityKillCommand
            )
        }
        let preKillPrefix = preKillCommands.joined(separator: "\n")
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return }
        let escapedRuntimePath = shellEscapedForDoubleQuotes(runtimeBinDirectory)
        let escapedResourcesPath = shellEscapedForDoubleQuotes(resourcesURL.path(percentEncoded: false))
        let escapedPathPrefix = "\(escapedRuntimePath):\(escapedResourcesPath)"

        let scriptURL = FileManager.default.temporaryDirectory
            .appending(path: "vector-winetricks-\(UUID().uuidString).sh")
        let scriptContents = """
        #!/bin/zsh
        \(preKillPrefix)
        PATH="\(escapedPathPrefix):$PATH"
        WINE="\(shellEscapedForDoubleQuotes(runtime.wine.path(percentEncoded: false)))"
        WINESERVER="\(shellEscapedForDoubleQuotes(runtime.wineserver.path(percentEncoded: false)))"
        WINEPREFIX="\(shellEscapedForDoubleQuotes(bottle.url.path))"
        export PATH WINE WINESERVER WINEPREFIX
        "\(shellEscapedForDoubleQuotes(winetricksURL.path(percentEncoded: false)))" \(trimmedCommand)
        rm -f -- "$0"
        """

        do {
            try scriptContents.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: scriptURL.path(percentEncoded: false)
            )
        } catch {
            VectorNotifications.notifyMaintenanceFailed(
                task: "Winetricks",
                bottleName: bottle.settings.name,
                reason: error.localizedDescription
            )
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = String(localized: "alert.message")
                alert.informativeText = String(localized: "alert.info")
                    + " \(command): "
                    + error.localizedDescription
                alert.alertStyle = .critical
                alert.addButton(withTitle: String(localized: "button.ok"))
                alert.runModal()
            }
            return
        }

        let winetricksCmd = "/bin/zsh \(scriptURL.path(percentEncoded: false).esc)"
        let appleScriptCommand = winetricksCmd
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Terminal"
            activate
            do script "\(appleScriptCommand)"
        end tell
        """

        let appleScriptErrorMessage: String? = await MainActor.run {
            var appleScriptError: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else {
                return "Unable to create AppleScript command."
            }
            appleScript.executeAndReturnError(&appleScriptError)
            guard let appleScriptError else {
                return nil
            }
            if let description = appleScriptError["NSAppleScriptErrorMessage"] as? String {
                return description
            }
            return "Unknown AppleScript error."
        }

        if let description = appleScriptErrorMessage {
            VectorNotifications.notifyMaintenanceFailed(
                task: "Winetricks",
                bottleName: bottle.settings.name,
                reason: description
            )
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = String(localized: "alert.message")
                alert.informativeText = String(localized: "alert.info")
                    + " \(command): "
                    + description
                alert.alertStyle = .critical
                alert.addButton(withTitle: String(localized: "button.ok"))
                alert.runModal()
            }
        } else {
            VectorNotifications.notifyMaintenanceStarted(
                task: "Winetricks (\(command))",
                bottleName: bottle.settings.name
            )
        }
    }
    // swiftlint:enable function_body_length

    private static func shellEscapedForDoubleQuotes(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func resolveRuntimeBinaries(for bottle: Bottle) -> (wine: URL, wineserver: URL) {
        let bundledWine = VectorWineInstaller.binFolder.appending(path: "wine64")
        let bundledWineserver = VectorWineInstaller.binFolder.appending(path: "wineserver")

        // Prefer the Steam compatibility runtime for Winetricks when available:
        // bundled wine can be too old for modern dotnet verbs.
        if let compatibilityWine = VectorWineInstaller.steamCompatibilityWineBinary(),
           let compatibilityWineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() {
            switch bottle.settings.runtimeSelection {
            case .custom:
                break
            case .crossover:
                break
            case .auto:
                if VectorWineInstaller.isCrossOverBottleURL(bottle.url) {
                    break
                }
                return (compatibilityWine, compatibilityWineserver)
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

    static func parseVerbs() async -> [WinetricksCategory] {
        // Grab the verbs file
        let verbsURL = VectorWineInstaller.libraryFolder.appending(path: "verbs.txt")
        let verbs: String = await { () async -> String in
            do {
                let (data, _) = try await URLSession.shared.data(from: verbsURL)
                return String(data: data, encoding: .utf8) ?? String()
            } catch {
                return String()
            }
        }()

        // Read the file line by line
        let lines = verbs.components(separatedBy: "\n")
        var categories: [WinetricksCategory] = []
        var currentCategory: WinetricksCategory?

        for line in lines {
            // Categories are label as "===== <name> ====="
            if line.starts(with: "=====") {
                // If we have a current category, add it to the list
                if let currentCategory = currentCategory {
                    categories.append(currentCategory)
                }

                // Create a new category
                // Capitalize the first letter of the category name
                let categoryName = line.replacingOccurrences(of: "=====", with: "").trimmingCharacters(in: .whitespaces)
                if let cateogry = WinetricksCategories(rawValue: categoryName) {
                    currentCategory = WinetricksCategory(category: cateogry,
                                                         verbs: [])
                } else {
                    currentCategory = nil
                }
            } else {
                guard currentCategory != nil else {
                    continue
                }

                // If we have a current category, add the verb to it
                // Verbs eg. "3m_library               3M Cloud Library (3M Company, 2015) [downloadable]"
                let verbName = line.components(separatedBy: " ")[0]
                let verbDescription = line.replacingOccurrences(of: "\(verbName) ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                currentCategory?.verbs.append(WinetricksVerb(name: verbName, description: verbDescription))
            }
        }

        // Add the last category
        if let currentCategory = currentCategory {
            categories.append(currentCategory)
        }

        return categories
    }
}
