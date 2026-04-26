//
//  VectorWineInstaller+CrossOver.swift
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
    static func crossOverWineBinary() -> URL? {
        resolveCrossOverExecutable(
            environmentKey: "VECTOR_CROSSOVER_WINE_BIN",
            defaultsKey: "crossOverWineBinaryPath",
            defaultLeafPath: "wine64",
            fallbackLeafPaths: ["wine"]
        )
    }

    static func crossOverWineserverBinary() -> URL? {
        resolveCrossOverExecutable(
            environmentKey: "VECTOR_CROSSOVER_WINESERVER_BIN",
            defaultsKey: "crossOverWineserverBinaryPath",
            defaultLeafPath: "wineserver"
        )
    }

    static func crossOverRuntimeBinaries() -> (wine: URL, wineserver: URL)? {
        guard let wine = crossOverWineBinary(),
              let wineserver = crossOverWineserverBinary() else {
            return nil
        }

        return (wine, wineserver)
    }

    static func isCrossOverBottleURL(_ bottleURL: URL) -> Bool {
        let fileManager = FileManager.default
        let bottlePath = bottleURL.path(percentEncoded: false)

        // CrossOver bottles include this file at bottle root.
        let bottleConfigPath = bottleURL
            .appending(path: "cxbottle.conf")
            .path(percentEncoded: false)
        if fileManager.fileExists(atPath: bottleConfigPath) {
            return true
        }

        let normalizedPath = bottlePath.replacingOccurrences(of: "\\", with: "/").lowercased()
        let knownPathFragments = [
            "/library/application support/crossover/bottles/",
            "/library/application support/com.codeweavers.crossover/bottles/"
        ]
        return knownPathFragments.contains(where: { normalizedPath.contains($0) })
    }
}

private extension VectorWineInstaller {
    static func resolveCrossOverExecutable(
        environmentKey: String, defaultsKey: String, defaultLeafPath: String,
        fallbackLeafPaths: [String] = []
    ) -> URL? {
        let environment = ProcessInfo.processInfo.environment
        let overridePath = environment[environmentKey] ?? UserDefaults.standard.string(forKey: defaultsKey)
        if let overridePath,
           !overridePath.isEmpty {
            let overrideURL = URL(fileURLWithPath: overridePath)
            let path = overrideURL.path(percentEncoded: false)
            return FileManager.default.isExecutableFile(atPath: path) ? overrideURL : nil
        }

        var candidateURLs: [URL] = []
        for binDirectory in crossOverBinDirectories() {
            candidateURLs.append(binDirectory.appending(path: defaultLeafPath))
            for fallbackLeafPath in fallbackLeafPaths {
                candidateURLs.append(binDirectory.appending(path: fallbackLeafPath))
            }
        }

        for candidateURL in candidateURLs {
            let candidatePath = candidateURL.path(percentEncoded: false)
            if FileManager.default.isExecutableFile(atPath: candidatePath) {
                return candidateURL
            }
        }

        return nil
    }

    static func crossOverBinDirectories() -> [URL] {
        let appCandidates = discoveredCrossOverAppBundles()
        var candidateDirectories: [URL] = []

        for appURL in appCandidates {
            candidateDirectories.append(
                appURL
                    .appending(path: "Contents")
                    .appending(path: "SharedSupport")
                    .appending(path: "CrossOver")
                    .appending(path: "bin")
            )
            candidateDirectories.append(
                appURL
                    .appending(path: "Contents")
                    .appending(path: "Resources")
                    .appending(path: "wine")
                    .appending(path: "bin")
            )
        }

        var seen = Set<String>()
        return candidateDirectories.filter { seen.insert($0.path(percentEncoded: false)).inserted }
    }

    static func discoveredCrossOverAppBundles() -> [URL] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let searchRoots = [
            URL(filePath: "/Applications"),
            home.appending(path: "Applications")
        ]

        var candidates: [URL] = [
            URL(filePath: "/Applications/CrossOver.app"),
            URL(filePath: "/Applications/CrossOver Preview.app"),
            home.appending(path: "Applications/CrossOver.app"),
            home.appending(path: "Applications/CrossOver Preview.app")
        ]

        for root in searchRoots {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for entry in entries {
                let name = entry.lastPathComponent.lowercased()
                guard name.hasPrefix("crossover"),
                      name.hasSuffix(".app") else {
                    continue
                }
                candidates.append(entry)
            }
        }

        var seen = Set<String>()
        return candidates.filter { candidate in
            let path = candidate.path(percentEncoded: false)
            guard seen.insert(path).inserted else { return false }
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }
}
