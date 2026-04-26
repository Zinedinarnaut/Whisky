//
//  Program+SteamArguments.swift
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
    private static let steamAppLaunchArgument = "-applaunch"
    private static let steamAppLaunchTypoArgument = "-appluanch"
    private static let optionPrefix = "-"

    private func isAppLaunchToken(_ token: String) -> Bool {
        token.caseInsensitiveCompare(Self.steamAppLaunchArgument) == .orderedSame
            || token.caseInsensitiveCompare(Self.steamAppLaunchTypoArgument) == .orderedSame
    }

    private func isAppLaunchTargetToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        return !trimmed.hasPrefix(Self.optionPrefix)
    }

    func normalizeSteamAppLaunchArgument(arguments: inout [String]) {
        for index in arguments.indices where arguments[index]
            .caseInsensitiveCompare(Self.steamAppLaunchTypoArgument) == .orderedSame {
            arguments[index] = Self.steamAppLaunchArgument
        }
    }

    func normalizeSteamAppLaunchArguments(arguments: inout [String], fallbackAppID: String) {
        normalizeSteamAppLaunchArgument(arguments: &arguments)

        let normalizedFallbackAppID = fallbackAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        var index = 0
        while index < arguments.count {
            guard isAppLaunchToken(arguments[index]) else {
                index += 1
                continue
            }

            let nextIndex = index + 1
            if nextIndex < arguments.count, isAppLaunchTargetToken(arguments[nextIndex]) {
                index += 2
                continue
            }

            if !normalizedFallbackAppID.isEmpty {
                arguments.insert(normalizedFallbackAppID, at: nextIndex)
                index += 2
            } else {
                arguments.remove(at: index)
            }
        }
    }

    func steamLaunchesSpecificApp(arguments: [String]) -> Bool {
        var index = 0
        while index < arguments.count {
            if isAppLaunchToken(arguments[index]) {
                let nextIndex = index + 1
                return nextIndex < arguments.count && isAppLaunchTargetToken(arguments[nextIndex])
            }
            index += 1
        }

        return false
    }
}
