//
//  WhiskyWineInstaller.swift
//  WhiskyKit
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

import CryptoKit
import Foundation
import SemanticVersion

public struct WhiskyWineRuntimeManifest: Codable, Sendable {
    public let version: String
    public let archiveURL: URL
    public let archiveSHA256: String
    public let wineVersion: String
    public let dxvkVersion: String
    public let d3dMetalVersion: String
    public let winetricksVersion: String
    public let wineMonoVersion: String

    public var semanticVersion: SemanticVersion {
        SemanticVersion(version) ?? SemanticVersion(0, 0, 0)
    }

    public var semanticWineVersion: SemanticVersion? {
        SemanticVersion(wineVersion)
    }
}

public enum WhiskyWineInstallerError: Error {
    case invalidManifestSignature
    case invalidManifestPayload
    case checksumMismatch(expected: String, actual: String)
}

public class WhiskyWineInstaller {
    /// The Whisky application folder
    public static let applicationFolder = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appending(path: Bundle.whiskyBundleIdentifier)

    /// The folder of all the libfrary files
    public static let libraryFolder = applicationFolder.appending(path: "Libraries")

    /// URL to the installed `wine` `bin` directory
    public static let binFolder: URL = libraryFolder.appending(path: "Wine").appending(path: "bin")

    private static let legacyArchiveURL: URL = {
        guard let url = URL(string: "https://data.getwhisky.app/Wine/Libraries.tar.gz") else {
            fatalError("Invalid URL string for legacyArchiveURL")
        }
        return url
    }()

    private static let defaultSignedManifestURL: URL = {
        guard let url = URL(string: "https://data.getwhisky.app/Wine/manifest.json") else {
            fatalError("Invalid URL string for signedManifestURL")
        }
        return url
    }()

    private static let legacyVersionPlistURL: URL = {
        guard let url = URL(string: "https://data.getwhisky.app/Wine/WhiskyWineVersion.plist") else {
            fatalError("Invalid URL string for legacyVersionPlistURL")
        }
        return url
    }()

    private static let manifestSigningPublicKey = "1OFop7oavBiAY9XvxcSi8BX96NFHVU0V9RFabpJpz2Y="
    private static let bundledManifestSignature =
        "DT9Ry8bWrBYkypX5PWCaK9VP0UdNR5gumD3CmQL32k9UnwcdCuwimNNyzHzNN/8DRHcCparEmdCPHMKKsF0YDg=="
    private static let runtimeManifestOverrideEnvironment = "WHISKY_RUNTIME_MANIFEST_URL"
    private static let runtimeManifestOverrideDefaultsKey = "whiskyWineManifestURL"

    public static let bundledRuntimeManifest = WhiskyWineRuntimeManifest(
        version: "2.5.0",
        archiveURL: legacyArchiveURL,
        archiveSHA256: "3283b80fb7ec7b105529a9a3fcd2628685e2c7ea6492536f123e758f79c4c077",
        wineVersion: "7.7.0",
        dxvkVersion: "1.10.3-20230507-repack",
        d3dMetalVersion: "2.0",
        winetricksVersion: "20250102",
        wineMonoVersion: "7.4.1"
    )

    public static func isWhiskyWineInstalled() -> Bool {
        return whiskyWineVersion() != nil
    }

    public static func runtimeManifest() async -> WhiskyWineRuntimeManifest {
        do {
            return try await fetchSignedRuntimeManifest()
        } catch {
            if (try? validateSignature(for: bundledRuntimeManifest, signature: bundledManifestSignature)) != true {
                print("Bundled runtime manifest signature validation failed")
            }
            return bundledRuntimeManifest
        }
    }

    public static func install(from: URL, manifest: WhiskyWineRuntimeManifest?) async throws {
        defer {
            try? FileManager.default.removeItem(at: from)
        }

        if !FileManager.default.fileExists(atPath: applicationFolder.path) {
            try FileManager.default.createDirectory(at: applicationFolder, withIntermediateDirectories: true)
        } else {
            // Recreate it
            try FileManager.default.removeItem(at: applicationFolder)
            try FileManager.default.createDirectory(at: applicationFolder, withIntermediateDirectories: true)
        }

        try Tar.untar(tarBall: from, toURL: applicationFolder)

        if let manifest {
            try writeRuntimeVersionMetadata(from: manifest)
        }
    }

    public static func uninstall() {
        do {
            try FileManager.default.removeItem(at: libraryFolder)
        } catch {
            print("Failed to uninstall WhiskyWine: \(error)")
        }
    }

    public static func shouldUpdateWhiskyWine() async -> (Bool, SemanticVersion) {
        let localVersion = whiskyWineVersion()

        if let remoteManifest = try? await fetchSignedRuntimeManifest() {
            let remoteVersion = remoteManifest.semanticVersion

            if let localVersion, localVersion < remoteVersion {
                return (true, remoteVersion)
            }

            return (false, SemanticVersion(0, 0, 0))
        }

        let remoteVersion = await fetchLegacyRemoteVersion()

        if let localVersion, let remoteVersion, localVersion < remoteVersion {
            return (true, remoteVersion)
        }

        return (false, SemanticVersion(0, 0, 0))
    }

    public static func verifyArchive(at fileURL: URL, expectedSHA256: String) throws {
        let actual = try sha256(of: fileURL)

        guard actual.caseInsensitiveCompare(expectedSHA256) == .orderedSame else {
            throw WhiskyWineInstallerError.checksumMismatch(expected: expectedSHA256, actual: actual)
        }
    }

    public static func whiskyWineInfo() -> WhiskyWineVersion? {
        do {
            let data = try Data(contentsOf: versionPlistPath)
            return try PropertyListDecoder().decode(WhiskyWineVersion.self, from: data)
        } catch {
            return nil
        }
    }

    public static func whiskyWineVersion() -> SemanticVersion? {
        whiskyWineInfo()?.version
    }

    public static func defaultWineVersion() -> SemanticVersion {
        if let installedWineVersion = whiskyWineInfo()?.wineVersion {
            return installedWineVersion
        }

        return bundledRuntimeManifest.semanticWineVersion ?? SemanticVersion(0, 0, 0)
    }
}

private extension WhiskyWineInstaller {
    struct RuntimeManifestEnvelope: Codable {
        let manifest: WhiskyWineRuntimeManifest
        let signature: String
    }

    static var versionPlistPath: URL {
        libraryFolder
            .appending(path: "WhiskyWineVersion")
            .appendingPathExtension("plist")
    }

    static func writeRuntimeVersionMetadata(from manifest: WhiskyWineRuntimeManifest) throws {
        var info = whiskyWineInfo() ?? WhiskyWineVersion()
        info.version = manifest.semanticVersion
        info.wineVersion = manifest.semanticWineVersion
        info.dxvkVersion = manifest.dxvkVersion
        info.d3dMetalVersion = manifest.d3dMetalVersion
        info.winetricksVersion = manifest.winetricksVersion
        info.wineMonoVersion = manifest.wineMonoVersion

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(info)
        try data.write(to: versionPlistPath)
    }

    static func fetchSignedRuntimeManifest() async throws -> WhiskyWineRuntimeManifest {
        var lastError: Error?

        for runtimeManifestURL in runtimeManifestURLs() {
            do {
                return try await fetchSignedRuntimeManifest(from: runtimeManifestURL)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? WhiskyWineInstallerError.invalidManifestPayload
    }

    static func fetchSignedRuntimeManifest(from runtimeManifestURL: URL) async throws -> WhiskyWineRuntimeManifest {
        let request = URLRequest(url: runtimeManifestURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: 20)
        let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw WhiskyWineInstallerError.invalidManifestPayload
        }

        let envelope = try JSONDecoder().decode(RuntimeManifestEnvelope.self, from: data)
        guard try validateSignature(for: envelope.manifest, signature: envelope.signature) else {
            throw WhiskyWineInstallerError.invalidManifestSignature
        }

        return envelope.manifest
    }

    static func runtimeManifestURLs() -> [URL] {
        var urls: [URL] = []

        let overrideURLString = ProcessInfo.processInfo.environment[runtimeManifestOverrideEnvironment]
            ?? UserDefaults.standard.string(forKey: runtimeManifestOverrideDefaultsKey)
        if let overrideURLString,
           let overrideURL = URL(string: overrideURLString) {
            urls.append(overrideURL)
        }

        urls.append(defaultSignedManifestURL)

        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }

    static func fetchLegacyRemoteVersion() async -> SemanticVersion? {
        do {
            let request = URLRequest(url: legacyVersionPlistURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                     timeoutInterval: 20)
            let (data, response) = try await URLSession(configuration: .ephemeral).data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            let remoteInfo = try PropertyListDecoder().decode(WhiskyWineVersion.self, from: data)
            return remoteInfo.version
        } catch {
            return nil
        }
    }

    static func sha256(of fileURL: URL) throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? fileHandle.close()
        }

        var hasher = SHA256()

        while true {
            let chunk = try fileHandle.read(upToCount: 1_048_576) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func validateSignature(for manifest: WhiskyWineRuntimeManifest, signature: String) throws -> Bool {
        guard let publicKeyData = Data(base64Encoded: manifestSigningPublicKey),
              let signatureData = Data(base64Encoded: signature) else {
            return false
        }

        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        let signedData = try canonicalManifestPayload(for: manifest)

        return publicKey.isValidSignature(signatureData, for: signedData)
    }

    static func canonicalManifestPayload(for manifest: WhiskyWineRuntimeManifest) throws -> Data {
        let object: [String: String] = [
            "archiveSHA256": manifest.archiveSHA256,
            "archiveURL": manifest.archiveURL.absoluteString,
            "d3dMetalVersion": manifest.d3dMetalVersion,
            "dxvkVersion": manifest.dxvkVersion,
            "version": manifest.version,
            "wineMonoVersion": manifest.wineMonoVersion,
            "wineVersion": manifest.wineVersion,
            "winetricksVersion": manifest.winetricksVersion
        ]

        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

public struct WhiskyWineVersion: Codable {
    public var version: SemanticVersion = SemanticVersion(1, 0, 0)
    public var wineVersion: SemanticVersion?
    public var dxvkVersion: String?
    public var d3dMetalVersion: String?
    public var winetricksVersion: String?
    public var wineMonoVersion: String?
}
