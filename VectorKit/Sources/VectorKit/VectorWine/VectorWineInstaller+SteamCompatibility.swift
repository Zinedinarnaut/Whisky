//
//  VectorWineInstaller+SteamCompatibility.swift
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

public extension VectorWineInstaller {
    static func steamCompatibilityWineBinary() -> URL? {
        resolveSteamCompatibilityExecutable(
            environmentKey: "VECTOR_STEAM_WINE_BIN",
            defaultsKey: "steamCompatibilityWineBinaryPath",
            defaultLeafPath: "wine"
        )
    }

    static func steamCompatibilityWineserverBinary() -> URL? {
        resolveSteamCompatibilityExecutable(
            environmentKey: "VECTOR_STEAM_WINESERVER_BIN",
            defaultsKey: "steamCompatibilityWineserverBinaryPath",
            defaultLeafPath: "wineserver"
        )
    }
}

private extension VectorWineInstaller {
    static var defaultSteamCompatibilityWineFolder: URL {
        applicationFolder
            .appending(path: "Compatibility")
            .appending(path: "SteamWine")
    }

    static func resolveSteamCompatibilityExecutable(
        environmentKey: String, defaultsKey: String, defaultLeafPath: String
    ) -> URL? {
        let environment = ProcessInfo.processInfo.environment
        let overridePath = environment[environmentKey] ?? UserDefaults.standard.string(forKey: defaultsKey)
        if let overridePath,
           !overridePath.isEmpty {
            let overrideURL = URL(fileURLWithPath: overridePath)
            let path = overrideURL.path(percentEncoded: false)
            return FileManager.default.isExecutableFile(atPath: path) ? overrideURL : nil
        }

        let defaultURL = defaultSteamCompatibilityWineFolder
            .appending(path: "Wine Stable.app")
            .appending(path: "Contents")
            .appending(path: "Resources")
            .appending(path: "wine")
            .appending(path: "bin")
            .appending(path: defaultLeafPath)

        let defaultPath = defaultURL.path(percentEncoded: false)
        return FileManager.default.isExecutableFile(atPath: defaultPath) ? defaultURL : nil
    }
}
