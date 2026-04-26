//
//  VectorWineInstaller+RuntimeHealth.swift
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

extension VectorWineInstaller {
    static func writeInstallHealthMetadata(manifest: VectorWineRuntimeManifest?) {
        let runtimeFiles = [
            binFolder.appending(path: "wine64"),
            binFolder.appending(path: "wineserver"),
            binFolder.appending(path: "vectorvmctl"),
            binFolder.appending(path: "vectorvmctl.exe")
        ]
        let records = runtimeFiles.map { url -> [String: String] in
            let path = url.path(percentEncoded: false)
            return [
                "path": path,
                "present": FileManager.default.fileExists(atPath: path) ? "true" : "false"
            ]
        }
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "manifestVersion": manifest?.version ?? "unknown",
            "vectorVMCTLSHA256": manifest?.vectorVMCTLSHA256 ?? "unknown",
            "files": records
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            let healthURL = libraryFolder.appending(path: "VectorRuntimeInstallHealth.json")
            try data.write(to: healthURL, options: .atomic)
        } catch {
            print("Failed to write Vector runtime install health: \(error)")
        }
    }
}
