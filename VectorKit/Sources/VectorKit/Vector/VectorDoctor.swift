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
        let checks = checksForReport(
            host: host,
            runtime: runtime,
            bridge: bridge,
            dispatch: dispatch,
            protectedAssessment: protectedAssessment
        )

        return VectorDoctorReport(
            schemaVersion: 1,
            generatedAt: isoDateString(),
            bottle: bottleSnapshot(for: bottle),
            hostCapabilities: host,
            runtimeAttestation: runtimeAttestation,
            runtime: runtime,
            memoryBridge: bridge,
            dispatch: dispatch,
            protectedLaunchAssessment: protectedAssessment,
            recentLogs: logs,
            checks: checks
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
    static func checksForReport(
        host: VectorHostSecurityCapabilityReport,
        runtime: VectorDoctorRuntimeSnapshot,
        bridge: VectorDoctorBridgeSnapshot,
        dispatch: VectorDoctorDispatchSnapshot,
        protectedAssessment: ProtectedLaunchAssessment?
    ) -> [VectorDoctorCheck] {
        [
            hostCheck(host),
            runtimeCheck(runtime),
            bridgeCheck(bridge),
            dispatchCheck(dispatch),
            protectedCheck(protectedAssessment)
        ]
    }

    static func hostCheck(_ host: VectorHostSecurityCapabilityReport) -> VectorDoctorCheck {
        let status: VectorDoctorCheckStatus = host.securityMode == .unknown ? .warning : .pass
        return check(
            id: "host",
            title: "Host security",
            status: status,
            detail: host.compactSummary,
            metadata: ["metal": host.metalDeviceName, "rosetta": String(host.rosettaInstalled)]
        )
    }

    static func runtimeCheck(_ runtime: VectorDoctorRuntimeSnapshot) -> VectorDoctorCheck {
        let runtimeReady = runtime.bundledWinePresent && runtime.bundledWineserverPresent
        return check(
            id: "runtime",
            title: "Wine runtime",
            status: runtimeReady ? .pass : .failed,
            detail: runtimeReady ? "Bundled runtime pair is present." : "Bundled wine/wineserver pair is incomplete.",
            metadata: ["wineVersion": runtime.installedWineVersion]
        )
    }

    static func bridgeCheck(_ bridge: VectorDoctorBridgeSnapshot) -> VectorDoctorCheck {
        let status: VectorDoctorCheckStatus
        if bridge.protectedToolingBlocked {
            status = .blocked
        } else if bridge.bridgeAvailable {
            status = .pass
        } else if bridge.advancedDiagnosticsUnlocked {
            status = .warning
        } else {
            status = .info
        }
        return check(id: "memory_bridge", title: "Memory bridge", status: status, detail: bridge.message)
    }

    static func dispatchCheck(_ dispatch: VectorDoctorDispatchSnapshot) -> VectorDoctorCheck {
        let status: VectorDoctorCheckStatus
        if !dispatch.enabled {
            status = .info
        } else if dispatch.updateAvailable {
            status = .warning
        } else {
            status = .pass
        }
        return check(id: "vecpatch", title: "VecPatch", status: status, detail: dispatch.message)
    }

    static func protectedCheck(_ assessment: ProtectedLaunchAssessment?) -> VectorDoctorCheck {
        guard let assessment else {
            return check(
                id: "protected_scan",
                title: "Protected title scan",
                status: .pass,
                detail: "No protected anti-cheat markers detected."
            )
        }
        return check(
            id: "protected_scan",
            title: "Protected title scan",
            status: assessment.shouldBlockLocalLaunch ? .blocked : .warning,
            detail: assessment.reasons.joined(separator: " ")
        )
    }
}

private extension VectorDoctor {
    static func check(
        id: String,
        title: String,
        status: VectorDoctorCheckStatus,
        detail: String,
        metadata: [String: String] = [:]
    ) -> VectorDoctorCheck {
        VectorDoctorCheck(id: id, title: title, status: status, detail: detail, metadata: metadata)
    }

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
}
