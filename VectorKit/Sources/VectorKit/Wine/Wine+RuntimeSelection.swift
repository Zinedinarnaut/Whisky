//
//  Wine+RuntimeSelection.swift
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

extension Wine {
    static func applyRuntimeSelectionOverrides(for bottle: Bottle, environment: inout [String: String]) {
        let wineOverrideKey = "VECTOR_WINE_BIN_OVERRIDE"
        let wineserverOverrideKey = "VECTOR_WINESERVER_BIN_OVERRIDE"

        func setRuntime(wine: URL, wineserver: URL) {
            environment[wineOverrideKey] = wine.path(percentEncoded: false)
            environment[wineserverOverrideKey] = wineserver.path(percentEncoded: false)
        }

        switch bottle.settings.runtimeSelection {
        case .auto:
            if VectorWineInstaller.isCrossOverBottleURL(bottle.url),
               let runtime = VectorWineInstaller.crossOverRuntimeBinaries() {
                setRuntime(wine: runtime.wine, wineserver: runtime.wineserver)
            }
        case .bundled:
            setRuntime(
                wine: Wine.wineBinary,
                wineserver: VectorWineInstaller.binFolder.appending(path: "wineserver")
            )
        case .compatibility:
            if let wine = VectorWineInstaller.steamCompatibilityWineBinary(),
               let wineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() {
                setRuntime(wine: wine, wineserver: wineserver)
            }
        case .crossover:
            if let runtime = VectorWineInstaller.crossOverRuntimeBinaries() {
                setRuntime(wine: runtime.wine, wineserver: runtime.wineserver)
            }
        case .custom:
            let customWinePath = bottle.settings.customWineBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let customWineserverPath = bottle.settings.customWineserverBinaryPath
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let fileManager = FileManager.default
            if fileManager.isExecutableFile(atPath: customWinePath),
               fileManager.isExecutableFile(atPath: customWineserverPath) {
                setRuntime(
                    wine: URL(filePath: customWinePath),
                    wineserver: URL(filePath: customWineserverPath)
                )
            }
        }
    }
}
