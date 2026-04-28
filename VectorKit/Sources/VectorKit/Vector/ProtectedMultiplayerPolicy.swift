//
//  ProtectedMultiplayerPolicy.swift
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

// swiftlint:disable file_length type_body_length

public enum GameTrustClassification: String, Codable, CaseIterable, Hashable, Sendable {
    case singlePlayer
    case moddingAllowed
    case protectedMultiplayer
    case blockedAntiCheat
}

public enum ProtectedRuleRiskLevel: String, Codable, CaseIterable, Hashable, Sendable {
    case low
    case medium
    case high
    case blocked
}

public enum ProtectedLocalLaunchDisposition: String, Codable, CaseIterable, Hashable, Sendable {
    case allow
    case warn
    case block
    case remoteOnly
}

public struct ProtectedTitlePolicy: Codable, Equatable, Sendable {
    public var allowMemoryAccess: Bool
    public var allowTrainerLaunch: Bool
    public var allowLocalOverrides: Bool
    public var allowUnsignedRules: Bool
    public var allowDebugTooling: Bool
    public var allowCustomLaunchMutations: Bool
    public var allowedDLLOverrides: [String]
    public var allowedLaunchArguments: [String]
    public var localLaunchDisposition: ProtectedLocalLaunchDisposition

    private enum CodingKeys: String, CodingKey {
        case allowMemoryAccess
        case allowTrainerLaunch
        case allowLocalOverrides
        case allowUnsignedRules
        case allowDebugTooling
        case allowCustomLaunchMutations
        case allowedDLLOverrides = "allowedDllOverrides"
        case allowedLaunchArguments
        case localLaunchDisposition
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case allowedDLLOverrides
    }

    public init(
        allowMemoryAccess: Bool,
        allowTrainerLaunch: Bool,
        allowLocalOverrides: Bool,
        allowUnsignedRules: Bool,
        allowDebugTooling: Bool,
        allowCustomLaunchMutations: Bool,
        allowedDLLOverrides: [String],
        allowedLaunchArguments: [String],
        localLaunchDisposition: ProtectedLocalLaunchDisposition
    ) {
        self.allowMemoryAccess = allowMemoryAccess
        self.allowTrainerLaunch = allowTrainerLaunch
        self.allowLocalOverrides = allowLocalOverrides
        self.allowUnsignedRules = allowUnsignedRules
        self.allowDebugTooling = allowDebugTooling
        self.allowCustomLaunchMutations = allowCustomLaunchMutations
        self.allowedDLLOverrides = allowedDLLOverrides
        self.allowedLaunchArguments = allowedLaunchArguments
        self.localLaunchDisposition = localLaunchDisposition
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)

        self.allowMemoryAccess = try container.decodeIfPresent(Bool.self, forKey: .allowMemoryAccess) ?? false
        self.allowTrainerLaunch = try container.decodeIfPresent(Bool.self, forKey: .allowTrainerLaunch) ?? false
        self.allowLocalOverrides = try container.decodeIfPresent(Bool.self, forKey: .allowLocalOverrides) ?? false
        self.allowUnsignedRules = try container.decodeIfPresent(Bool.self, forKey: .allowUnsignedRules) ?? false
        self.allowDebugTooling = try container.decodeIfPresent(Bool.self, forKey: .allowDebugTooling) ?? false
        self.allowCustomLaunchMutations = try container.decodeIfPresent(
            Bool.self,
            forKey: .allowCustomLaunchMutations
        ) ?? false
        self.allowedDLLOverrides = try container.decodeIfPresent([String].self, forKey: .allowedDLLOverrides)
            ?? legacyContainer.decodeIfPresent([String].self, forKey: .allowedDLLOverrides)
            ?? []
        self.allowedLaunchArguments = try container.decodeIfPresent(
            [String].self,
            forKey: .allowedLaunchArguments
        ) ?? []
        self.localLaunchDisposition = try container.decodeIfPresent(
            ProtectedLocalLaunchDisposition.self,
            forKey: .localLaunchDisposition
        ) ?? .block
    }

    public static let hardLockdown = ProtectedTitlePolicy(
        allowMemoryAccess: false,
        allowTrainerLaunch: false,
        allowLocalOverrides: false,
        allowUnsignedRules: false,
        allowDebugTooling: false,
        allowCustomLaunchMutations: false,
        allowedDLLOverrides: [],
        allowedLaunchArguments: [],
        localLaunchDisposition: .block
    )
}

public struct ProtectedTitleDescriptor: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var steamAppID: String
    public var executableMatches: [String]
    public var pathFragments: [String]
    public var antiCheatProvider: String
    public var trustClassification: GameTrustClassification
    public var officialSupportRequired: Bool
    public var fallbackPlayOptions: [String]
    public var supportContactStatus: String
    public var policy: ProtectedTitlePolicy

    public init(
        id: String,
        title: String,
        steamAppID: String,
        executableMatches: [String],
        pathFragments: [String],
        antiCheatProvider: String,
        trustClassification: GameTrustClassification,
        officialSupportRequired: Bool,
        fallbackPlayOptions: [String],
        supportContactStatus: String,
        policy: ProtectedTitlePolicy
    ) {
        self.id = id
        self.title = title
        self.steamAppID = steamAppID
        self.executableMatches = executableMatches
        self.pathFragments = pathFragments
        self.antiCheatProvider = antiCheatProvider
        self.trustClassification = trustClassification
        self.officialSupportRequired = officialSupportRequired
        self.fallbackPlayOptions = fallbackPlayOptions
        self.supportContactStatus = supportContactStatus
        self.policy = policy
    }
}

public struct ProtectedLaunchAssessment: Codable, Equatable, Sendable {
    public var matchedTitle: ProtectedTitleDescriptor?
    public var trustClassification: GameTrustClassification
    public var localLaunchDisposition: ProtectedLocalLaunchDisposition
    public var detectedArtifacts: [String]
    public var reasons: [String]

    public var shouldBlockLocalLaunch: Bool {
        localLaunchDisposition == .block || localLaunchDisposition == .remoteOnly
    }

    public static let allowed = ProtectedLaunchAssessment(
        matchedTitle: nil,
        trustClassification: .singlePlayer,
        localLaunchDisposition: .allow,
        detectedArtifacts: [],
        reasons: []
    )
}

public struct RuntimeAttestationRecord: Codable, Equatable, Sendable {
    public var label: String
    public var path: String
    public var sha256: String?
    public var present: Bool
}

public struct VectorRuntimeAttestation: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var generatedAt: String
    public var hostCapabilities: VectorHostSecurityCapabilityReport
    public var vectorVersion: String
    public var wineVersion: String
    public var dxvkVersion: String
    public var d3dMetalVersion: String
    public var winetricksVersion: String
    public var wineMonoVersion: String
    public var appBundleIdentifier: String
    public var appBundlePath: String
    public var appCodesignIdentifier: String
    public var appTeamIdentifier: String
    public var appSigningAuthorities: [String]
    public var appEntitlements: [String: String]
    public var notarizationState: String
    public var hardenedRuntime: String
    public var runtimePatchDigest: String
    public var records: [RuntimeAttestationRecord]
}

public struct VectorStudioReviewBundle: Codable, Equatable, Sendable {
    public var generatedAt: String
    public var bottleName: String
    public var bottlePath: String
    public var requestedSteamAppID: String
    public var launchAssessment: ProtectedLaunchAssessment
    public var runtimeAttestation: VectorRuntimeAttestation
    public var patchDispatchEndpoint: String
    public var patchDispatchChannel: String
    public var patchDispatchRequireSignedRules: Bool
    public var patchDispatchLastRulesDigest: String
    public var safeMultiplayerMode: Bool
    public var trainerSupportMode: Bool
    public var activeSteamAppID: String
    public var policyStatement: String
}

public enum VectorDeveloperToolPolicy {
    public static var developerToolsEnabled: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["VECTOR_DEVELOPER_TOOLS"] == "1" {
            return true
        }
        return UserDefaults.standard.bool(forKey: "VectorDeveloperToolsEnabled")
    }

    public static var advancedDiagnosticsEnabled: Bool {
        guard developerToolsEnabled else {
            return false
        }
        return VectorHostSecurityCapabilityProbe.current().hostAllowsAdvancedDiagnostics
    }

    public static func assertAdvancedDiagnosticsAllowed() throws {
        guard developerToolsEnabled else {
            throw WineProcessMemoryError.protectedToolingUnavailable(
                "Advanced diagnostics require Developer Mode."
            )
        }
        guard VectorHostSecurityCapabilityProbe.current().hostAllowsAdvancedDiagnostics else {
            throw WineProcessMemoryError.protectedToolingUnavailable(
                "Advanced diagnostics require Reduced Security, permissive security, or disabled SIP."
            )
        }
    }
}

public enum VectorProtectedTitlePolicyEngine {
    private struct CodeSignatureMetadata {
        let identifier: String
        let teamIdentifier: String
        let authorities: [String]
        let entitlements: [String: String]
        let notarizationState: String
        let hardenedRuntime: String
    }

    private struct SystemToolResult {
        let stdout: String
        let stderr: String
        let code: Int32
    }

    private static let protectedAntiCheatMarkerFragments = [
        "easyanticheat",
        "easyanticheat_eos",
        "eos_anticheat",
        "eosanticheat",
        "start_protected_game",
        "embarkgameboot",
        "battleye",
        "beservice",
        "beclient",
        "bedaisy",
        "ricochet",
        "randgrid",
        "vgk",
        "vanguard",
        "equ8",
        "xigncode",
        "wellbia",
        "nprotect",
        "gameguard",
        "faceit"
    ]

    public static let arcRaiders = ProtectedTitleDescriptor(
        id: "arc-raiders",
        title: "ARC Raiders",
        steamAppID: "1808500",
        executableMatches: [
            "arcraiders.exe",
            "arc-raiders.exe",
            "embarkgameboot.exe"
        ],
        pathFragments: [
            "arc raiders",
            "arcraiders",
            "embarkgameboot"
        ],
        antiCheatProvider: "Easy Anti-Cheat / Embark Game Boot",
        trustClassification: .blockedAntiCheat,
        officialSupportRequired: true,
        fallbackPlayOptions: [
            "Steam Remote Play from a Windows PC",
            "Steam Deck or SteamOS with official Proton/EAC support",
            "Moonlight/Sunshine from a trusted Windows host",
            "Cloud streaming provider if ARC Raiders is available"
        ],
        supportContactStatus: "Not contacted / official Vector support required",
        policy: .hardLockdown
    )

    public static let protectedTitles: [ProtectedTitleDescriptor] = [arcRaiders]

    public static func assessLaunch(
        programURL: URL,
        bottle: Bottle,
        activeSteamAppID: String,
        detectedArtifacts: [String]
    ) -> ProtectedLaunchAssessment {
        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedProgramPath = normalizedPath(programURL.path(percentEncoded: false))
        let normalizedArtifacts = detectedArtifacts.map(normalizedPath)

        if let descriptor = protectedTitles.first(where: { descriptor in
            matches(descriptor, appID: normalizedAppID)
                || matches(descriptor, path: normalizedProgramPath)
                || normalizedArtifacts.contains(where: { matches(descriptor, path: $0) })
        }) {
            return blockedAssessment(for: descriptor, artifacts: detectedArtifacts)
        }

        if detectedArtifacts.contains(where: isProtectedAntiCheatArtifact) {
            let generic = genericBlockedAntiCheatDescriptor(for: detectedArtifacts)
            return blockedAssessment(for: generic, artifacts: detectedArtifacts)
        }

        _ = bottle
        return .allowed
    }

    public static func protectedAssessment(for bottle: Bottle) -> ProtectedLaunchAssessment? {
        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let descriptor = protectedTitles.first(where: { matches($0, appID: activeSteamAppID) }) {
            return blockedAssessment(for: descriptor, artifacts: [])
        }

        let normalizedBottlePath = normalizedPath(bottle.url.path(percentEncoded: false))
        if let descriptor = protectedTitles.first(where: { matches($0, path: normalizedBottlePath) }) {
            return blockedAssessment(for: descriptor, artifacts: [])
        }

        return nil
    }

    public static func scannedProtectedAssessment(
        for bottle: Bottle,
        maxFindings: Int = 12
    ) -> ProtectedLaunchAssessment? {
        if let assessment = protectedAssessment(for: bottle) {
            return assessment
        }

        let findings = scanBottleForProtectedArtifacts(bottle.url, maxFindings: maxFindings)
        guard !findings.isEmpty else {
            return nil
        }

        let descriptor = findings.contains(where: { matches(arcRaiders, path: normalizedPath($0)) })
            ? arcRaiders
            : genericBlockedAntiCheatDescriptor(for: findings)
        return blockedAssessment(for: descriptor, artifacts: findings)
    }

    public static func ruleAllowed(_ rule: DispatchPatchRule, in bottle: Bottle) -> Bool {
        guard let assessment = scannedProtectedAssessment(for: bottle), let title = assessment.matchedTitle else {
            return true
        }

        let appliesToProtectedTitle = matches(title, appID: rule.steamAppID)
            || matches(title, path: rule.executableMatch)
            || rule.trustClass == .protectedMultiplayer
            || rule.trustClass == .blockedAntiCheat
        guard appliesToProtectedTitle else {
            return true
        }

        let policy = rule.protectedTitlePolicy ?? title.policy
        if rule.source == .local, !policy.allowLocalOverrides {
            return false
        }
        if !rule.studioApproved {
            return false
        }
        if !policy.allowUnsignedRules, !DispatchPatchSignatureVerifier.isRuleSignatureValid(rule) {
            return false
        }
        if !policy.allowCustomLaunchMutations {
            let hasArguments = !rule.arguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasEnvironment = !rule.environment.isEmpty
            let hasGraphicsOverride = rule.graphicsBackend != nil || rule.fallbackGraphicsBackend != nil
            if hasArguments || hasEnvironment || hasGraphicsOverride {
                return false
            }
        }
        return rule.officialSupportRequired == title.officialSupportRequired
    }

    public static func assertMemoryToolingAllowed(for bottle: Bottle) throws {
        try VectorDeveloperToolPolicy.assertAdvancedDiagnosticsAllowed()
        if let assessment = protectedAssessment(for: bottle), let title = assessment.matchedTitle {
            throw WineProcessMemoryError.protectedToolingUnavailable(
                "Memory tooling is disabled for protected multiplayer title: \(title.title)."
            )
        }
        if let assessment = scannedProtectedAssessment(for: bottle), let title = assessment.matchedTitle {
            throw WineProcessMemoryError.protectedToolingUnavailable(
                "Memory tooling is disabled for protected multiplayer title: \(title.title)."
            )
        }
    }

    public static func studioReviewBundle(for bottle: Bottle, steamAppID: String) -> VectorStudioReviewBundle {
        let artifacts = scanBottleForProtectedArtifacts(bottle.url, maxFindings: 24)
        let assessment = scannedProtectedAssessment(for: bottle, maxFindings: 24) ?? assessLaunch(
            programURL: bottle.url,
            bottle: bottle,
            activeSteamAppID: steamAppID,
            detectedArtifacts: artifacts
        )
        return VectorStudioReviewBundle(
            generatedAt: isoDateString(),
            bottleName: bottle.settings.name,
            bottlePath: bottle.url.path(percentEncoded: false),
            requestedSteamAppID: steamAppID,
            launchAssessment: assessment,
            runtimeAttestation: runtimeAttestation(),
            patchDispatchEndpoint: bottle.settings.patchDispatchEndpointURL,
            patchDispatchChannel: bottle.settings.patchDispatchChannel.rawValue,
            patchDispatchRequireSignedRules: bottle.settings.patchDispatchRequireSignedRules,
            patchDispatchLastRulesDigest: bottle.settings.patchDispatchLastAppliedRulesDigest,
            safeMultiplayerMode: bottle.settings.safeMultiplayerMode,
            trainerSupportMode: bottle.settings.trainerSupportMode,
            activeSteamAppID: bottle.settings.activeSteamAppID,
            policyStatement: """
            Vector blocks protected anti-cheat titles unless the studio/EAC approves the runtime profile.
            """
        )
    }

    public static func scanBottleForProtectedArtifacts(_ bottleURL: URL, maxFindings: Int) -> [String] {
        let root = bottleURL.appending(path: "drive_c")
        let rootPath = root.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: rootPath) else {
            return []
        }

        let markerFragments = ["arc raiders", "arcraiders"] + protectedAntiCheatMarkerFragments
        var findings: [String] = []
        var scanned = 0
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let candidate = enumerator?.nextObject() as? URL,
              findings.count < maxFindings,
              scanned < 4_000 {
            scanned += 1
            let path = normalizedPath(candidate.path(percentEncoded: false))
            if markerFragments.contains(where: { path.contains($0) }) {
                findings.append(candidate.path(percentEncoded: false))
            }
        }
        return findings
    }

    public static func runtimeAttestation() -> VectorRuntimeAttestation {
        let info = VectorWineInstaller.vectorWineInfo()
        let appBundleURL = Bundle.main.bundleURL
        let codeSignature = codeSignatureMetadata(for: appBundleURL)
        let records = [
            runtimeRecord(
                label: "bundled_wine",
                url: VectorWineInstaller.binFolder.appending(path: "wine64")
            ),
            runtimeRecord(
                label: "bundled_wineserver",
                url: VectorWineInstaller.binFolder.appending(path: "wineserver")
            ),
            runtimeRecord(label: "compatibility_wine", url: VectorWineInstaller.steamCompatibilityWineBinary()),
            runtimeRecord(
                label: "compatibility_wineserver",
                url: VectorWineInstaller.steamCompatibilityWineserverBinary()
            ),
            runtimeRecord(label: "vectorvmctl", url: VectorWineInstaller.binFolder.appending(path: "vectorvmctl")),
            runtimeRecord(
                label: "vectorvmctl_pe",
                url: VectorWineInstaller.binFolder.appending(path: "vectorvmctl.exe")
            ),
            runtimeRecord(label: "dispatch_cache", url: nil)
        ]

        return VectorRuntimeAttestation(
            schemaVersion: 2,
            generatedAt: isoDateString(),
            hostCapabilities: VectorHostSecurityCapabilityProbe.current(),
            vectorVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            wineVersion: info?.wineVersion?.description ?? "unknown",
            dxvkVersion: info?.dxvkVersion ?? "unknown",
            d3dMetalVersion: info?.d3dMetalVersion ?? "unknown",
            winetricksVersion: info?.winetricksVersion ?? "unknown",
            wineMonoVersion: info?.wineMonoVersion ?? "unknown",
            appBundleIdentifier: Bundle.main.bundleIdentifier ?? "unknown",
            appBundlePath: appBundleURL.path(percentEncoded: false),
            appCodesignIdentifier: codeSignature.identifier,
            appTeamIdentifier: codeSignature.teamIdentifier,
            appSigningAuthorities: codeSignature.authorities,
            appEntitlements: codeSignature.entitlements,
            notarizationState: codeSignature.notarizationState,
            hardenedRuntime: codeSignature.hardenedRuntime,
            runtimePatchDigest: patchsetDigest() ?? "not-probed",
            records: records
        )
    }

    private static func blockedAssessment(
        for descriptor: ProtectedTitleDescriptor,
        artifacts: [String]
    ) -> ProtectedLaunchAssessment {
        ProtectedLaunchAssessment(
            matchedTitle: descriptor,
            trustClassification: descriptor.trustClassification,
            localLaunchDisposition: descriptor.policy.localLaunchDisposition,
            detectedArtifacts: artifacts,
            reasons: [
                "\(descriptor.title) uses \(descriptor.antiCheatProvider).",
                "Vector does not bypass, disable, emulate, or weaken anti-cheat.",
                "Official studio/EAC approval is required before local online launch is allowed."
            ]
        )
    }

    private static func genericBlockedAntiCheatDescriptor(for artifacts: [String] = []) -> ProtectedTitleDescriptor {
        let provider = protectedProviderName(for: artifacts)
        return ProtectedTitleDescriptor(
            id: "generic-protected-anticheat",
            title: "Protected anti-cheat title",
            steamAppID: "",
            executableMatches: [
                "start_protected_game.exe",
                "beservice.exe",
                "beclient.exe",
                "eosanticheatservice.exe"
            ],
            pathFragments: protectedAntiCheatMarkerFragments,
            antiCheatProvider: provider,
            trustClassification: .blockedAntiCheat,
            officialSupportRequired: true,
            fallbackPlayOptions: [
                "Windows PC",
                "officially supported SteamOS/Proton device",
                "Remote Play from a supported host"
            ],
            supportContactStatus: "Unknown",
            policy: .hardLockdown
        )
    }

    private static func protectedProviderName(for artifacts: [String]) -> String {
        let normalized = artifacts.map(normalizedPath).joined(separator: " ")
        if normalized.contains("embarkgameboot") {
            return "Easy Anti-Cheat / Embark Game Boot"
        }
        if normalized.contains("easyanticheat") {
            return "Easy Anti-Cheat"
        }
        if normalized.contains("eos_anticheat")
            || normalized.contains("eosanticheat")
            || normalized.contains("start_protected_game") {
            return "EOS Anti-Cheat"
        }
        if normalized.contains("battleye")
            || normalized.contains("beservice")
            || normalized.contains("beclient")
            || normalized.contains("bedaisy") {
            return "BattlEye"
        }
        if normalized.contains("ricochet") || normalized.contains("randgrid") {
            return "Ricochet-like protected service"
        }
        if normalized.contains("vgk") || normalized.contains("vanguard") {
            return "Riot Vanguard"
        }
        return "Protected anti-cheat (EAC / BattlEye / EOS / kernel-service class)"
    }

    private static func matches(_ descriptor: ProtectedTitleDescriptor, appID: String) -> Bool {
        let normalizedAppID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        return !descriptor.steamAppID.isEmpty && descriptor.steamAppID == normalizedAppID
    }

    private static func matches(_ descriptor: ProtectedTitleDescriptor, path: String) -> Bool {
        let normalized = normalizedPath(path)
        return descriptor.executableMatches.contains { normalized.contains($0.lowercased()) }
            || descriptor.pathFragments.contains { normalized.contains($0.lowercased()) }
    }

    private static func isProtectedAntiCheatArtifact(_ artifact: String) -> Bool {
        let normalized = normalizedPath(artifact)
        return protectedAntiCheatMarkerFragments.contains { normalized.contains($0) }
    }

    private static func runtimeRecord(label: String, url: URL?) -> RuntimeAttestationRecord {
        guard let url else {
            return RuntimeAttestationRecord(label: label, path: "", sha256: nil, present: false)
        }
        let path = url.path(percentEncoded: false)
        let present = FileManager.default.fileExists(atPath: path)
        return RuntimeAttestationRecord(
            label: label,
            path: path,
            sha256: present ? sha256(url: url) : nil,
            present: present
        )
    }

    private static func sha256(url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func patchsetDigest() -> String? {
        let fileManager = FileManager.default
        var roots = [
            VectorWineInstaller.libraryFolder.appending(path: "Patchsets"),
            VectorWineInstaller.libraryFolder.appending(path: "Wine").appending(path: "patchsets")
        ]
        if let resourceURL = Bundle.main.resourceURL {
            roots.append(resourceURL.appending(path: "runtime").appending(path: "Wine").appending(path: "patchsets"))
            roots.append(resourceURL.appending(path: "Wine").appending(path: "patchsets"))
        }

        var fileURLs: [URL] = []
        for root in roots {
            guard fileManager.fileExists(atPath: root.path(percentEncoded: false)),
                  let enumerator = fileManager.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                  ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                    continue
                }
                fileURLs.append(fileURL)
            }
        }

        guard !fileURLs.isEmpty else { return nil }
        var hasher = SHA256()
        let sortedURLs = fileURLs.sorted {
            $0.path(percentEncoded: false) < $1.path(percentEncoded: false)
        }
        for fileURL in sortedURLs {
            let pathData = Data(fileURL.path(percentEncoded: false).utf8)
            guard let fileData = try? Data(contentsOf: fileURL) else { continue }
            hasher.update(data: pathData)
            hasher.update(data: fileData)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func codeSignatureMetadata(for bundleURL: URL) -> CodeSignatureMetadata {
        let path = bundleURL.path(percentEncoded: false)
        let details = runSystemTool("/usr/bin/codesign", arguments: ["-dv", "--verbose=4", path])
        let entitlementsOutput = runSystemTool("/usr/bin/codesign", arguments: ["-d", "--entitlements", ":-", path])
        let spctlOutput = runSystemTool(
            "/usr/sbin/spctl",
            arguments: ["--assess", "--type", "execute", "--verbose=4", path]
        )
        let combinedDetails = details.stdout + details.stderr
        return CodeSignatureMetadata(
            identifier: firstCodesignValue(named: "Identifier", in: combinedDetails),
            teamIdentifier: firstCodesignValue(named: "TeamIdentifier", in: combinedDetails),
            authorities: codesignAuthorities(in: combinedDetails),
            entitlements: entitlementsDictionary(from: entitlementsOutput.stdout + entitlementsOutput.stderr),
            notarizationState: notarizationState(from: spctlOutput),
            hardenedRuntime: hardenedRuntimeState(from: combinedDetails)
        )
    }

    private static func runSystemTool(_ executable: String, arguments: [String]) -> SystemToolResult {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        do {
            try process.run()
            process.waitUntilExit()
            let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return SystemToolResult(stdout: stdout, stderr: stderr, code: process.terminationStatus)
        } catch {
            return SystemToolResult(stdout: "", stderr: error.localizedDescription, code: -1)
        }
    }

    private static func firstCodesignValue(named key: String, in output: String) -> String {
        let prefix = "\(key)="
        return output
            .components(separatedBy: .newlines)
            .first(where: { $0.hasPrefix(prefix) })?
            .dropFirst(prefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
    }

    private static func codesignAuthorities(in output: String) -> [String] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line -> String? in
                guard line.hasPrefix("Authority=") else { return nil }
                return String(line.dropFirst("Authority=".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
    }

    private static func entitlementsDictionary(from output: String) -> [String: String] {
        guard let plistStart = output.range(of: "<?xml")?.lowerBound else { return [:] }
        let plistText = String(output[plistStart...])
        guard let data = plistText.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any] else {
            return [:]
        }
        return plist.reduce(into: [String: String]()) { result, pair in
            result[pair.key] = String(describing: pair.value)
        }
    }

    private static func notarizationState(from output: SystemToolResult) -> String {
        let combined = (output.stdout + output.stderr).lowercased()
        if output.code == 0, combined.contains("accepted") {
            return "accepted"
        }
        if combined.contains("rejected") {
            return "rejected"
        }
        if combined.contains("source=no usable signature") {
            return "unsigned"
        }
        return output.code == 0 ? "accepted" : "not-accepted"
    }

    private static func hardenedRuntimeState(from output: String) -> String {
        let normalized = output.lowercased()
        if normalized.contains("runtime") || normalized.contains("flags=") && normalized.contains("runtime") {
            return "enabled"
        }
        return "not-detected"
    }

    private static func normalizedPath(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "/").lowercased()
    }

    private static func isoDateString() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

// swiftlint:enable file_length type_body_length
