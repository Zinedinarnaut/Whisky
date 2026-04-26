//
//  VectorDoctorBundle.swift
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

import CryptoKit
import Foundation

public struct VectorDoctorBundleResult: Codable, Sendable {
    public var url: URL
    public var manifest: VectorDoctorBundleManifest
}

public struct VectorDoctorBundleManifest: Codable, Sendable {
    public var schemaVersion: Int
    public var generatedAt: String
    public var bottleName: String
    public var bottlePath: String
    public var doctorReportDigest: String
    public var vecPatchDigest: String
    public var runtimePatchDigest: String
    public var includedFiles: [String]
}

public enum VectorDoctorBundleError: LocalizedError {
    case archiveFailed(status: Int32, output: String)

    public var errorDescription: String? {
        switch self {
        case .archiveFailed(let status, let output):
            return "Diagnostic bundle archive failed with status \(status): \(output)"
        }
    }
}

public extension VectorDoctor {
    static func writeDiagnosticBundle(
        for bottle: Bottle,
        to destinationURL: URL,
        checkRemote: Bool = true
    ) async throws -> VectorDoctorBundleResult {
        let report = await report(for: bottle, checkRemote: checkRemote)
        let fileManager = FileManager.default
        let stagingURL = fileManager.temporaryDirectory
            .appending(path: "VectorDoctor-\(UUID().uuidString)", directoryHint: .isDirectory)
        let logsURL = stagingURL.appending(path: "logs", directoryHint: .isDirectory)

        try fileManager.createDirectory(at: logsURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingURL) }

        let doctorData = try writeJSON(report, named: "doctor.json", in: stagingURL)
        try writeJSON(report.hostCapabilities, named: "host-security.json", in: stagingURL)
        try writeJSON(report.runtimeAttestation, named: "runtime-attestation.json", in: stagingURL)
        try writeJSON(report.dispatch, named: "vecpatch-status.json", in: stagingURL)
        try writeJSON(report.bottle, named: "bottle-snapshot.json", in: stagingURL)
        try writeJSON(bottle.settings, named: "bottle-settings.json", in: stagingURL)
        try copyBottleMetadata(for: bottle, into: stagingURL)
        try copyRecentLogs(report.recentLogs, into: logsURL)

        var includedFiles = try recursiveFiles(in: stagingURL)
        let manifest = VectorDoctorBundleManifest(
            schemaVersion: 2,
            generatedAt: bundleIsoDateString(),
            bottleName: bottle.settings.name,
            bottlePath: bottle.url.path(percentEncoded: false),
            doctorReportDigest: sha256Hex(doctorData),
            vecPatchDigest: report.dispatch.effectiveRulesDigest,
            runtimePatchDigest: report.runtimeAttestation.runtimePatchDigest,
            includedFiles: includedFiles.sorted()
        )
        try writeJSON(manifest, named: "manifest.json", in: stagingURL)
        includedFiles = try recursiveFiles(in: stagingURL)

        if fileManager.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
            try fileManager.removeItem(at: destinationURL)
        }
        try createArchive(from: stagingURL, to: destinationURL)

        return VectorDoctorBundleResult(
            url: destinationURL,
            manifest: VectorDoctorBundleManifest(
                schemaVersion: manifest.schemaVersion,
                generatedAt: manifest.generatedAt,
                bottleName: manifest.bottleName,
                bottlePath: manifest.bottlePath,
                doctorReportDigest: manifest.doctorReportDigest,
                vecPatchDigest: manifest.vecPatchDigest,
                runtimePatchDigest: manifest.runtimePatchDigest,
                includedFiles: includedFiles.sorted()
            )
        )
    }
}

private extension VectorDoctor {
    @discardableResult
    static func writeJSON<T: Encodable>(_ value: T, named filename: String, in directory: URL) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        try data.write(to: directory.appending(path: filename), options: .atomic)
        return data
    }

    static func copyBottleMetadata(for bottle: Bottle, into directory: URL) throws {
        let metadataURL = bottle.url.appending(path: "Metadata").appendingPathExtension("plist")
        let destinationURL = directory.appending(path: "Metadata.plist")
        if FileManager.default.fileExists(atPath: metadataURL.path(percentEncoded: false)) {
            try FileManager.default.copyItem(at: metadataURL, to: destinationURL)
        }
    }

    static func copyRecentLogs(_ snippets: [VectorDoctorLogSnippet], into logsURL: URL) throws {
        for snippet in snippets {
            let sourceURL = URL(filePath: snippet.path)
            guard FileManager.default.fileExists(atPath: sourceURL.path(percentEncoded: false)) else {
                continue
            }
            let destinationURL = logsURL.appending(path: sourceURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }
    }

    static func recursiveFiles(in rootURL: URL) throws -> [String] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [String] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else {
                continue
            }
            let relative = fileURL.path(percentEncoded: false)
                .replacingOccurrences(of: rootURL.path(percentEncoded: false) + "/", with: "")
            files.append(relative)
        }
        return files
    }

    static func createArchive(from sourceURL: URL, to destinationURL: URL) throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = [
            "-c",
            "-k",
            "--sequesterRsrc",
            sourceURL.path(percentEncoded: false),
            destinationURL.path(percentEncoded: false)
        ]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw VectorDoctorBundleError.archiveFailed(status: process.terminationStatus, output: output)
        }
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func bundleIsoDateString() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
