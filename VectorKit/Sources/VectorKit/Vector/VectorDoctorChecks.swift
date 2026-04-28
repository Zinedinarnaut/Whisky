//
//  VectorDoctorChecks.swift
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

extension VectorDoctor {
    struct CheckContext {
        var bottle: Bottle
        var host: VectorHostSecurityCapabilityReport
        var runtime: VectorDoctorRuntimeSnapshot
        var bridge: VectorDoctorBridgeSnapshot
        var dispatch: VectorDoctorDispatchSnapshot
        var repairSignals: RepairSignals
        var protectedAssessment: ProtectedLaunchAssessment?
    }

    static func checksForReport(_ context: CheckContext) -> [VectorDoctorCheck] {
        [
            hostCheck(context.host),
            bottleStorageCheck(context.bottle),
            registryCheck(context.bottle),
            runtimeCheck(context.runtime),
            bridgeCheck(context.bridge),
            dispatchCheck(context.dispatch),
            mediaCheck(bottle: context.bottle, repairSignals: context.repairSignals),
            launcherDependenciesCheck(context.repairSignals),
            protectedCheck(context.protectedAssessment)
        ]
    }
}

private extension VectorDoctor {
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

    static func bottleStorageCheck(_ bottle: Bottle) -> VectorDoctorCheck {
        let bottlePath = bottle.url.path(percentEncoded: false)
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: bottlePath, isDirectory: &isDirectory), isDirectory.boolValue else {
            return check(
                id: "bottle_storage",
                title: "Bottle storage",
                status: .failed,
                detail: "Bottle folder is missing or no longer reachable.",
                metadata: ["path": bottlePath]
            )
        }

        let isWritable = fileManager.isWritableFile(atPath: bottlePath)
        let values = try? bottle.url.resourceValues(
            forKeys: [.volumeNameKey, .volumeIsInternalKey, .volumeAvailableCapacityForImportantUsageKey]
        )
        let freeBytes = values?.volumeAvailableCapacityForImportantUsage ?? 0
        let freeSpace = freeBytes > 0 ? ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file) : ""
        let volumeKind = values?.volumeIsInternal == false ? "external" : "local"

        if !isWritable {
            return check(
                id: "bottle_storage",
                title: "Bottle storage",
                status: .failed,
                detail: "Bottle folder is reachable but not writable.",
                metadata: ["path": bottlePath, "volume": values?.volumeName ?? ""]
            )
        }

        let status: VectorDoctorCheckStatus = freeBytes > 0 && freeBytes < 10_000_000_000 ? .warning : .pass
        let detail = freeSpace.isEmpty
            ? "Bottle folder is writable on \(volumeKind) storage."
            : "Bottle folder is writable on \(volumeKind) storage with \(freeSpace) available."
        return check(
            id: "bottle_storage",
            title: "Bottle storage",
            status: status,
            detail: detail,
            metadata: ["path": bottlePath, "volume": values?.volumeName ?? "", "freeBytes": "\(freeBytes)"]
        )
    }

    static func registryCheck(_ bottle: Bottle) -> VectorDoctorCheck {
        let registryFiles = ["system.reg", "user.reg", "userdef.reg"]
        let missing = registryFiles.filter { file in
            let url = bottle.url.appending(path: file)
            return !FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
        }

        guard missing.isEmpty else {
            return check(
                id: "registry",
                title: "Registry files",
                status: .failed,
                detail: "Missing registry hive files: \(missing.joined(separator: ", ")).",
                metadata: ["missing": missing.joined(separator: ",")]
            )
        }

        return check(
            id: "registry",
            title: "Registry files",
            status: .pass,
            detail: "Required registry hive files are present."
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

    static func mediaCheck(bottle: Bottle, repairSignals: RepairSignals) -> VectorDoctorCheck {
        if repairSignals.needsMediaRepair {
            return check(
                id: "media_playback",
                title: "Media playback",
                status: .warning,
                detail: repairSignals.mediaDetails
            )
        }

        return check(
            id: "media_playback",
            title: "Media playback",
            status: bottle.settings.mediaPlaybackCompatibilityMode ? .pass : .info,
            detail: bottle.settings.mediaPlaybackCompatibilityMode
                ? "Media playback compatibility mode is enabled."
                : "No media playback faults detected in recent logs."
        )
    }

    static func launcherDependenciesCheck(_ repairSignals: RepairSignals) -> VectorDoctorCheck {
        if repairSignals.needsLauncherDependencyRepair {
            return check(
                id: "launcher_dependencies",
                title: "Launcher dependencies",
                status: .warning,
                detail: repairSignals.launcherDetails
            )
        }

        return check(
            id: "launcher_dependencies",
            title: "Launcher dependencies",
            status: .pass,
            detail: "No .NET, Visual C++, or WebView auth dependency faults detected in recent logs."
        )
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

    static func check(
        id: String,
        title: String,
        status: VectorDoctorCheckStatus,
        detail: String,
        metadata: [String: String] = [:]
    ) -> VectorDoctorCheck {
        VectorDoctorCheck(id: id, title: title, status: status, detail: detail, metadata: metadata)
    }
}
