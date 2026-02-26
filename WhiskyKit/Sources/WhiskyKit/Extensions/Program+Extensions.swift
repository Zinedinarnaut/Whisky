//
//  Program+Extensions.swift
//  Whisky
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import Foundation
import AppKit
import os.log

extension Program {
    private static let steamExecutable = "steam.exe"
    private static let steamSafeLaunchArguments = [
        "-no-browser",
        "-cef-disable-gpu",
        "-cef-disable-gpu-compositing",
        "-cef-disable-d3d11",
        "-no-cef-sandbox"
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
        generateEnvironment()
    }

    private func runtimeArguments() -> [String] {
        var arguments = settings.arguments.split { $0.isWhitespace }.map(String.init)

        guard isSteamProgram else {
            return arguments
        }

        for argument in Self.steamSafeLaunchArguments
        where !arguments.contains(where: { $0.caseInsensitiveCompare(argument) == .orderedSame }) {
            arguments.append(argument)
        }

        return arguments
    }

    private var isSteamProgram: Bool {
        url.lastPathComponent.caseInsensitiveCompare(Self.steamExecutable) == .orderedSame
    }
}
