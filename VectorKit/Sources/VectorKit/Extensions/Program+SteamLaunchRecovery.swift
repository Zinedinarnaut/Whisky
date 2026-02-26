//
//  Program+SteamLaunchRecovery.swift
//  VectorKit
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

extension Program {
    private static let steamDisabledNativeDLLOverrides = "nvapi,nvapi64=d"

    func steamRecoveryArguments(from arguments: [String]) -> [String] {
        var recoveredArguments: [String] = []
        var skipNext = false

        for argument in arguments {
            if skipNext {
                skipNext = false
                continue
            }

            if argument.caseInsensitiveCompare("-overridepackageurl") == .orderedSame {
                skipNext = true
                continue
            }

            if argument.caseInsensitiveCompare("-noverifyfiles") == .orderedSame
                || argument.caseInsensitiveCompare("-nobootstrapupdate") == .orderedSame
                || argument.caseInsensitiveCompare("-skipinitialbootstrap") == .orderedSame
                || argument.caseInsensitiveCompare("-norepairfiles") == .orderedSame
                || argument.caseInsensitiveCompare("-forcesteamupdate") == .orderedSame
                || argument.caseInsensitiveCompare("-forcepackagedownload") == .orderedSame
                || argument.caseInsensitiveCompare("-exitsteam") == .orderedSame
                || argument.caseInsensitiveCompare("-no-browser") == .orderedSame {
                continue
            }

            recoveredArguments.append(argument)
        }

        return recoveredArguments
    }

    func isSameArguments(lhs: [String], rhs: [String]) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }

        for (left, right) in zip(lhs, rhs)
        where left.caseInsensitiveCompare(right) != .orderedSame {
            return false
        }

        return true
    }

    func resetSteamWineserver(environment: [String: String]) async throws {
        guard VectorWineInstaller.steamCompatibilityWineBinary() != nil else {
            return
        }

        for await _ in try Wine.runWineserverProcess(
            name: "steam-prelaunch-wineserver-kill",
            args: ["-k"],
            bottle: bottle,
            environment: environment
        ) { }
    }

    func applySteamCompatibilityDLLOverrides(_ environment: inout [String: String]) {
        guard VectorWineInstaller.steamCompatibilityWineBinary() != nil else {
            return
        }

        let current = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if current.localizedCaseInsensitiveContains("nvapi64")
            || current.localizedCaseInsensitiveContains("nvapi") {
            return
        }

        if current.isEmpty {
            environment["WINEDLLOVERRIDES"] = Self.steamDisabledNativeDLLOverrides
        } else {
            environment["WINEDLLOVERRIDES"] = "\(current);\(Self.steamDisabledNativeDLLOverrides)"
        }
    }
}
