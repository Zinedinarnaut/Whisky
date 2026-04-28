//
//  VectorDoctorReport.swift
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

public enum VectorDoctorCheckStatus: String, Codable, Sendable {
    case pass
    case info
    case warning
    case blocked
    case failed
}

public enum VectorDoctorFixID: String, Codable, CaseIterable, Sendable, Identifiable {
    case repairRuntime
    case killMismatchedWineserver
    case reapplyVecPatch
    case repairMediaPlayback
    case repairLauncherDependencies
    case exportDiagnosticBundle

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .repairRuntime:
            return "runtime repair"
        case .killMismatchedWineserver:
            return "wineserver reset"
        case .reapplyVecPatch:
            return "VecPatch sync"
        case .repairMediaPlayback:
            return "media repair"
        case .repairLauncherDependencies:
            return "launcher dependency repair"
        case .exportDiagnosticBundle:
            return "diagnostic export"
        }
    }
}

public struct VectorDoctorFixSuggestion: Codable, Identifiable, Sendable {
    public var id: VectorDoctorFixID
    public var title: String
    public var detail: String
    public var actionTitle: String
}

public struct VectorDoctorCheck: Codable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var status: VectorDoctorCheckStatus
    public var detail: String
    public var metadata: [String: String]
}

public struct VectorDoctorBottleSnapshot: Codable, Sendable {
    public var name: String
    public var path: String
    public var windowsVersion: String
    public var runtimeSelection: String
    public var graphicsBackend: String
    public var inferredGraphicsBackend: String
    public var patchDispatchEnabled: Bool
    public var patchDispatchEndpoint: String
    public var patchDispatchChannel: String
    public var requireSignedPatchRules: Bool
    public var safeMultiplayerMode: Bool
    public var trainerSupportMode: Bool
    public var activeSteamAppID: String
    public var logProfile: String
}

public struct VectorDoctorRuntimeSnapshot: Codable, Sendable {
    public var vectorRuntimeInstalled: Bool
    public var installedVectorWineVersion: String
    public var installedWineVersion: String
    public var bundledWinePath: String
    public var bundledWinePresent: Bool
    public var bundledWineserverPath: String
    public var bundledWineserverPresent: Bool
    public var compatibilityWinePath: String
    public var compatibilityWinePresent: Bool
    public var compatibilityWineserverPath: String
    public var compatibilityWineserverPresent: Bool
    public var installHealth: [String: String]
}

public struct VectorDoctorBridgeSnapshot: Codable, Sendable {
    public var developerModeEnabled: Bool
    public var advancedDiagnosticsUnlocked: Bool
    public var protectedToolingBlocked: Bool
    public var requestedTransport: String
    public var effectiveTransport: String
    public var bridgeAvailable: Bool
    public var debuggerAvailable: Bool
    public var message: String
}

public struct VectorDoctorDispatchSnapshot: Codable, Sendable {
    public var enabled: Bool
    public var endpointURL: String
    public var channel: String
    public var requireSignedRules: Bool
    public var remoteVersion: Int
    public var remoteRuleCount: Int
    public var effectiveRuleCount: Int
    public var updateAvailable: Bool
    public var effectiveRulesDigest: String
    public var recommendedBackend: String
    public var fallbackBackend: String
    public var message: String
}

public struct VectorDoctorLogSnippet: Codable, Identifiable, Sendable {
    public var id: String { path }
    public var name: String
    public var path: String
    public var createdAt: String
    public var tail: String
}

public struct VectorDoctorHealthSnapshot: Codable, Sendable {
    public var score: Int
    public var grade: String
    public var summary: String
    public var risks: [String]
    public var repairCount: Int
}

public struct VectorDoctorReport: Codable, Sendable {
    public var schemaVersion: Int
    public var generatedAt: String
    public var bottle: VectorDoctorBottleSnapshot
    public var health: VectorDoctorHealthSnapshot
    public var hostCapabilities: VectorHostSecurityCapabilityReport
    public var runtimeAttestation: VectorRuntimeAttestation
    public var runtime: VectorDoctorRuntimeSnapshot
    public var memoryBridge: VectorDoctorBridgeSnapshot
    public var dispatch: VectorDoctorDispatchSnapshot
    public var protectedLaunchAssessment: ProtectedLaunchAssessment?
    public var recentLogs: [VectorDoctorLogSnippet]
    public var checks: [VectorDoctorCheck]
    public var recommendedFixes: [VectorDoctorFixSuggestion]
}
