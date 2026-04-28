//
//  BottleGamingMode.swift
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
import os.log
import CryptoKit

#if canImport(FoundationModels)
import FoundationModels
#endif

// swiftlint:disable file_length function_body_length line_length type_body_length

private let dispatchCacheFilename = ".vector-patch-dispatch-cache.json"
private let dispatchLocalOverridesFilename = ".vector-patch-local-overrides.json"
private let dispatchRollbackFilename = ".vector-patch-rollback.json"

public enum DispatchPatchRuleSource: String, Codable, Sendable {
    case remote
    case local
    case crossover
    case proton
    case wineGE = "wine_ge"
}

public struct DispatchPatchRule: Codable, Sendable {
    public var id: String
    public var name: String
    public var executableMatch: String
    public var steamAppID: String
    public var arguments: String
    public var environment: [String: String]
    public var enabled: Bool
    public var channel: DispatchPatchChannel
    public var signature: String
    public var changelog: String
    public var priority: Int
    public var ruleVersion: Int
    public var graphicsBackend: GraphicsBackendMode?
    public var fallbackGraphicsBackend: GraphicsBackendMode?
    public var rollbackToRuleVersion: Int?
    public var source: DispatchPatchRuleSource
    public var trustClass: GameTrustClassification
    public var riskLevel: ProtectedRuleRiskLevel
    public var protectedTitlePolicy: ProtectedTitlePolicy?
    public var officialSupportRequired: Bool
    public var allowedOverrideKeys: [String]
    public var studioApproved: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case executableMatch
        case steamAppID = "steamAppId"
        case arguments
        case environment
        case enabled
        case channel
        case signature
        case changelog
        case priority
        case ruleVersion
        case graphicsBackend
        case fallbackGraphicsBackend
        case rollbackToRuleVersion
        case source
        case trustClass
        case riskLevel
        case protectedTitlePolicy
        case officialSupportRequired
        case allowedOverrideKeys
        case studioApproved
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case steamAppID
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        executableMatch: String = "",
        steamAppID: String = "",
        arguments: String = "",
        environment: [String: String] = [:],
        enabled: Bool = true,
        channel: DispatchPatchChannel = .stable,
        signature: String = "",
        changelog: String = "",
        priority: Int = 100,
        ruleVersion: Int = 1,
        graphicsBackend: GraphicsBackendMode? = nil,
        fallbackGraphicsBackend: GraphicsBackendMode? = nil,
        rollbackToRuleVersion: Int? = nil,
        source: DispatchPatchRuleSource = .remote,
        trustClass: GameTrustClassification = .singlePlayer,
        riskLevel: ProtectedRuleRiskLevel = .low,
        protectedTitlePolicy: ProtectedTitlePolicy? = nil,
        officialSupportRequired: Bool = false,
        allowedOverrideKeys: [String] = [],
        studioApproved: Bool = false
    ) {
        self.id = id
        self.name = name
        self.executableMatch = executableMatch
        self.steamAppID = steamAppID
        self.arguments = arguments
        self.environment = environment
        self.enabled = enabled
        self.channel = channel
        self.signature = signature
        self.changelog = changelog
        self.priority = priority
        self.ruleVersion = max(1, ruleVersion)
        self.graphicsBackend = graphicsBackend
        self.fallbackGraphicsBackend = fallbackGraphicsBackend
        self.rollbackToRuleVersion = rollbackToRuleVersion
        self.source = source
        self.trustClass = trustClass
        self.riskLevel = riskLevel
        self.protectedTitlePolicy = protectedTitlePolicy
        self.officialSupportRequired = officialSupportRequired
        self.allowedOverrideKeys = allowedOverrideKeys
        self.studioApproved = studioApproved
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Dispatch Rule"
        self.executableMatch = try container.decodeIfPresent(String.self, forKey: .executableMatch) ?? ""
        self.steamAppID = try container.decodeIfPresent(String.self, forKey: .steamAppID)
            ?? legacyContainer.decodeIfPresent(String.self, forKey: .steamAppID)
            ?? ""
        self.arguments = try container.decodeIfPresent(String.self, forKey: .arguments) ?? ""
        self.environment = try container.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.channel = try container.decodeIfPresent(DispatchPatchChannel.self, forKey: .channel) ?? .stable
        self.signature = try container.decodeIfPresent(String.self, forKey: .signature) ?? ""
        self.changelog = try container.decodeIfPresent(String.self, forKey: .changelog) ?? ""
        self.priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 100
        self.ruleVersion = max(1, try container.decodeIfPresent(Int.self, forKey: .ruleVersion) ?? 1)
        let graphicsBackendRaw = try container.decodeIfPresent(String.self, forKey: .graphicsBackend)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.graphicsBackend = GraphicsBackendMode(rawValue: graphicsBackendRaw)
        let fallbackGraphicsBackendRaw = try container.decodeIfPresent(String.self, forKey: .fallbackGraphicsBackend)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.fallbackGraphicsBackend = GraphicsBackendMode(rawValue: fallbackGraphicsBackendRaw)
        self.rollbackToRuleVersion = try container.decodeIfPresent(Int.self, forKey: .rollbackToRuleVersion)
        let sourceRaw = try container.decodeIfPresent(String.self, forKey: .source)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.source = DispatchPatchRuleSource(rawValue: sourceRaw) ?? .remote
        self.trustClass = try container.decodeIfPresent(GameTrustClassification.self, forKey: .trustClass)
            ?? .singlePlayer
        self.riskLevel = try container.decodeIfPresent(ProtectedRuleRiskLevel.self, forKey: .riskLevel)
            ?? .low
        self.protectedTitlePolicy = try container.decodeIfPresent(
            ProtectedTitlePolicy.self,
            forKey: .protectedTitlePolicy
        )
        self.officialSupportRequired = try container.decodeIfPresent(Bool.self, forKey: .officialSupportRequired)
            ?? false
        self.allowedOverrideKeys = try container.decodeIfPresent([String].self, forKey: .allowedOverrideKeys)
            ?? []
        self.studioApproved = try container.decodeIfPresent(Bool.self, forKey: .studioApproved) ?? false
    }

    public var mergeIdentity: String {
        let executable = executableMatch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let appID = steamAppID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !executable.isEmpty {
            return "exe:\(executable)"
        }
        if !appID.isEmpty {
            return "steam:\(appID)"
        }
        return "name:\(normalizedName)"
    }
}

private struct DispatchPatchRuleSigningPayload: Encodable {
    let id: String
    let name: String
    let executableMatch: String
    let steamAppID: String
    let arguments: String
    let environment: [String: String]
    let enabled: Bool
    let channel: DispatchPatchChannel
    let changelog: String
    let priority: Int
    let ruleVersion: Int
    let graphicsBackend: String
    let fallbackGraphicsBackend: String
    let rollbackToRuleVersion: Int?
    let trustClass: GameTrustClassification
    let riskLevel: ProtectedRuleRiskLevel
    let protectedTitlePolicy: ProtectedTitlePolicy?
    let officialSupportRequired: Bool
    let allowedOverrideKeys: [String]
    let studioApproved: Bool

    init(rule: DispatchPatchRule) {
        self.id = rule.id
        self.name = rule.name
        self.executableMatch = rule.executableMatch
        self.steamAppID = rule.steamAppID
        self.arguments = rule.arguments
        self.environment = rule.environment
        self.enabled = rule.enabled
        self.channel = rule.channel
        self.changelog = rule.changelog
        self.priority = rule.priority
        self.ruleVersion = rule.ruleVersion
        self.graphicsBackend = rule.graphicsBackend?.rawValue ?? ""
        self.fallbackGraphicsBackend = rule.fallbackGraphicsBackend?.rawValue ?? ""
        self.rollbackToRuleVersion = rule.rollbackToRuleVersion
        self.trustClass = rule.trustClass
        self.riskLevel = rule.riskLevel
        self.protectedTitlePolicy = rule.protectedTitlePolicy
        self.officialSupportRequired = rule.officialSupportRequired
        self.allowedOverrideKeys = rule.allowedOverrideKeys.sorted()
        self.studioApproved = rule.studioApproved
    }
}

public enum DispatchPatchSignatureVerifier {
    private static let signaturePrefix = "ed25519:"
    private static let publicKeyDefaultsKey = "VecPatchPublicKeyBase64"
    private static let bundledPublicKeyBase64 = "akVW5axA3RB6/CBYI/O5AtK/aRa4GuJEp1xcRYavenA="

    public static func isRuleSignatureValid(_ rule: DispatchPatchRule) -> Bool {
        let trimmedSignature = rule.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSignature.hasPrefix(signaturePrefix),
              let signatureData = Data(base64Encoded: String(trimmedSignature.dropFirst(signaturePrefix.count))),
              let publicKeyData = activePublicKeyData(),
              let signedData = canonicalPayloadData(for: rule) else {
            return false
        }

        do {
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
            return publicKey.isValidSignature(signatureData, for: signedData)
        } catch {
            return false
        }
    }

    public static func canonicalPayloadData(for rule: DispatchPatchRule) -> Data? {
        let object: [String: Any] = [
            "allowed_override_keys": rule.allowedOverrideKeys.sorted(),
            "arguments": rule.arguments,
            "channel": rule.channel.rawValue,
            "changelog": rule.changelog,
            "enabled": rule.enabled,
            "environment": rule.environment,
            "executable_match": rule.executableMatch,
            "fallback_graphics_backend": rule.fallbackGraphicsBackend?.rawValue ?? "",
            "graphics_backend": rule.graphicsBackend?.rawValue ?? "",
            "id": rule.id,
            "name": rule.name,
            "official_support_required": rule.officialSupportRequired,
            "priority": rule.priority,
            "protected_title_policy": protectedTitlePolicyObject(rule.protectedTitlePolicy) ?? NSNull(),
            "risk_level": rule.riskLevel.rawValue,
            "rollback_to_rule_version": rule.rollbackToRuleVersion.map { $0 as Any } ?? NSNull(),
            "rule_version": rule.ruleVersion,
            "steam_app_id": rule.steamAppID,
            "studio_approved": rule.studioApproved,
            "trust_class": rule.trustClass.rawValue
        ]
        return try? JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    private static func activePublicKeyData() -> Data? {
        let environment = ProcessInfo.processInfo.environment
        let candidates = [
            environment["VECPATCH_PUBLIC_KEY_BASE64"],
            environment["VECPATCH_PUBLIC_KEY"],
            UserDefaults.standard.string(forKey: publicKeyDefaultsKey),
            bundledPublicKeyBase64
        ]

        for candidate in candidates {
            guard let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty,
                  let data = Data(base64Encoded: value) else {
                continue
            }
            return data
        }
        return nil
    }

    private static func protectedTitlePolicyObject(_ policy: ProtectedTitlePolicy?) -> Any? {
        guard let policy else { return nil }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(policy),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return object
    }
}

public struct DispatchPatchEnvelope: Codable, Sendable {
    public var version: Int
    public var generatedAt: String
    public var changelog: String
    public var rules: [DispatchPatchRule]

    public init(
        version: Int = 1,
        generatedAt: String = "",
        changelog: String = "",
        rules: [DispatchPatchRule]
    ) {
        self.version = version
        self.generatedAt = generatedAt
        self.changelog = changelog
        self.rules = rules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt) ?? ""
        self.changelog = try container.decodeIfPresent(String.self, forKey: .changelog) ?? ""
        self.rules = try container.decodeIfPresent([DispatchPatchRule].self, forKey: .rules) ?? []
    }
}

public struct DispatchDoctorSignal: Codable, Sendable {
    public var id: String
    public var title: String
    public var summary: String
    public var steamAppID: String
    public var executableMatch: String
    public var matchFragments: [String]
    public var fixIDs: [String]
    public var trustClass: GameTrustClassification
    public var riskLevel: ProtectedRuleRiskLevel
    public var updatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case steamAppID = "steamAppId"
        case executableMatch
        case matchFragments
        case fixIDs = "fixIds"
        case trustClass
        case riskLevel
        case updatedAt
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case steamAppID
        case fixIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Doctor Signal"
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.steamAppID = try container.decodeIfPresent(String.self, forKey: .steamAppID)
            ?? legacyContainer.decodeIfPresent(String.self, forKey: .steamAppID)
            ?? ""
        self.executableMatch = try container.decodeIfPresent(String.self, forKey: .executableMatch) ?? ""
        self.matchFragments = try container.decodeIfPresent([String].self, forKey: .matchFragments) ?? []
        self.fixIDs = try container.decodeIfPresent([String].self, forKey: .fixIDs)
            ?? legacyContainer.decodeIfPresent([String].self, forKey: .fixIDs)
            ?? []
        self.trustClass = try container.decodeIfPresent(GameTrustClassification.self, forKey: .trustClass)
            ?? .singlePlayer
        self.riskLevel = try container.decodeIfPresent(ProtectedRuleRiskLevel.self, forKey: .riskLevel)
            ?? .low
        self.updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}

public struct DispatchDoctorSignalsEnvelope: Codable, Sendable {
    public var version: Int
    public var generatedAt: String
    public var signals: [DispatchDoctorSignal]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt) ?? ""
        self.signals = try container.decodeIfPresent([DispatchDoctorSignal].self, forKey: .signals) ?? []
    }
}

public struct DispatchPatchLocalOverridesDocument: Codable, Sendable {
    public var version: Int
    public var generatedAt: String
    public var rules: [DispatchPatchRule]

    public init(
        version: Int = 1,
        generatedAt: String = "",
        rules: [DispatchPatchRule] = []
    ) {
        self.version = version
        self.generatedAt = generatedAt
        self.rules = rules
    }
}

public struct DispatchPatchStatus: Sendable {
    public var endpointURL: String
    public var channel: DispatchPatchChannel
    public var dispatchEnabled: Bool
    public var remoteVersion: Int
    public var remoteGeneratedAt: String
    public var remoteChangelog: String
    public var remoteRuleCount: Int
    public var remoteRuleVersion: Int
    public var remoteRulesDigest: String
    public var effectiveRuleCount: Int
    public var effectiveRulesDigest: String
    public var recommendedBackend: GraphicsBackendMode?
    public var fallbackBackend: GraphicsBackendMode?
    public var lastFetchedAt: Date?
    public var lastAppliedVersion: Int
    public var lastAppliedGeneratedAt: String
    public var lastAppliedRulesDigest: String
    public var lastAppliedAt: Date?
    public var updateAvailable: Bool
    public var alreadyApplied: Bool {
        let effectiveDigest = effectiveRulesDigest.trimmingCharacters(in: .whitespacesAndNewlines)
        let appliedDigest = lastAppliedRulesDigest.trimmingCharacters(in: .whitespacesAndNewlines)
        return dispatchEnabled
            && !updateAvailable
            && effectiveRuleCount > 0
            && !effectiveDigest.isEmpty
            && effectiveDigest == appliedDigest
    }

    public init(
        endpointURL: String,
        channel: DispatchPatchChannel,
        dispatchEnabled: Bool,
        remoteVersion: Int = 0,
        remoteGeneratedAt: String = "",
        remoteChangelog: String = "",
        remoteRuleCount: Int = 0,
        remoteRuleVersion: Int = 0,
        remoteRulesDigest: String = "",
        effectiveRuleCount: Int = 0,
        effectiveRulesDigest: String = "",
        recommendedBackend: GraphicsBackendMode? = nil,
        fallbackBackend: GraphicsBackendMode? = nil,
        lastFetchedAt: Date? = nil,
        lastAppliedVersion: Int = 0,
        lastAppliedGeneratedAt: String = "",
        lastAppliedRulesDigest: String = "",
        lastAppliedAt: Date? = nil,
        updateAvailable: Bool = false
    ) {
        self.endpointURL = endpointURL
        self.channel = channel
        self.dispatchEnabled = dispatchEnabled
        self.remoteVersion = remoteVersion
        self.remoteGeneratedAt = remoteGeneratedAt
        self.remoteChangelog = remoteChangelog
        self.remoteRuleCount = remoteRuleCount
        self.remoteRuleVersion = remoteRuleVersion
        self.remoteRulesDigest = remoteRulesDigest
        self.effectiveRuleCount = effectiveRuleCount
        self.effectiveRulesDigest = effectiveRulesDigest
        self.recommendedBackend = recommendedBackend
        self.fallbackBackend = fallbackBackend
        self.lastFetchedAt = lastFetchedAt
        self.lastAppliedVersion = lastAppliedVersion
        self.lastAppliedGeneratedAt = lastAppliedGeneratedAt
        self.lastAppliedRulesDigest = lastAppliedRulesDigest
        self.lastAppliedAt = lastAppliedAt
        self.updateAvailable = updateAvailable
    }
}

private struct DispatchPatchCacheEnvelope: Codable, Sendable {
    var fetchedAt: Date
    var version: Int
    var generatedAt: String
    var changelog: String
    var rules: [DispatchPatchRule]

    init(
        fetchedAt: Date,
        version: Int = 1,
        generatedAt: String = "",
        changelog: String = "",
        rules: [DispatchPatchRule]
    ) {
        self.fetchedAt = fetchedAt
        self.version = version
        self.generatedAt = generatedAt
        self.changelog = changelog
        self.rules = rules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fetchedAt = try container.decodeIfPresent(Date.self, forKey: .fetchedAt) ?? .distantPast
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt) ?? ""
        self.changelog = try container.decodeIfPresent(String.self, forKey: .changelog) ?? ""
        self.rules = try container.decodeIfPresent([DispatchPatchRule].self, forKey: .rules) ?? []
    }
}

private struct DispatchPatchLocalOverrideEnvelope: Codable, Sendable {
    var version: Int
    var generatedAt: String
    var rules: [DispatchPatchRule]

    init(version: Int = 1, generatedAt: String = "", rules: [DispatchPatchRule] = []) {
        self.version = version
        self.generatedAt = generatedAt
        self.rules = rules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt) ?? ""
        self.rules = try container.decodeIfPresent([DispatchPatchRule].self, forKey: .rules) ?? []
    }
}

private struct DispatchPatchRollbackEnvelope: Codable, Sendable {
    var createdAt: Date
    var profiles: [BottleGameProfile]

    init(createdAt: Date = Date(), profiles: [BottleGameProfile]) {
        self.createdAt = createdAt
        self.profiles = profiles
    }
}

private struct DispatchBackendInferenceRecommendation: Sendable {
    let primary: GraphicsBackendMode
    let fallback: GraphicsBackendMode?
    let confidence: Double
    let reason: String
    let sourceRuleID: String?
}

private actor DispatchBackendInferenceService {
    static let shared = DispatchBackendInferenceService()
    private var recommendationCache: [String: DispatchBackendInferenceRecommendation] = [:]

    func recommendBackend(
        for bottle: Bottle,
        rules: [DispatchPatchRule],
        fallback: (primary: GraphicsBackendMode, fallback: GraphicsBackendMode?)?
    ) async -> DispatchBackendInferenceRecommendation? {
        let candidates = rules
            .filter { $0.enabled && $0.graphicsBackend != nil }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }
                if lhs.ruleVersion != rhs.ruleVersion {
                    return lhs.ruleVersion > rhs.ruleVersion
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        if candidates.isEmpty {
            guard let fallback else { return nil }
            return DispatchBackendInferenceRecommendation(
                primary: fallback.primary,
                fallback: fallback.fallback,
                confidence: 0.6,
                reason: "No dispatch candidate carried an explicit backend. Using deterministic fallback recommendation.",
                sourceRuleID: nil
            )
        }

        let cacheKey = makeCacheKey(for: bottle, rules: candidates)
        if let cached = recommendationCache[cacheKey] {
            return cached
        }

        var recommendation = fallback.map {
            DispatchBackendInferenceRecommendation(
                primary: $0.primary,
                fallback: $0.fallback,
                confidence: 0.68,
                reason: "Deterministic recommendation from patch rules.",
                sourceRuleID: nil
            )
        } ?? DispatchBackendInferenceRecommendation(
            primary: candidates[0].graphicsBackend ?? .dxvk,
            fallback: candidates[0].fallbackGraphicsBackend,
            confidence: 0.55,
            reason: "Defaulting to the highest-priority patch backend recommendation.",
            sourceRuleID: candidates[0].id
        )

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if let modeledRecommendation = await modelRecommendation(
                for: bottle,
                candidates: candidates
            ) {
                recommendation = modeledRecommendation
            }
        }
        #endif

        recommendationCache[cacheKey] = recommendation
        return recommendation
    }

    private func makeCacheKey(for bottle: Bottle, rules: [DispatchPatchRule]) -> String {
        let activeAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = rules
            .map { rule in
                let backend = rule.graphicsBackend?.rawValue ?? ""
                let fallback = rule.fallbackGraphicsBackend?.rawValue ?? ""
                return "\(rule.id)|\(rule.ruleVersion)|\(rule.priority)|\(backend)|\(fallback)|\(rule.mergeIdentity)"
            }
            .joined(separator: "\n")
        let hash = SHA256.hash(data: Data(digest.utf8))
        let hashString = hash.map { String(format: "%02x", $0) }.joined()
        return "\(bottle.url.path(percentEncoded: false))|\(activeAppID)|\(hashString)"
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func modelRecommendation(
        for bottle: Bottle,
        candidates: [DispatchPatchRule]
    ) async -> DispatchBackendInferenceRecommendation? {
        struct Response: Decodable {
            let backend: String
            let fallback: String?
            let confidence: Double?
            let reason: String?
            let sourceRuleID: String?
        }

        let activeAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateSummary = candidates.prefix(16).map { rule in
            let backend = rule.graphicsBackend?.rawValue ?? "none"
            let fallback = rule.fallbackGraphicsBackend?.rawValue ?? ""
            let appID = rule.steamAppID.isEmpty ? "-" : rule.steamAppID
            let executable = rule.executableMatch.isEmpty ? "-" : rule.executableMatch
            return "id=\(rule.id), name=\(rule.name), app=\(appID), exe=\(executable), backend=\(backend), fallback=\(fallback), priority=\(rule.priority), version=\(rule.ruleVersion)"
        }.joined(separator: "\n")

        let prompt = """
        You are selecting one graphics backend for a Wine game-launch runtime.
        Choose the safest and most compatible backend candidate from the provided patch rules.

        Runtime backends:
        - dxvk
        - dxmt
        - wined3d
        - d3dMetal

        Context:
        - active_steam_app_id: \(activeAppID.isEmpty ? "-" : activeAppID)
        - current_global_backend_mode: \(bottle.settings.graphicsBackendMode.rawValue)

        Candidate rules:
        \(candidateSummary)

        Return ONLY one JSON object:
        {"backend":"dxvk|dxmt|wined3d|d3dMetal","fallback":"dxvk|dxmt|wined3d|d3dMetal|","confidence":0.0,"reason":"short reason","source_rule_id":"rule id or empty"}
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let json = extractJSONObject(from: content),
                  let jsonData = json.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(Response.self, from: jsonData),
                  let backend = parseBackend(decoded.backend) else {
                return nil
            }

            let fallback = parseBackend(decoded.fallback ?? "")
            let confidence = max(0, min(1, decoded.confidence ?? 0.5))
            let reason = decoded.reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Model recommendation."
            let sourceRuleID = decoded.sourceRuleID?.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedSourceRuleID = sourceRuleID?.isEmpty == false ? sourceRuleID : nil

            return DispatchBackendInferenceRecommendation(
                primary: backend,
                fallback: fallback,
                confidence: confidence,
                reason: reason,
                sourceRuleID: normalizedSourceRuleID
            )
        } catch {
            return nil
        }
    }
    #endif

    private func parseBackend(_ rawValue: String) -> GraphicsBackendMode? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .lowercased()
        switch normalized {
        case "dxvk":
            return .dxvk
        case "dxmt":
            return .dxmt
        case "wined3d":
            return .wined3d
        case "d3dmetal":
            return .d3dMetal
        case "auto", "":
            return nil
        default:
            return nil
        }
    }

    private func extractJSONObject(from text: String) -> String? {
        guard let firstBrace = text.firstIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var endIndex: String.Index?
        var cursor = firstBrace
        while cursor < text.endIndex {
            let character = text[cursor]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    endIndex = cursor
                    break
                }
            }
            cursor = text.index(after: cursor)
        }

        guard let endIndex else {
            return nil
        }
        return String(text[firstBrace...endIndex])
    }
}

private enum LauncherDescriptor: String, CaseIterable {
    case steam
    case epic
    case ubisoft
    case gog

    var displayName: String {
        switch self {
        case .steam:
            return "Steam"
        case .epic:
            return "Epic Games Launcher"
        case .ubisoft:
            return "Ubisoft Connect"
        case .gog:
            return "GOG Galaxy"
        }
    }

    var installerDownloadURL: URL? {
        switch self {
        case .steam:
            return URL(string: "https://cdn.cloudflare.steamstatic.com/client/installer/SteamSetup.exe")
        case .epic:
            return URL(string: "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi")
        case .ubisoft:
            return URL(string: "https://static3.cdn.ubi.com/orbit/launcher_installer/UbisoftConnectInstaller.exe")
        case .gog:
            return URL(string: "https://webinstallers.gog-statics.com/download/GOG_Galaxy_2.0.exe")
        }
    }

    var installerFilename: String {
        switch self {
        case .steam:
            return "SteamSetup.exe"
        case .epic:
            return "EpicGamesLauncherInstaller.msi"
        case .ubisoft:
            return "UbisoftConnectInstaller.exe"
        case .gog:
            return "GOGGalaxySetup.exe"
        }
    }

    var silentArguments: [String] {
        switch self {
        case .steam:
            return ["/S"]
        case .epic:
            return []
        case .ubisoft:
            return ["/S"]
        case .gog:
            return ["/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART"]
        }
    }

    var expectedExecutableCandidates: [String] {
        switch self {
        case .steam:
            return [
                "drive_c/Program Files (x86)/Steam/steam.exe",
                "drive_c/Program Files/Steam/steam.exe"
            ]
        case .epic:
            return [
                "drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe",
                "drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe",
                "drive_c/Program Files/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
            ]
        case .ubisoft:
            return [
                "drive_c/Program Files (x86)/Ubisoft/Ubisoft Game Launcher/UbisoftConnect.exe",
                "drive_c/Program Files/Ubisoft/Ubisoft Game Launcher/UbisoftConnect.exe"
            ]
        case .gog:
            return [
                "drive_c/Program Files (x86)/GOG Galaxy/GalaxyClient.exe",
                "drive_c/Program Files/GOG Galaxy/GalaxyClient.exe"
            ]
        }
    }
}

public enum BottleGamingModeManager {
    public static let dispatchProfileNamePrefix = "Dispatch:"

    public static func applyGamingDefaults(
        to bottle: Bottle,
        dispatchEndpointURL: String? = nil
    ) {
        bottle.settings.gamingModeEnabled = true
        bottle.settings.graphicsBackendMode = .dxvk
        bottle.settings.dxvk = true
        bottle.settings.dxvkAsync = true
        bottle.settings.shaderCacheEnabled = true
        bottle.settings.steamDisableOverlay = true
        bottle.settings.trainerSupportMode = true

        if let dispatchEndpointURL {
            let normalized = dispatchEndpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                bottle.settings.patchDispatchEndpointURL = normalized
            }
        }
    }

    public static func installGamingLaunchersIfEnabled(for bottle: Bottle) async {
        guard bottle.settings.gamingModeEnabled else {
            return
        }
        guard bottle.settings.gamingAutoInstallLaunchers else {
            if bottle.settings.gamingAutoPinLaunchers {
                pinKnownLaunchers(for: bottle)
            }
            return
        }

        let launchersRoot = bottle.url
            .appending(path: "drive_c")
            .appending(path: "Vector")
            .appending(path: "Launchers")
        do {
            try FileManager.default.createDirectory(at: launchersRoot, withIntermediateDirectories: true)
        } catch {
            Logger.wineKit.warning(
                "Failed to create launcher bootstrap directory at \(launchersRoot.path(percentEncoded: false), privacy: .public)"
            )
            return
        }

        for descriptor in LauncherDescriptor.allCases {
            guard let downloadURL = descriptor.installerDownloadURL else {
                continue
            }
            let installerURL = launchersRoot.appending(path: descriptor.installerFilename)

            do {
                try await downloadFile(from: downloadURL, to: installerURL)
                try await runInstallerIfPossible(installerURL: installerURL, descriptor: descriptor, bottle: bottle)
                if bottle.settings.gamingAutoPinLaunchers {
                    pinProgramIfNeeded(
                        at: installerURL,
                        in: bottle,
                        name: "\(descriptor.displayName) Installer"
                    )
                }
            } catch {
                Logger.wineKit.warning(
                    "Failed to bootstrap launcher \(descriptor.displayName, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        if bottle.settings.gamingAutoPinLaunchers {
            pinKnownLaunchers(for: bottle)
        }
    }

    public static func prepareProfilesForLaunch(for bottle: Bottle) async {
        let launchState = await MainActor.run {
            (
                gamingModeEnabled: bottle.settings.gamingModeEnabled,
                autoApplyKnownProfiles: bottle.settings.gamingAutoApplyKnownGamePatches,
                patchDispatchEnabled: bottle.settings.patchDispatchEnabled,
                dispatchProfileCount: bottle.settings.gameProfiles.filter {
                    $0.name.hasPrefix(dispatchProfileNamePrefix)
                }.count,
                appliedRulesDigest: bottle.settings.patchDispatchLastAppliedRulesDigest
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        guard launchState.gamingModeEnabled else {
            return
        }

        if launchState.autoApplyKnownProfiles {
            await MainActor.run {
                ensureKnownGameProfiles(in: bottle)
            }
        }

        guard launchState.patchDispatchEnabled else {
            return
        }

        let rules = await DispatchPatchService.shared.rules(for: bottle, forceRefresh: false)
        let status = await DispatchPatchService.shared.status(for: bottle, checkRemote: false)
        let effectiveRulesDigest = status.effectiveRulesDigest.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldApplyDispatchChanges = launchState.dispatchProfileCount == 0
            || effectiveRulesDigest != launchState.appliedRulesDigest
            || (rules.isEmpty && launchState.dispatchProfileCount > 0)

        if shouldApplyDispatchChanges {
            await MainActor.run {
                mergeDispatchRules(rules, into: bottle)
                bottle.settings.patchDispatchLastAppliedVersion = status.remoteVersion
                bottle.settings.patchDispatchLastAppliedGeneratedAt = status.remoteGeneratedAt
                bottle.settings.patchDispatchLastAppliedRulesDigest = status.effectiveRulesDigest
                bottle.settings.patchDispatchLastAppliedAt = Date()
            }
        }
        await updateInferredBackend(using: rules, for: bottle)
    }

    public static func ensureKnownGameProfiles(in bottle: Bottle) {
        var profiles = bottle.settings.gameProfiles

        let knownProfiles: [BottleGameProfile] = [
            BottleGameProfile(
                name: "Auto: High On Life 2",
                executableMatch: "highonlife2-win64-shipping.exe",
                steamAppID: "2069250",
                arguments: "-dx12 -ngxdisable",
                environment: [
                    "WINEDLLOVERRIDES":
                        "dxgi,d3d11,d3d10core,d3d9,d3d12,d3d12core=b;nvapi,nvapi64=d;amd_fidelityfx_upscaler_dx12,amd_fidelityfx_framegeneration_dx12=n,b;nvngx,_nvngx,nvngx_dlss,nvngx_dlssd,nvngx_dlssg,sl.interposer,sl.common,sl.dlss,sl.dlss_g,sl.deepdvc,sl.reflex,sl.pcl=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            ),
            BottleGameProfile(
                name: "Auto: Parcel Simulator",
                executableMatch: "parcel-win64-shipping.exe",
                steamAppID: "2424010",
                arguments: "-force-d3d11 -dx11 -d3d11",
                environment: [
                    "WINEDLLOVERRIDES": "dxgi,d3d11,d3d10core,d3d9=b;nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            ),
            BottleGameProfile(
                name: "Auto: Minecraft Dungeons",
                executableMatch: "dungeons-win64-shipping.exe",
                steamAppID: "1672970",
                arguments:
                    "-force-d3d11 -dx11 -d3d11 -cef-disable-gpu -cef-disable-gpu-compositing "
                    + "-cef-disable-accelerated-video-decode -cef-disable-low-latency-dxva "
                    + "-cef-disable-zero-copy-dxgi-video -nosound",
                environment: [
                    "WINEDLLOVERRIDES": "dxgi,d3d11,d3d10core,d3d9=n,b;nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0",
                    "VECTOR_PROTON_STYLE_COMPAT": "1",
                    "VECTOR_PROTON_MEDIA_SHIMS": "1",
                    "VECTOR_MEDIA_FOUNDATION_MODE": "proton-style"
                ]
            ),
            BottleGameProfile(
                name: "Auto: Minecraft Dungeons Launcher",
                executableMatch: "dungeons.exe",
                steamAppID: "1672970",
                arguments:
                    "-force-d3d11 -dx11 -d3d11 -cef-disable-gpu -cef-disable-gpu-compositing "
                    + "-cef-disable-accelerated-video-decode -cef-disable-low-latency-dxva "
                    + "-cef-disable-zero-copy-dxgi-video -nosound",
                environment: [
                    "WINEDLLOVERRIDES": "dxgi,d3d11,d3d10core,d3d9=n,b;nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0",
                    "VECTOR_PROTON_STYLE_COMPAT": "1",
                    "VECTOR_PROTON_MEDIA_SHIMS": "1",
                    "VECTOR_MEDIA_FOUNDATION_MODE": "proton-style"
                ]
            ),
            BottleGameProfile(
                name: "Auto: Content Warning",
                executableMatch: "content warning.exe",
                steamAppID: "2881650",
                arguments: "-force-d3d11 -dx11 -d3d11",
                environment: [
                    "WINEDLLOVERRIDES": "dxgi,d3d11,d3d10core,d3d9=n,b;nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            ),
            BottleGameProfile(
                name: "Auto: Lethal Company",
                executableMatch: "lethal company.exe",
                steamAppID: "1966720",
                arguments: "",
                environment: [
                    "WINEDLLOVERRIDES": "nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            ),
            BottleGameProfile(
                name: "Auto: Hydroneer",
                executableMatch: "hydroneer-win64-shipping.exe",
                steamAppID: "1106840",
                arguments: "",
                environment: [
                    "WINEDLLOVERRIDES": "nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            ),
            BottleGameProfile(
                name: "Auto: Satisfactory",
                executableMatch: "factorygamesteam.exe",
                steamAppID: "526870",
                arguments: "-dx11",
                environment: [
                    "WINEDLLOVERRIDES": "dxgi,d3d11,d3d10core=n,b;nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            ),
            BottleGameProfile(
                name: "Auto: Escape the Backrooms",
                executableMatch: "escapethebackrooms.exe",
                steamAppID: "1943950",
                arguments: "-dx11 -d3d11",
                environment: [
                    "WINEDLLOVERRIDES": "dxgi,d3d11,d3d10core=n,b;nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            ),
            BottleGameProfile(
                name: "Auto: Titanfall 2",
                executableMatch: "titanfall2.exe",
                steamAppID: "1237970",
                arguments: "",
                environment: [
                    "WINEDLLOVERRIDES": "dxgi,d3d11,d3d10core,d3d9=n,b;nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            ),
            BottleGameProfile(
                name: "Auto: Origin",
                executableMatch: "origin.exe",
                arguments: "",
                environment: [
                    "WINEDLLOVERRIDES": "version=n,b;nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            ),
            BottleGameProfile(
                name: "Auto: EA App",
                executableMatch: "eadesktop.exe",
                arguments: "",
                environment: [
                    "WINEDLLOVERRIDES": "version=n,b;nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            ),
            BottleGameProfile(
                name: "Auto: Silent Hill f",
                executableMatch: "silenthillf-win64-shipping.exe",
                steamAppID: "2947440",
                arguments: "-force-d3d11 -dx11 -d3d11",
                environment: [
                    "WINEDLLOVERRIDES": "dxgi,d3d9,d3d10core,d3d11=n,b;nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            ),
            BottleGameProfile(
                name: "Auto: Forza Horizon 6",
                executableMatch: "forzahorizon6.exe",
                steamAppID: "2483190",
                arguments: "-dx12 -d3d12",
                environment: [
                    "WINEDLLOVERRIDES": "dxgi,d3d11,d3d10core,d3d9=b;d3d12,d3d12core=n,b;nvapi,nvapi64=d",
                    "VECTOR_FORCE_DISABLE_DXVK": "1",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0",
                    "ROSETTA_ADVERTISE_AVX": "1"
                ],
                graphicsBackendOverride: .d3dMetal,
                fallbackGraphicsBackend: .dxvk
            ),
            BottleGameProfile(
                name: "Auto: WeMod / Wand",
                executableMatch: "wemod.exe",
                arguments: "--disable-gpu --disable-gpu-compositing --disable-features=RendererCodeIntegrity,CalculateNativeWinOcclusion --no-sandbox",
                environment: [
                    "WINE_DISABLE_WRITE_WATCH": "1",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1"
                ]
            ),
            BottleGameProfile(
                name: "Auto: Wand Runtime",
                executableMatch: "wand",
                arguments: "--disable-gpu --disable-gpu-compositing --disable-features=RendererCodeIntegrity,CalculateNativeWinOcclusion --no-sandbox",
                environment: [
                    "WINE_DISABLE_WRITE_WATCH": "1",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1"
                ]
            )
        ]

        for profile in knownProfiles {
            upsertProfile(profile, in: &profiles)
        }

        bottle.settings.gameProfiles = profiles
    }

    public static func mergeDispatchRules(_ rules: [DispatchPatchRule], into bottle: Bottle) {
        let protectedFilteredRules = rules.filter {
            VectorProtectedTitlePolicyEngine.ruleAllowed($0, in: bottle)
        }
        let selectedRules = selectRuleWinners(from: protectedFilteredRules)
        let shouldAttachBackendOverrides = bottle.settings.graphicsBackendMode == .auto
        let newDispatchProfiles = selectedRules.map { rule in
            BottleGameProfile(
                name: "\(dispatchProfileNamePrefix) \(rule.name)",
                executableMatch: rule.executableMatch,
                steamAppID: rule.steamAppID,
                arguments: rule.arguments,
                environment: rule.environment,
                graphicsBackendOverride: shouldAttachBackendOverrides ? rule.graphicsBackend : nil,
                fallbackGraphicsBackend: shouldAttachBackendOverrides ? rule.fallbackGraphicsBackend : nil,
                dispatchPriority: rule.priority,
                dispatchRuleVersion: rule.ruleVersion,
                dispatchRuleID: rule.id,
                dispatchChannel: rule.channel,
                dispatchSource: rule.source.rawValue
            )
        }

        var profiles = bottle.settings.gameProfiles
        let existingDispatch = profiles.filter { $0.name.hasPrefix(dispatchProfileNamePrefix) }
        let nonDispatchProfiles = profiles.filter { !$0.name.hasPrefix(dispatchProfileNamePrefix) }
        var existingByKey: [String: BottleGameProfile] = [:]
        for profile in existingDispatch {
            existingByKey[profileMergeKey(profile)] = profile
        }

        var mergedDispatch: [BottleGameProfile] = []
        for var profile in newDispatchProfiles {
            let key = profileMergeKey(profile)
            if let existing = existingByKey[key] {
                profile.id = existing.id
            }
            mergedDispatch.append(profile)
        }

        profiles = nonDispatchProfiles + mergedDispatch
        bottle.settings.gameProfiles = profiles

        // Keep dispatch patch application idempotent and non-destructive:
        // patch sync updates game profiles, but does not overwrite user-selected
        // global graphics backend mode.
    }

    public static func syncDispatchProfiles(for bottle: Bottle, forceRefresh: Bool) async {
        guard bottle.settings.patchDispatchEnabled else {
            return
        }

        VectorNotifications.notifyMaintenanceStarted(
            task: "Patch sync",
            bottleName: bottle.settings.name
        )
        let currentDispatchProfileCount = bottle.settings.gameProfiles.filter {
            $0.name.hasPrefix(dispatchProfileNamePrefix)
        }.count
        let rules = await DispatchPatchService.shared.rules(for: bottle, forceRefresh: forceRefresh)
        let status = await DispatchPatchService.shared.status(for: bottle, checkRemote: false)
        let effectiveRulesDigest = status.effectiveRulesDigest.trimmingCharacters(in: .whitespacesAndNewlines)
        let appliedRulesDigest = bottle.settings.patchDispatchLastAppliedRulesDigest
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldApplyDispatchChanges = currentDispatchProfileCount == 0
            || effectiveRulesDigest != appliedRulesDigest
            || (rules.isEmpty && currentDispatchProfileCount > 0)

        if shouldApplyDispatchChanges {
            saveRollbackSnapshot(for: bottle)
            mergeDispatchRules(rules, into: bottle)
        }
        await updateInferredBackend(using: rules, for: bottle)

        guard shouldApplyDispatchChanges else {
            await DispatchPatchService.shared.reportPatchSyncTelemetry(
                for: bottle,
                updatedRuleCount: currentDispatchProfileCount,
                success: true,
                details: "no-op_sync=true;reason=already_applied"
            )
            VectorNotifications.notifyPatchSyncCompleted(bottle.settings.name)
            return
        }

        bottle.settings.patchDispatchLastAppliedVersion = status.remoteVersion
        bottle.settings.patchDispatchLastAppliedGeneratedAt = status.remoteGeneratedAt
        bottle.settings.patchDispatchLastAppliedRulesDigest = status.effectiveRulesDigest
        bottle.settings.patchDispatchLastAppliedAt = Date()
        let mergedDispatchProfileCount = bottle.settings.gameProfiles.filter {
            $0.name.hasPrefix(dispatchProfileNamePrefix)
        }.count
        await DispatchPatchService.shared.reportPatchSyncTelemetry(
            for: bottle,
            updatedRuleCount: mergedDispatchProfileCount,
            success: true,
            details: "prev_dispatch_profiles=\(currentDispatchProfileCount)"
        )
        VectorNotifications.notifyPatchSyncCompleted(bottle.settings.name)
    }

    @discardableResult
    public static func rollbackLastDispatchProfiles(for bottle: Bottle) -> Bool {
        guard let snapshot = loadRollbackSnapshot(for: bottle) else {
            return false
        }

        let nonDispatchProfiles = bottle.settings.gameProfiles.filter {
            !$0.name.hasPrefix(dispatchProfileNamePrefix)
        }
        bottle.settings.gameProfiles = nonDispatchProfiles + snapshot.profiles
        return true
    }

    public static func pinKnownLaunchers(for bottle: Bottle) {
        for launcher in LauncherDescriptor.allCases {
            for relativePath in launcher.expectedExecutableCandidates {
                let candidateURL = bottle.url.appending(path: relativePath)
                guard FileManager.default.fileExists(atPath: candidateURL.path(percentEncoded: false)) else {
                    continue
                }
                pinProgramIfNeeded(at: candidateURL, in: bottle, name: launcher.displayName)
                break
            }
        }
    }

    private static func upsertProfile(_ profile: BottleGameProfile, in profiles: inout [BottleGameProfile]) {
        if let index = profiles.firstIndex(where: { existing in
            let sameName = existing.name.caseInsensitiveCompare(profile.name) == .orderedSame
            let sameExecutable = !profile.executableMatch.isEmpty
                && existing.executableMatch.caseInsensitiveCompare(profile.executableMatch) == .orderedSame
            let sameAppID = !profile.steamAppID.isEmpty && existing.steamAppID == profile.steamAppID
            return sameName || (sameExecutable && sameAppID)
        }) {
            var updated = profile
            updated.id = profiles[index].id
            profiles[index] = updated
        } else {
            profiles.append(profile)
        }
    }

    private static func profileMergeKey(_ profile: BottleGameProfile) -> String {
        let name = profile.name.lowercased()
        let executable = profile.executableMatch.lowercased()
        let appID = profile.steamAppID.lowercased()
        return "\(name)|\(executable)|\(appID)"
    }

    private static func rollbackSnapshotURL(for bottle: Bottle) -> URL {
        bottle.url.appending(path: dispatchRollbackFilename)
    }

    private static func saveRollbackSnapshot(for bottle: Bottle) {
        let dispatchProfiles = bottle.settings.gameProfiles.filter {
            $0.name.hasPrefix(dispatchProfileNamePrefix)
        }
        guard !dispatchProfiles.isEmpty else {
            return
        }

        let snapshot = DispatchPatchRollbackEnvelope(profiles: dispatchProfiles)
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: rollbackSnapshotURL(for: bottle), options: .atomic)
        } catch {
            Logger.wineKit.warning(
                "Failed to persist rollback snapshot for \(bottle.settings.name, privacy: .public)"
            )
        }
    }

    private static func loadRollbackSnapshot(for bottle: Bottle) -> DispatchPatchRollbackEnvelope? {
        let url = rollbackSnapshotURL(for: bottle)
        let path = url.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(DispatchPatchRollbackEnvelope.self, from: data)
    }

    static func selectRuleWinners(from rules: [DispatchPatchRule]) -> [DispatchPatchRule] {
        var grouped: [String: [DispatchPatchRule]] = [:]
        for rule in rules where rule.enabled {
            grouped[rule.mergeIdentity, default: []].append(rule)
        }

        var winners: [DispatchPatchRule] = []
        for key in grouped.keys.sorted() {
            guard var ranked = grouped[key] else { continue }
            ranked.sort(by: shouldPreferRule(_:over:))

            guard var winner = ranked.first else { continue }
            if winner.fallbackGraphicsBackend == nil {
                winner.fallbackGraphicsBackend = ranked.dropFirst().compactMap(\.graphicsBackend).first
            }
            winners.append(winner)
        }

        winners.sort(by: shouldPreferRule(_:over:))
        return winners
    }

    private static func sourcePrecedence(_ source: DispatchPatchRuleSource) -> Int {
        switch source {
        case .local:
            return 0
        case .remote:
            return 1
        case .crossover:
            return 2
        case .proton, .wineGE:
            return 2
        }
    }

    private static func shouldPreferRule(_ lhs: DispatchPatchRule, over rhs: DispatchPatchRule) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }
        if lhs.ruleVersion != rhs.ruleVersion {
            return lhs.ruleVersion > rhs.ruleVersion
        }
        if sourcePrecedence(lhs.source) != sourcePrecedence(rhs.source) {
            return sourcePrecedence(lhs.source) < sourcePrecedence(rhs.source)
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func updateInferredBackend(using rules: [DispatchPatchRule], for bottle: Bottle) async {
        let fallbackRecommendation = await MainActor.run {
            guard bottle.settings.graphicsBackendMode == .auto else {
                bottle.settings.inferredGraphicsBackendMode = nil
                bottle.settings.inferredFallbackGraphicsBackendMode = nil
                return nil as (primary: GraphicsBackendMode, fallback: GraphicsBackendMode?)?
            }

            return preferredBackendRecommendation(from: rules, in: bottle)
        }
        guard await MainActor.run(body: { bottle.settings.graphicsBackendMode == .auto }) else {
            return
        }

        let recommendation = await DispatchBackendInferenceService.shared.recommendBackend(
            for: bottle,
            rules: rules,
            fallback: fallbackRecommendation
        )
        await MainActor.run {
            guard bottle.settings.graphicsBackendMode == .auto else {
                bottle.settings.inferredGraphicsBackendMode = nil
                bottle.settings.inferredFallbackGraphicsBackendMode = nil
                return
            }

            bottle.settings.inferredGraphicsBackendMode = recommendation?.primary
            bottle.settings.inferredFallbackGraphicsBackendMode = recommendation?.fallback
        }
    }

    fileprivate static func preferredBackendRecommendation(
        from rules: [DispatchPatchRule],
        in bottle: Bottle
    ) -> (primary: GraphicsBackendMode, fallback: GraphicsBackendMode?)? {
        let activeSteamAppID = bottle.settings.activeSteamAppID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bestMatch = rules.first { rule in
            return !rule.steamAppID.isEmpty && rule.steamAppID == activeSteamAppID
        } ?? {
            guard activeSteamAppID.isEmpty else {
                return nil
            }
            let backendRules = rules.filter { $0.graphicsBackend != nil }
            return backendRules.count == 1 ? backendRules.first : nil
        }()

        guard let bestMatch, let primary = bestMatch.graphicsBackend else {
            return nil
        }

        return (primary, bestMatch.fallbackGraphicsBackend)
    }

    private static func pinProgramIfNeeded(at url: URL, in bottle: Bottle, name: String) {
        if bottle.settings.pins.contains(where: { $0.url == url }) {
            return
        }
        bottle.settings.pins.append(PinnedProgram(name: name, url: url))
    }

    private static func downloadFile(from remoteURL: URL, to destination: URL) async throws {
        let request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        if FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
    }

    private static func runInstallerIfPossible(installerURL: URL, descriptor: LauncherDescriptor, bottle: Bottle) async throws {
        let extensionName = installerURL.pathExtension.lowercased()
        if extensionName == "exe" {
            _ = try await Wine.runProgramDirectWithTerminationStatus(
                at: installerURL,
                args: descriptor.silentArguments,
                bottle: bottle
            )
            return
        }

        if extensionName == "msi" {
            _ = try await Wine.runWine(
                [
                    "msiexec",
                    "/i",
                    installerURL.path(percentEncoded: false),
                    "/qn",
                    "/norestart"
                ],
                bottle: bottle,
                collectOutput: false
            )
        }
    }
}

public actor DispatchPatchService {
    public static let shared = DispatchPatchService()
    private var inMemoryCache: [String: DispatchPatchCacheEnvelope] = [:]
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    private let encoder = JSONEncoder()

    public func rules(for bottle: Bottle, forceRefresh: Bool) async -> [DispatchPatchRule] {
        guard bottle.settings.patchDispatchEnabled else {
            return []
        }

        let endpointString = bottle.settings.patchDispatchEndpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let channel = bottle.settings.patchDispatchChannel
        let requireSignedRules = bottle.settings.patchDispatchRequireSignedRules
        let localRules = loadLocalOverrideRules(for: bottle, channel: channel)
        let compatibilityRules = loadCompatibilityPatchCatalogRules(for: bottle, channel: channel)

        guard !endpointString.isEmpty,
              var endpointComponents = URLComponents(string: endpointString) else {
            return securityFilteredWinners(compatibilityRules + localRules, for: bottle)
        }
        let hasChannelQuery = (endpointComponents.queryItems ?? []).contains {
            $0.name.caseInsensitiveCompare("channel") == .orderedSame
        }
        if !hasChannelQuery {
            var items = endpointComponents.queryItems ?? []
            items.append(URLQueryItem(name: "channel", value: channel.rawValue))
            endpointComponents.queryItems = items
        }
        guard let endpointURL = endpointComponents.url else {
            return []
        }

        let key = bottle.url.path(percentEncoded: false)
        let refreshInterval = TimeInterval(max(1, bottle.settings.patchDispatchRefreshIntervalMinutes) * 60)
        if !forceRefresh,
           let cached = cachedEnvelope(for: key, bottle: bottle),
           Date().timeIntervalSince(cached.fetchedAt) < refreshInterval {
            return securityFilteredWinners(cached.rules + compatibilityRules + localRules, for: bottle)
        }

        do {
            let request = URLRequest(
                url: endpointURL,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                timeoutInterval: 8
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let envelope = try decoder.decode(DispatchPatchEnvelope.self, from: data)
            let filteredRemoteRules = envelope.rules.filter { rule in
                if rule.channel != channel {
                    return false
                }

                if requireSignedRules {
                    return DispatchPatchSignatureVerifier.isRuleSignatureValid(rule)
                }

                return true
            }

            let resolvedRules = securityFilteredWinners(
                filteredRemoteRules + compatibilityRules + localRules,
                for: bottle
            )

            let cacheEnvelope = DispatchPatchCacheEnvelope(
                fetchedAt: Date(),
                version: envelope.version,
                generatedAt: envelope.generatedAt,
                changelog: envelope.changelog,
                rules: filteredRemoteRules
            )
            inMemoryCache[key] = cacheEnvelope
            saveCacheEnvelope(cacheEnvelope, for: bottle)
            return resolvedRules
        } catch {
            Logger.wineKit.warning(
                "Dispatch fetch failed for \(endpointString, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )

            if let fallback = cachedEnvelope(for: key, bottle: bottle) {
                return securityFilteredWinners(fallback.rules + compatibilityRules + localRules, for: bottle)
            }

            return securityFilteredWinners(compatibilityRules + localRules, for: bottle)
        }
    }

    public func status(for bottle: Bottle, checkRemote: Bool) async -> DispatchPatchStatus {
        let endpointString = bottle.settings.patchDispatchEndpointURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let channel = bottle.settings.patchDispatchChannel
        let dispatchEnabled = bottle.settings.patchDispatchEnabled

        if dispatchEnabled, checkRemote {
            _ = await rules(for: bottle, forceRefresh: true)
        }

        let key = bottle.url.path(percentEncoded: false)
        let cached = cachedEnvelope(for: key, bottle: bottle)

        let remoteVersion = cached?.version ?? 0
        let remoteGeneratedAt = cached?.generatedAt ?? ""
        let remoteChangelog = cached?.changelog ?? ""
        let remoteRules = cached?.rules ?? []
        let localRules = loadLocalOverrideRules(for: bottle, channel: channel)
        let compatibilityRules = loadCompatibilityPatchCatalogRules(for: bottle, channel: channel)
        let effectiveRules = securityFilteredWinners(remoteRules + compatibilityRules + localRules, for: bottle)
        let remoteRuleCount = remoteRules.count
        let remoteRuleVersion = remoteRules.map(\.ruleVersion).max() ?? 0
        let remoteRulesDigest = rulesDigest(remoteRules)
        let effectiveRuleCount = effectiveRules.count
        let effectiveRulesDigest = rulesDigest(effectiveRules)
        let inferredRecommendation = await DispatchBackendInferenceService.shared.recommendBackend(
            for: bottle,
            rules: effectiveRules,
            fallback: BottleGamingModeManager.preferredBackendRecommendation(
                from: effectiveRules,
                in: bottle
            )
        )
        let backendHint = inferredRecommendation?.primary ?? effectiveRules.compactMap(\.graphicsBackend).first
        let fallbackBackendHint = inferredRecommendation?.fallback
            ?? effectiveRules.compactMap(\.fallbackGraphicsBackend).first
        let fetchedAt = cached?.fetchedAt

        let appliedVersion = bottle.settings.patchDispatchLastAppliedVersion
        let appliedGeneratedAt = bottle.settings.patchDispatchLastAppliedGeneratedAt
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let appliedRulesDigest = bottle.settings.patchDispatchLastAppliedRulesDigest
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let appliedAt = bottle.settings.patchDispatchLastAppliedAt

        let updateAvailable: Bool
        if !dispatchEnabled {
            updateAvailable = false
        } else if effectiveRuleCount == 0 {
            updateAvailable = false
        } else if !appliedRulesDigest.isEmpty {
            updateAvailable = effectiveRulesDigest != appliedRulesDigest
        } else if remoteRuleVersion > 0 && remoteRuleVersion != appliedVersion {
            updateAvailable = true
        } else if remoteVersion > 0 && remoteVersion != appliedVersion {
            updateAvailable = true
        } else if !remoteGeneratedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updateAvailable = remoteGeneratedAt != appliedGeneratedAt
        } else {
            updateAvailable = appliedAt == nil
        }

        return DispatchPatchStatus(
            endpointURL: endpointString,
            channel: channel,
            dispatchEnabled: dispatchEnabled,
            remoteVersion: remoteVersion,
            remoteGeneratedAt: remoteGeneratedAt,
            remoteChangelog: remoteChangelog,
            remoteRuleCount: remoteRuleCount,
            remoteRuleVersion: remoteRuleVersion,
            remoteRulesDigest: remoteRulesDigest,
            effectiveRuleCount: effectiveRuleCount,
            effectiveRulesDigest: effectiveRulesDigest,
            recommendedBackend: backendHint,
            fallbackBackend: fallbackBackendHint,
            lastFetchedAt: fetchedAt,
            lastAppliedVersion: appliedVersion,
            lastAppliedGeneratedAt: appliedGeneratedAt,
            lastAppliedRulesDigest: appliedRulesDigest,
            lastAppliedAt: appliedAt,
            updateAvailable: updateAvailable
        )
    }

    public func doctorSignals(
        for bottle: Bottle,
        executablePath: String = "",
        logText: String = ""
    ) async -> [DispatchDoctorSignal] {
        guard bottle.settings.patchDispatchEnabled,
              let endpointURL = doctorSignalsURL(
                from: bottle.settings.patchDispatchEndpointURL,
                bottle: bottle,
                executablePath: executablePath
              ) else {
            return []
        }

        do {
            let request = URLRequest(
                url: endpointURL,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                timeoutInterval: 6
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let envelope = try decoder.decode(DispatchDoctorSignalsEnvelope.self, from: data)
            return envelope.signals.filter {
                doctorSignal($0, matchesBottle: bottle, executablePath: executablePath, logText: logText)
            }
        } catch {
            Logger.wineKit.warning(
                "VecPatch doctor signal fetch failed for \(endpointURL.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }

    public func reportTelemetry(
        for bottle: Bottle,
        programPath: String,
        success: Bool,
        fpsAverage: Double? = nil,
        crashSignature: String? = nil
    ) async {
        guard bottle.settings.patchDispatchEnabled else {
            return
        }

        let rules = await rules(for: bottle, forceRefresh: false)
        let matchingRules = rules.filter { rule in
            if !rule.executableMatch.isEmpty && programPath.lowercased().contains(rule.executableMatch.lowercased()) {
                return true
            }
            let appID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
            return !appID.isEmpty && !rule.steamAppID.isEmpty && rule.steamAppID == appID
        }

        let activeRule = matchingRules.first ?? rules.first
        let endpointURL = telemetryURL(from: bottle.settings.patchDispatchEndpointURL)
        guard let endpointURL else { return }

        var payload: [String: Any] = [
            "event_type": "launch_result",
            "success": success,
            "channel": bottle.settings.patchDispatchChannel.rawValue,
            "program_path": programPath,
            "graphics_backend": activeRule?.graphicsBackend?.rawValue ?? bottle.settings.graphicsBackendMode.rawValue,
            "fallback_graphics_backend":
                activeRule?.fallbackGraphicsBackend?.rawValue ?? "",
            "steam_app_id": bottle.settings.activeSteamAppID,
            "rule_ids": matchingRules.map(\.id),
            "rule_versions": matchingRules.map(\.ruleVersion)
        ]

        if let fpsAverage {
            payload["fps_average"] = fpsAverage
        }
        if let crashSignature, !crashSignature.isEmpty {
            payload["crash_signature"] = crashSignature
        }

        await sendTelemetryPayload(payload, to: endpointURL)
    }

    public func reportPatchSyncTelemetry(
        for bottle: Bottle,
        updatedRuleCount: Int,
        success: Bool,
        details: String = ""
    ) async {
        guard bottle.settings.patchDispatchEnabled else {
            return
        }
        guard let endpointURL = telemetryURL(from: bottle.settings.patchDispatchEndpointURL) else {
            return
        }

        let payload: [String: Any] = [
            "event_type": "patch_sync",
            "success": success,
            "channel": bottle.settings.patchDispatchChannel.rawValue,
            "rule_count": updatedRuleCount,
            "graphics_backend": bottle.settings.graphicsBackendMode.rawValue,
            "details": details,
            "steam_app_id": bottle.settings.activeSteamAppID
        ]
        await sendTelemetryPayload(payload, to: endpointURL)
    }

    public func localOverridesDocument(for bottle: Bottle) -> DispatchPatchLocalOverridesDocument {
        let rules = loadLocalOverrideRules(for: bottle, channel: bottle.settings.patchDispatchChannel)
        let url = localOverrideURL(for: bottle)
        let generatedAt: String
        if let data = try? Data(contentsOf: url),
           let envelope = try? decoder.decode(DispatchPatchLocalOverrideEnvelope.self, from: data) {
            generatedAt = envelope.generatedAt
        } else {
            generatedAt = ""
        }

        return DispatchPatchLocalOverridesDocument(
            version: 1,
            generatedAt: generatedAt,
            rules: rules
        )
    }

    public func saveLocalOverridesDocument(
        _ document: DispatchPatchLocalOverridesDocument,
        for bottle: Bottle
    ) throws {
        let url = localOverrideURL(for: bottle)
        let path = url.path(percentEncoded: false)

        let localRules = document.rules.map { rule in
            var normalized = rule
            normalized.source = .local
            normalized.channel = bottle.settings.patchDispatchChannel
            return normalized
        }
        let envelope = DispatchPatchLocalOverrideEnvelope(
            version: max(1, document.version),
            generatedAt: document.generatedAt,
            rules: localRules
        )

        if envelope.rules.isEmpty {
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(at: url)
            }
            return
        }

        let data = try encoder.encode(envelope)
        try data.write(to: url, options: .atomic)
    }

    private func rulesDigest(_ rules: [DispatchPatchRule]) -> String {
        guard !rules.isEmpty else {
            return ""
        }

        let normalized = rules
            .sorted { lhs, rhs in
                if lhs.mergeIdentity != rhs.mergeIdentity {
                    return lhs.mergeIdentity < rhs.mergeIdentity
                }
                if lhs.ruleVersion != rhs.ruleVersion {
                    return lhs.ruleVersion < rhs.ruleVersion
                }
                return lhs.id < rhs.id
            }
            .map { rule in
                let environment = rule.environment
                    .sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending })
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: ";")
                let backend = rule.graphicsBackend?.rawValue ?? ""
                let fallback = rule.fallbackGraphicsBackend?.rawValue ?? ""
                return [
                    rule.id,
                    rule.name,
                    rule.executableMatch.lowercased(),
                    rule.steamAppID,
                    rule.arguments,
                    environment,
                    rule.enabled ? "1" : "0",
                    rule.channel.rawValue,
                    rule.signature,
                    String(rule.priority),
                    String(rule.ruleVersion),
                    backend,
                    fallback,
                    rule.source.rawValue
                ].joined(separator: "|")
            }
            .joined(separator: "\n")

        let hash = SHA256.hash(data: Data(normalized.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func cachedEnvelope(for key: String, bottle: Bottle) -> DispatchPatchCacheEnvelope? {
        if let inMemory = inMemoryCache[key] {
            return inMemory
        }

        guard let disk = loadCacheEnvelope(for: bottle) else {
            return nil
        }

        inMemoryCache[key] = disk
        return disk
    }

    private func cacheURL(for bottle: Bottle) -> URL {
        bottle.url.appending(path: dispatchCacheFilename)
    }

    private func localOverrideURL(for bottle: Bottle) -> URL {
        bottle.url.appending(path: dispatchLocalOverridesFilename)
    }

    private func loadCacheEnvelope(for bottle: Bottle) -> DispatchPatchCacheEnvelope? {
        let url = cacheURL(for: bottle)
        let path = url.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: url),
              let envelope = try? decoder.decode(DispatchPatchCacheEnvelope.self, from: data) else {
            return nil
        }
        return envelope
    }

    private func saveCacheEnvelope(_ envelope: DispatchPatchCacheEnvelope, for bottle: Bottle) {
        let url = cacheURL(for: bottle)
        do {
            let data = try encoder.encode(envelope)
            try data.write(to: url, options: .atomic)
        } catch {
            Logger.wineKit.warning(
                "Failed to persist dispatch cache at \(url.path(percentEncoded: false), privacy: .public)"
            )
        }
    }

    private func loadLocalOverrideRules(
        for bottle: Bottle,
        channel: DispatchPatchChannel
    ) -> [DispatchPatchRule] {
        let url = localOverrideURL(for: bottle)
        let path = url.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: url),
              let envelope = try? decoder.decode(DispatchPatchLocalOverrideEnvelope.self, from: data) else {
            return []
        }

        return envelope.rules.compactMap { rule in
            guard rule.channel == channel else { return nil }
            var localRule = rule
            localRule.source = .local
            if localRule.priority == 100 {
                localRule.priority = 0
            }
            return localRule
        }
    }

    private func securityFilteredWinners(_ rules: [DispatchPatchRule], for bottle: Bottle) -> [DispatchPatchRule] {
        let filtered = rules.filter {
            VectorProtectedTitlePolicyEngine.ruleAllowed($0, in: bottle)
        }
        return BottleGamingModeManager.selectRuleWinners(from: filtered)
    }

    private func loadCompatibilityPatchCatalogRules(
        for bottle: Bottle,
        channel: DispatchPatchChannel
    ) -> [DispatchPatchRule] {
        let decoder = self.decoder
        let ruleFiles = resolveCompatibilityPatchRuleFiles()
        guard !ruleFiles.isEmpty else {
            return []
        }

        var rules: [DispatchPatchRule] = []
        for ruleFile in ruleFiles {
            guard let data = try? Data(contentsOf: ruleFile) else {
                continue
            }

            let decodedRules: [DispatchPatchRule]
            if let envelope = try? decoder.decode(DispatchPatchEnvelope.self, from: data) {
                decodedRules = envelope.rules
            } else if let envelope = try? decoder.decode(DispatchPatchLocalOverrideEnvelope.self, from: data) {
                decodedRules = envelope.rules
            } else if let directRules = try? decoder.decode([DispatchPatchRule].self, from: data) {
                decodedRules = directRules
            } else {
                continue
            }

            let source = patchRuleSource(for: ruleFile) ?? .crossover
            for rule in decodedRules where rule.channel == channel {
                var catalogRule = rule
                catalogRule.source = source
                if catalogRule.priority == 100 {
                    catalogRule.priority = 150
                }
                rules.append(catalogRule)
            }
        }

        return rules
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func resolveCompatibilityPatchRuleFiles() -> [URL] {
        let fileManager = FileManager.default
        var searchRoots: [URL] = []

        if let overridePath = ProcessInfo.processInfo.environment["VECTOR_CROSSOVER_PATCH_RULES_DIR"],
           !overridePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchRoots.append(URL(filePath: overridePath))
        }
        if let defaultsPath = UserDefaults.standard.string(forKey: "crossOverPatchRulesDirectory"),
           !defaultsPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchRoots.append(URL(filePath: defaultsPath))
        }
        if let overridePath = ProcessInfo.processInfo.environment["VECTOR_COMPAT_PATCH_RULES_DIR"],
           !overridePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchRoots.append(URL(filePath: overridePath))
        }
        if let overridePath = ProcessInfo.processInfo.environment["VECTOR_PROTON_PATCH_RULES_DIR"],
           !overridePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchRoots.append(URL(filePath: overridePath))
        }
        if let defaultsPath = UserDefaults.standard.string(forKey: "compatibilityPatchRulesDirectory"),
           !defaultsPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchRoots.append(URL(filePath: defaultsPath))
        }
        if let defaultsPath = UserDefaults.standard.string(forKey: "protonPatchRulesDirectory"),
           !defaultsPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchRoots.append(URL(filePath: defaultsPath))
        }

        searchRoots.append(VectorWineInstaller.libraryFolder.appending(path: "Patchsets"))
        searchRoots.append(VectorWineInstaller.libraryFolder.appending(path: "Wine").appending(path: "patchsets"))
        if let resourceURL = Bundle.main.resourceURL {
            searchRoots.append(resourceURL.appending(path: "runtime").appending(path: "Wine").appending(path: "patchsets"))
            searchRoots.append(resourceURL.appending(path: "Wine").appending(path: "patchsets"))
        }

        let sourceFileURL = URL(filePath: #filePath)
        var candidateRoot = sourceFileURL.deletingLastPathComponent()
        for _ in 0..<8 {
            let patchsetRoot = candidateRoot
                .appending(path: "runtime")
                .appending(path: "Wine")
                .appending(path: "patchsets")
            if fileManager.fileExists(atPath: patchsetRoot.path(percentEncoded: false)) {
                searchRoots.append(patchsetRoot)
                break
            }
            candidateRoot.deleteLastPathComponent()
        }

        var seenRoots = Set<String>()
        let uniqueRoots = searchRoots.filter { root in
            let path = root.path(percentEncoded: false)
            return seenRoots.insert(path).inserted && fileManager.fileExists(atPath: path)
        }

        var seenFiles = Set<String>()
        var ruleFiles: [URL] = []
        for root in uniqueRoots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                guard fileURL.lastPathComponent == "dispatch-rules.json" else {
                    continue
                }
                guard patchRuleSource(for: fileURL) != nil else {
                    continue
                }

                let path = fileURL.path(percentEncoded: false)
                if seenFiles.insert(path).inserted {
                    ruleFiles.append(fileURL)
                }
            }
        }

        return ruleFiles.sorted {
            $0.path(percentEncoded: false) < $1.path(percentEncoded: false)
        }
    }

    private func patchRuleSource(for ruleFileURL: URL) -> DispatchPatchRuleSource? {
        let fileManager = FileManager.default
        let directoryName = ruleFileURL.deletingLastPathComponent().lastPathComponent.lowercased()
        if directoryName.contains("crossover") || directoryName.contains("winecx") {
            return .crossover
        }
        if directoryName.contains("proton") || directoryName.contains("wine-ge")
            || directoryName.contains("wine_ge") || directoryName.contains("umu") {
            return .proton
        }

        let patchsetManifestURL = ruleFileURL.deletingLastPathComponent().appending(path: "patchset.json")
        guard fileManager.fileExists(atPath: patchsetManifestURL.path(percentEncoded: false)),
              let data = try? Data(contentsOf: patchsetManifestURL),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let patchset = jsonObject["patchset"] as? [String: Any] else {
            return nil
        }

        let fields = [
            patchset["label"] as? String,
            patchset["baseWineSource"] as? String,
            patchset["crossoverWineSource"] as? String,
            patchset["protonWineSource"] as? String,
            patchset["protonSource"] as? String,
            patchset["wineGESource"] as? String
        ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        if fields.contains("crossover") || fields.contains("winecx") {
            return .crossover
        }
        if fields.contains("proton") || fields.contains("wine-ge") || fields.contains("wine_ge")
            || fields.contains("umu") {
            return .proton
        }
        return nil
    }

    private func telemetryURL(from patchEndpoint: String) -> URL? {
        let trimmed = patchEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var components = URLComponents(string: trimmed) else {
            return nil
        }
        let patchPath = components.path
        if patchPath.hasSuffix("/patches") {
            components.path = String(patchPath.dropLast("/patches".count)) + "/telemetry"
        } else {
            let basePath = patchPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = basePath.isEmpty ? "/api/v1/telemetry" : "/\(basePath)/telemetry"
        }
        components.query = nil
        return components.url
    }

    private func doctorSignalsURL(from patchEndpoint: String, bottle: Bottle, executablePath: String) -> URL? {
        let trimmed = patchEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var components = URLComponents(string: trimmed) else {
            return nil
        }

        let patchPath = components.path
        if patchPath.hasSuffix("/patches") {
            components.path = String(patchPath.dropLast("/patches".count)) + "/doctor-signals"
        } else if patchPath.hasSuffix("/rules") {
            components.path = String(patchPath.dropLast("/rules".count)) + "/doctor-signals"
        } else {
            let basePath = patchPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = basePath.isEmpty ? "/api/v1/doctor-signals" : "/\(basePath)/doctor-signals"
        }

        components.queryItems = [
            URLQueryItem(name: "channel", value: bottle.settings.patchDispatchChannel.rawValue),
            URLQueryItem(
                name: "steam_app_id",
                value: bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            URLQueryItem(name: "executable", value: executablePath)
        ]
        return components.url
    }

    private func doctorSignal(
        _ signal: DispatchDoctorSignal,
        matchesBottle bottle: Bottle,
        executablePath: String,
        logText: String
    ) -> Bool {
        let normalizedExecutablePath = executablePath.lowercased()
        let normalizedLogText = logText.lowercased()
        let signalAppID = signal.steamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        let activeAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)

        if !signalAppID.isEmpty, signalAppID == activeAppID {
            return true
        }
        if !signal.executableMatch.isEmpty,
           normalizedExecutablePath.contains(signal.executableMatch.lowercased()) {
            return true
        }
        return signal.matchFragments.contains { fragment in
            let normalized = fragment.lowercased()
            return normalizedExecutablePath.contains(normalized) || normalizedLogText.contains(normalized)
        }
    }

    private func sendTelemetryPayload(_ payload: [String: Any], to url: URL) async {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 6
        request.httpBody = data

        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            Logger.wineKit.warning(
                "VecPatch telemetry submit failed for \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

// swiftlint:enable file_length function_body_length line_length type_body_length
