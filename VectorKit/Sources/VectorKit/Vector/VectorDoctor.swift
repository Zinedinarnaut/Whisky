//
//  VectorDoctor.swift
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

public enum VectorDoctor {
    public static func report(for bottle: Bottle, checkRemote: Bool = true) async -> VectorDoctorReport {
        let host = VectorHostSecurityCapabilityProbe.current()
        let runtimeAttestation = VectorProtectedTitlePolicyEngine.runtimeAttestation()
        let runtime = runtimeSnapshot()
        let dispatch = await dispatchSnapshot(for: bottle, checkRemote: checkRemote)
        let protectedAssessment = VectorProtectedTitlePolicyEngine.scannedProtectedAssessment(
            for: bottle,
            maxFindings: 24
        )
        let bridge = bridgeSnapshot(for: bottle, host: host, protectedAssessment: protectedAssessment)
        let logs = recentLogSnippets(for: bottle, maxCount: 3)
        let repairSignals = await repairSignalsForReport(
            bottle: bottle,
            runtime: runtime,
            dispatch: dispatch,
            logs: logs
        )
        let checks = checksForReport(
            CheckContext(
                bottle: bottle,
                host: host,
                runtime: runtime,
                bridge: bridge,
                dispatch: dispatch,
                repairSignals: repairSignals,
                protectedAssessment: protectedAssessment
            )
        )
        let recommendedFixes = recommendedFixes(from: repairSignals, protectedAssessment: protectedAssessment)
        let health = healthSnapshot(
            checks: checks,
            repairSignals: repairSignals,
            recommendedFixes: recommendedFixes
        )

        return VectorDoctorReport(
            schemaVersion: 2,
            generatedAt: isoDateString(),
            bottle: bottleSnapshot(for: bottle),
            health: health,
            hostCapabilities: host,
            runtimeAttestation: runtimeAttestation,
            runtime: runtime,
            memoryBridge: bridge,
            dispatch: dispatch,
            protectedLaunchAssessment: protectedAssessment,
            recentLogs: logs,
            checks: checks,
            recommendedFixes: recommendedFixes
        )
    }

    public static func encodedReport(for bottle: Bottle, checkRemote: Bool = true) async throws -> Data {
        let report = await report(for: bottle, checkRemote: checkRemote)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(report)
    }
}

private extension VectorDoctor {
    static func repairSignalsForReport(
        bottle: Bottle,
        runtime: VectorDoctorRuntimeSnapshot,
        dispatch: VectorDoctorDispatchSnapshot,
        logs: [VectorDoctorLogSnippet]
    ) async -> RepairSignals {
        let doctorSignals = await DispatchPatchService.shared.doctorSignals(
            for: bottle,
            executablePath: bottle.settings.pins.first?.url?.path(percentEncoded: false) ?? "",
            logText: logs.map(\.tail).joined(separator: "\n")
        )
        return repairSignals(
            for: bottle,
            runtime: runtime,
            dispatch: dispatch,
            logs: logs,
            remoteFixIDs: doctorSignals.flatMap(\.fixIDs)
        )
    }

    static func bottleSnapshot(for bottle: Bottle) -> VectorDoctorBottleSnapshot {
        VectorDoctorBottleSnapshot(
            name: bottle.settings.name,
            path: bottle.url.path(percentEncoded: false),
            windowsVersion: bottle.settings.windowsVersion.pretty(),
            runtimeSelection: bottle.settings.runtimeSelection.rawValue,
            graphicsBackend: bottle.settings.graphicsBackendMode.rawValue,
            inferredGraphicsBackend: bottle.settings.inferredGraphicsBackendMode?.rawValue ?? "",
            patchDispatchEnabled: bottle.settings.patchDispatchEnabled,
            patchDispatchEndpoint: bottle.settings.patchDispatchEndpointURL,
            patchDispatchChannel: bottle.settings.patchDispatchChannel.rawValue,
            requireSignedPatchRules: bottle.settings.patchDispatchRequireSignedRules,
            safeMultiplayerMode: bottle.settings.safeMultiplayerMode,
            trainerSupportMode: bottle.settings.trainerSupportMode,
            activeSteamAppID: bottle.settings.activeSteamAppID,
            logProfile: bottle.settings.logProfile.rawValue
        )
    }

    static func runtimeSnapshot() -> VectorDoctorRuntimeSnapshot {
        let info = VectorWineInstaller.vectorWineInfo()
        let bundledWine = VectorWineInstaller.binFolder.appending(path: "wine64")
        let bundledWineserver = VectorWineInstaller.binFolder.appending(path: "wineserver")
        let compatibilityWine = VectorWineInstaller.steamCompatibilityWineBinary()
        let compatibilityWineserver = VectorWineInstaller.steamCompatibilityWineserverBinary()

        return VectorDoctorRuntimeSnapshot(
            vectorRuntimeInstalled: VectorWineInstaller.isVectorWineInstalled(),
            installedVectorWineVersion: info?.version.description ?? "unknown",
            installedWineVersion: info?.wineVersion?.description ?? "unknown",
            bundledWinePath: bundledWine.path(percentEncoded: false),
            bundledWinePresent: isExecutable(bundledWine),
            bundledWineserverPath: bundledWineserver.path(percentEncoded: false),
            bundledWineserverPresent: isExecutable(bundledWineserver),
            compatibilityWinePath: compatibilityWine?.path(percentEncoded: false) ?? "",
            compatibilityWinePresent: compatibilityWine.map(isExecutable) ?? false,
            compatibilityWineserverPath: compatibilityWineserver?.path(percentEncoded: false) ?? "",
            compatibilityWineserverPresent: compatibilityWineserver.map(isExecutable) ?? false,
            installHealth: runtimeInstallHealth()
        )
    }

    static func bridgeSnapshot(
        for bottle: Bottle,
        host: VectorHostSecurityCapabilityReport,
        protectedAssessment: ProtectedLaunchAssessment?
    ) -> VectorDoctorBridgeSnapshot {
        let protectedBlocked = protectedAssessment?.shouldBlockLocalLaunch ?? false
        guard VectorDeveloperToolPolicy.developerToolsEnabled else {
            return lockedBridgeSnapshot(
                host: host,
                protectedBlocked: protectedBlocked,
                message: "Developer Mode is off."
            )
        }
        guard host.advancedDiagnosticsUnlocked else {
            return lockedBridgeSnapshot(
                host: host,
                protectedBlocked: protectedBlocked,
                message: "Advanced diagnostics require Reduced Security plus Developer Mode."
            )
        }
        guard !protectedBlocked else {
            return lockedBridgeSnapshot(
                host: host,
                protectedBlocked: true,
                message: "Protected multiplayer policy blocks memory tooling."
            )
        }

        do {
            let status = try WineProcessMemoryService(bottle: bottle).transportStatus()
            return VectorDoctorBridgeSnapshot(
                developerModeEnabled: true,
                advancedDiagnosticsUnlocked: host.advancedDiagnosticsUnlocked,
                protectedToolingBlocked: false,
                requestedTransport: status.requested.rawValue,
                effectiveTransport: status.effective.rawValue,
                bridgeAvailable: status.bridgeAvailable,
                debuggerAvailable: status.debuggerAvailable,
                message: "Memory bridge probe completed."
            )
        } catch {
            return lockedBridgeSnapshot(
                host: host,
                protectedBlocked: protectedBlocked,
                message: error.localizedDescription
            )
        }
    }

    static func lockedBridgeSnapshot(
        host: VectorHostSecurityCapabilityReport,
        protectedBlocked: Bool,
        message: String
    ) -> VectorDoctorBridgeSnapshot {
        VectorDoctorBridgeSnapshot(
            developerModeEnabled: VectorDeveloperToolPolicy.developerToolsEnabled,
            advancedDiagnosticsUnlocked: host.advancedDiagnosticsUnlocked,
            protectedToolingBlocked: protectedBlocked,
            requestedTransport: WineProcessMemoryTransport.auto.rawValue,
            effectiveTransport: "locked",
            bridgeAvailable: false,
            debuggerAvailable: false,
            message: message
        )
    }

    static func dispatchSnapshot(for bottle: Bottle, checkRemote: Bool) async -> VectorDoctorDispatchSnapshot {
        let status = await DispatchPatchService.shared.status(for: bottle, checkRemote: checkRemote)
        let message: String
        if !status.dispatchEnabled {
            message = "Patch dispatch is disabled for this bottle."
        } else if status.effectiveRuleCount == 0 {
            message = "Patch dispatch is reachable or cached, but no effective rules matched."
        } else if status.updateAvailable {
            message = "Patch updates are available."
        } else {
            message = "Patch dispatch is current."
        }
        return VectorDoctorDispatchSnapshot(
            enabled: status.dispatchEnabled,
            endpointURL: status.endpointURL,
            channel: status.channel.rawValue,
            requireSignedRules: bottle.settings.patchDispatchRequireSignedRules,
            remoteVersion: status.remoteVersion,
            remoteRuleCount: status.remoteRuleCount,
            effectiveRuleCount: status.effectiveRuleCount,
            updateAvailable: status.updateAvailable,
            effectiveRulesDigest: status.effectiveRulesDigest,
            recommendedBackend: status.recommendedBackend?.rawValue ?? "",
            fallbackBackend: status.fallbackBackend?.rawValue ?? "",
            message: message
        )
    }

    static func recentLogSnippets(for bottle: Bottle, maxCount: Int) -> [VectorDoctorLogSnippet] {
        let bottlePath = bottle.url.path(percentEncoded: false)
        let logFiles = sortedLogFiles().prefix(25)
        var snippets: [VectorDoctorLogSnippet] = []

        for logURL in logFiles {
            guard let content = try? String(contentsOf: logURL, encoding: .utf8),
                  content.contains("Bottle URL: \(bottlePath)")
                    || content.contains("Bottle Name: \(bottle.settings.name)") else {
                continue
            }
            snippets.append(logSnippet(url: logURL, content: content))
            if snippets.count >= maxCount {
                break
            }
        }
        return snippets
    }
}

private extension VectorDoctor {
    static func runtimeInstallHealth() -> [String: String] {
        let url = VectorWineInstaller.libraryFolder.appending(path: "VectorRuntimeInstallHealth.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object.reduce(into: [String: String]()) { result, pair in
            result[pair.key] = String(describing: pair.value)
        }
    }

    static func sortedLogFiles() -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: Wine.logsFolder,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return files.filter { $0.pathExtension == "log" }.sorted {
            creationDate($0) > creationDate($1)
        }
    }

    static func logSnippet(url: URL, content: String) -> VectorDoctorLogSnippet {
        VectorDoctorLogSnippet(
            name: url.lastPathComponent,
            path: url.path(percentEncoded: false),
            createdAt: ISO8601DateFormatter().string(from: creationDate(url)),
            tail: tail(content, maxLines: 80)
        )
    }

    static func tail(_ content: String, maxLines: Int) -> String {
        content.components(separatedBy: .newlines).suffix(maxLines).joined(separator: "\n")
    }

    static func creationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }

    static func isExecutable(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path(percentEncoded: false))
    }

    static func isoDateString() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    static func healthSnapshot(
        checks: [VectorDoctorCheck],
        repairSignals: RepairSignals,
        recommendedFixes: [VectorDoctorFixSuggestion]
    ) -> VectorDoctorHealthSnapshot {
        var score = 100
        var risks: [String] = []

        for check in checks {
            switch check.status {
            case .pass:
                continue
            case .info:
                score -= 3
            case .warning:
                score -= 12
                risks.append("\(check.title): \(check.detail)")
            case .blocked:
                score -= 35
                risks.append("\(check.title): \(check.detail)")
            case .failed:
                score -= 28
                risks.append("\(check.title): \(check.detail)")
            }
        }

        if repairSignals.needsMediaRepair {
            score -= 6
        }
        if repairSignals.needsLauncherDependencyRepair {
            score -= 6
        }
        if repairSignals.needsRuntimeRepair {
            score -= 10
        }
        if repairSignals.needsWineserverReset {
            score -= 12
        }

        let clampedScore = min(100, max(0, score))
        return VectorDoctorHealthSnapshot(
            score: clampedScore,
            grade: healthGrade(for: clampedScore),
            summary: healthSummary(for: clampedScore, recommendedFixes: recommendedFixes),
            risks: Array(risks.uniqued().prefix(6)),
            repairCount: recommendedFixes.count
        )
    }

    static func healthGrade(for score: Int) -> String {
        switch score {
        case 90...100:
            return "Excellent"
        case 75..<90:
            return "Good"
        case 55..<75:
            return "Needs attention"
        default:
            return "Repair recommended"
        }
    }

    static func healthSummary(
        for score: Int,
        recommendedFixes: [VectorDoctorFixSuggestion]
    ) -> String {
        guard !recommendedFixes.isEmpty else {
            return score >= 75
                ? "Bottle looks healthy. No one-click repairs are recommended."
                : "Bottle has risk signals, but no safe automated repair was identified."
        }
        let actions = recommendedFixes.map(\.actionTitle).joined(separator: ", ")
        return "Recommended repair path: \(actions)."
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
