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

    static func runCommand(command: String, bottle: Bottle) async {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return }

        do {
            let scriptURL = try writeScript(
                command: trimmedCommand,
                bottle: bottle,
                unattended: false,
                waitForWineserverShutdown: true
            )
            await openScriptInTerminal(scriptURL: scriptURL, command: trimmedCommand, bottle: bottle)
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
    }

    private static func openScriptInTerminal(scriptURL: URL, command: String, bottle: Bottle) async {
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
