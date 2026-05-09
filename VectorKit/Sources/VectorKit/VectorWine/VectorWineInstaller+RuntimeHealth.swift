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
            let binaryInfo = RuntimeBinaryInfo.inspect(url: url)
            return [
                "path": path,
                "present": FileManager.default.fileExists(atPath: path) ? "true" : "false",
                "binaryFormat": binaryInfo.format,
                "architectures": binaryInfo.architectures.joined(separator: ","),
                "hostExecutableNative": binaryInfo.hostExecutableNative,
                "outsideAppBundle": isOutsideMainAppBundle(url)
            ]
        }
        let payload: [String: Any] = [
            "schemaVersion": 2,
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

private struct RuntimeBinaryInfo {
    var format: String
    var architectures: [String]
    var hostExecutableNative: String

    static func inspect(url: URL) -> RuntimeBinaryInfo {
        guard let data = readHeader(url: url),
              !data.isEmpty else {
            return RuntimeBinaryInfo(format: "missing", architectures: [], hostExecutableNative: "false")
        }

        if let architectures = machoArchitectures(in: data) {
            return RuntimeBinaryInfo(
                format: "mach-o",
                architectures: architectures,
                hostExecutableNative: nativeStatus(for: architectures)
            )
        }

        if let architecture = peArchitecture(in: data) {
            return RuntimeBinaryInfo(
                format: "pe",
                architectures: [architecture],
                hostExecutableNative: "not-applicable"
            )
        }

        return RuntimeBinaryInfo(format: "unknown", architectures: [], hostExecutableNative: "unknown")
    }

    private static func readHeader(url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer {
            try? handle.close()
        }
        return try? handle.read(upToCount: 4_096)
    }

    private static func nativeStatus(for architectures: [String]) -> String {
        #if arch(arm64)
        return architectures.contains("arm64") ? "true" : "false"
        #elseif arch(x86_64)
        return architectures.contains("x86_64") ? "true" : "false"
        #else
        return "unknown"
        #endif
    }

    private static func machoArchitectures(in data: Data) -> [String]? {
        guard data.count >= 8 else { return nil }

        let magic = data.prefix(4)
        if magic.matches([0xca, 0xfe, 0xba, 0xbe]) || magic.matches([0xca, 0xfe, 0xba, 0xbf]) {
            return fatMachOArchitectures(in: data, littleEndian: false)
        }
        if magic.matches([0xbe, 0xba, 0xfe, 0xca]) || magic.matches([0xbf, 0xba, 0xfe, 0xca]) {
            return fatMachOArchitectures(in: data, littleEndian: true)
        }
        if magic.matches([0xfe, 0xed, 0xfa, 0xce]) || magic.matches([0xfe, 0xed, 0xfa, 0xcf]) {
            return cpuType(at: 4, in: data, littleEndian: false).map { [architectureName(for: $0)] }
        }
        if magic.matches([0xce, 0xfa, 0xed, 0xfe]) || magic.matches([0xcf, 0xfa, 0xed, 0xfe]) {
            return cpuType(at: 4, in: data, littleEndian: true).map { [architectureName(for: $0)] }
        }

        return nil
    }

    private static func fatMachOArchitectures(in data: Data, littleEndian: Bool) -> [String]? {
        guard let count = unsigned32(at: 4, in: data, littleEndian: littleEndian) else {
            return nil
        }
        var architectures: [String] = []
        let recordSize = 20
        for index in 0..<min(Int(count), 16) {
            let offset = 8 + index * recordSize
            guard let type = cpuType(at: offset, in: data, littleEndian: littleEndian) else {
                break
            }
            architectures.append(architectureName(for: type))
        }
        return architectures.isEmpty ? nil : architectures
    }

    private static func peArchitecture(in data: Data) -> String? {
        guard data.count >= 64,
              data[0] == 0x4d,
              data[1] == 0x5a,
              let headerOffset = unsigned32(at: 60, in: data, littleEndian: true) else {
            return nil
        }

        let peOffset = Int(headerOffset)
        guard peOffset >= 0,
              data.count >= peOffset + 6,
              data[peOffset] == 0x50,
              data[peOffset + 1] == 0x45,
              data[peOffset + 2] == 0,
              data[peOffset + 3] == 0,
              let machine = unsigned16(at: peOffset + 4, in: data, littleEndian: true) else {
            return nil
        }

        switch machine {
        case 0x014c: return "i386"
        case 0x8664: return "x86_64"
        case 0x01c0: return "arm"
        case 0xaa64: return "arm64"
        default: return "pe-0x\(String(machine, radix: 16))"
        }
    }

    private static func cpuType(at offset: Int, in data: Data, littleEndian: Bool) -> Int32? {
        unsigned32(at: offset, in: data, littleEndian: littleEndian).map { Int32(bitPattern: $0) }
    }

    private static func unsigned16(at offset: Int, in data: Data, littleEndian: Bool) -> UInt16? {
        guard data.count >= offset + 2 else { return nil }
        let value = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        return littleEndian ? value.byteSwapped : value
    }

    private static func unsigned32(at offset: Int, in data: Data, littleEndian: Bool) -> UInt32? {
        guard data.count >= offset + 4 else { return nil }
        let value = UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
        return littleEndian ? value.byteSwapped : value
    }

    private static func architectureName(for cpuType: Int32) -> String {
        switch cpuType {
        case 7: return "i386"
        case 12: return "arm"
        case 16_777_223: return "x86_64"
        case 16_777_228: return "arm64"
        case 33_554_444: return "arm64_32"
        default: return "cpu-\(cpuType)"
        }
    }
}

private func isOutsideMainAppBundle(_ url: URL) -> String {
    let payloadPath = url.standardizedFileURL.path(percentEncoded: false)
    let appBundlePath = Bundle.main.bundleURL.standardizedFileURL.path(percentEncoded: false)
    return payloadPath.hasPrefix(appBundlePath + "/") ? "false" : "true"
}

private extension Data.SubSequence {
    func matches(_ bytes: [UInt8]) -> Bool {
        elementsEqual(bytes)
    }
}
