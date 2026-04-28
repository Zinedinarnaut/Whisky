//
//  VectorLaunchDoctor.swift
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

public enum VectorLaunchDoctorFindingSeverity: String, Codable, Sendable {
    case info
    case warning
    case blocked
}

public enum VectorLaunchDoctorFailureClass: String, Codable, Sendable {
    case dxFeatureLevel
    case dx12Unsupported
    case wineserverMismatch
    case missingRuntimeDependency
    case webViewAuth
    case mediaPlayback
    case protectedAntiCheat
    case steamBootstrap
    case unknown
}

public struct VectorLaunchDoctorFinding: Codable, Identifiable, Sendable {
    public var id: String
    public var severity: VectorLaunchDoctorFindingSeverity
    public var title: String
    public var detail: String
    public var failureClass: VectorLaunchDoctorFailureClass?
}

public struct VectorLaunchDoctorTrace: Codable, Sendable {
    public var schemaVersion: Int
    public var generatedAt: String
    public var programPath: String
    public var activeSteamAppID: String
    public var graphicsBackend: String
    public var inferredGraphicsBackend: String
    public var patchDigest: String
    public var findings: [VectorLaunchDoctorFinding]
}

public enum VectorLaunchDoctor {
    private static let traceFilename = ".vector-launch-doctor.json"
    private static let minecraftDungeonsSteamAppID = "1672970"
    private static let contentWarningSteamAppID = "2881650"
    private static let forzaHorizon6SteamAppID = "2483190"

    @discardableResult
    public static func prepareForLaunch(programURL: URL, bottle: Bottle) async -> [VectorLaunchDoctorFinding] {
        var findings: [VectorLaunchDoctorFinding] = []
        let programPath = programURL.path(percentEncoded: false)
        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)

        findings += await applyPatchUpdatesIfNeeded(for: bottle)
        findings += await applyKnownLaunchGuardrails(
            programPath: programPath,
            activeSteamAppID: activeSteamAppID,
            bottle: bottle
        )
        appendProtectedLaunchFinding(programURL: programURL, bottle: bottle, findings: &findings)
        findings += recentLogClassifications(for: bottle)
        writeTrace(programPath: programPath, bottle: bottle, findings: findings)

        return findings
    }
}

private extension VectorLaunchDoctor {
    enum KnownLaunchMatch: Equatable {
        case minecraftDungeons
        case contentWarning
        case forzaHorizon6
    }

    static func applyPatchUpdatesIfNeeded(for bottle: Bottle) async -> [VectorLaunchDoctorFinding] {
        guard bottle.settings.patchDispatchEnabled else {
            return []
        }

        let status = await DispatchPatchService.shared.status(for: bottle, checkRemote: false)
        guard status.updateAvailable else {
            return []
        }

        await BottleGamingModeManager.syncDispatchProfiles(for: bottle, forceRefresh: false)
        return [
            finding(
                id: "vecpatch-sync",
                severity: .info,
                title: "VecPatch synced",
                detail: "Updated launch profiles before starting the game.",
                failureClass: .unknown
            )
        ]
    }

    static func applyKnownLaunchGuardrails(
        programPath: String,
        activeSteamAppID: String,
        bottle: Bottle
    ) async -> [VectorLaunchDoctorFinding] {
        guard let match = knownLaunchMatch(programPath: programPath, activeSteamAppID: activeSteamAppID) else {
            return []
        }

        await MainActor.run {
            if bottle.settings.gamingAutoApplyKnownGamePatches {
                BottleGamingModeManager.ensureKnownGameProfiles(in: bottle)
            }
            if match == .minecraftDungeons || match == .contentWarning {
                bottle.settings.mediaPlaybackCompatibilityMode = true
            }
            if match == .forzaHorizon6, bottle.settings.graphicsBackendMode == .auto {
                bottle.settings.inferredGraphicsBackendMode = .d3dMetal
                bottle.settings.inferredFallbackGraphicsBackendMode = .dxvk
            }
        }

        return knownLaunchFinding(for: match)
    }

    static func knownLaunchMatch(programPath: String, activeSteamAppID: String) -> KnownLaunchMatch? {
        let normalizedPath = programPath.lowercased()
        if activeSteamAppID == minecraftDungeonsSteamAppID
            || normalizedPath.contains("dungeons-win64-shipping.exe")
            || normalizedPath.contains("minecraftdungeons.exe") {
            return .minecraftDungeons
        }
        if activeSteamAppID == contentWarningSteamAppID || normalizedPath.contains("content warning.exe") {
            return .contentWarning
        }
        if activeSteamAppID == forzaHorizon6SteamAppID || normalizedPath.contains("forzahorizon6.exe") {
            return .forzaHorizon6
        }
        return nil
    }

    static func knownLaunchFinding(for match: KnownLaunchMatch) -> [VectorLaunchDoctorFinding] {
        switch match {
        case .minecraftDungeons:
            return [
                finding(
                    id: "minecraft-dungeons-guardrails",
                    severity: .info,
                    title: "Minecraft Dungeons guardrails",
                    detail: "Ensured Steam/auth/media profiles are present before launch.",
                    failureClass: .webViewAuth
                )
            ]
        case .contentWarning:
            return [
                finding(
                    id: "content-warning-guardrails",
                    severity: .info,
                    title: "Content Warning guardrails",
                    detail: "Ensured D3D11/media compatibility settings are active before launch.",
                    failureClass: .mediaPlayback
                )
            ]
        case .forzaHorizon6:
            return [
                finding(
                    id: "forza-horizon-6-preflight",
                    severity: .warning,
                    title: "Forza Horizon 6 preflight",
                    detail: "Prepared D3DMetal-first DX12 routing; release-build support may still vary.",
                    failureClass: .dx12Unsupported
                )
            ]
        }
    }

    static func appendProtectedLaunchFinding(
        programURL: URL,
        bottle: Bottle,
        findings: inout [VectorLaunchDoctorFinding]
    ) {
        let artifacts = VectorProtectedTitlePolicyEngine.scanBottleForProtectedArtifacts(bottle.url, maxFindings: 12)
        let assessment = VectorProtectedTitlePolicyEngine.assessLaunch(
            programURL: programURL,
            bottle: bottle,
            activeSteamAppID: bottle.settings.activeSteamAppID,
            detectedArtifacts: artifacts
        )
        guard assessment.shouldBlockLocalLaunch else {
            return
        }

        findings.append(
            finding(
                id: "protected-multiplayer-block",
                severity: .blocked,
                title: "Protected multiplayer blocked",
                detail: assessment.reasons.joined(separator: " "),
                failureClass: .protectedAntiCheat
            )
        )
    }

    static func writeTrace(
        programPath: String,
        bottle: Bottle,
        findings: [VectorLaunchDoctorFinding]
    ) {
        let trace = VectorLaunchDoctorTrace(
            schemaVersion: 2,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            programPath: programPath,
            activeSteamAppID: bottle.settings.activeSteamAppID,
            graphicsBackend: bottle.settings.graphicsBackendMode.rawValue,
            inferredGraphicsBackend: bottle.settings.inferredGraphicsBackendMode?.rawValue ?? "",
            patchDigest: bottle.settings.patchDispatchLastAppliedRulesDigest,
            findings: findings
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        do {
            let data = try encoder.encode(trace)
            try data.write(to: bottle.url.appending(path: traceFilename), options: .atomic)
        } catch {
            Logger.wineKit.warning(
                "Failed to write Vector Launch Doctor trace for \(bottle.settings.name, privacy: .public)"
            )
        }
    }

    static func finding(
        id: String,
        severity: VectorLaunchDoctorFindingSeverity,
        title: String,
        detail: String,
        failureClass: VectorLaunchDoctorFailureClass? = nil
    ) -> VectorLaunchDoctorFinding {
        VectorLaunchDoctorFinding(
            id: id,
            severity: severity,
            title: title,
            detail: detail,
            failureClass: failureClass
        )
    }
}
