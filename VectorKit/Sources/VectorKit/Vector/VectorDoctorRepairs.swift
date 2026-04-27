//
//  VectorDoctorRepairs.swift
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
    struct RepairSignals {
        var needsRuntimeRepair: Bool
        var needsWineserverReset: Bool
        var needsPatchSync: Bool
        var needsMediaRepair: Bool
        var needsLauncherDependencyRepair: Bool
        var remoteFixIDs: [VectorDoctorFixID]
        var mediaDetails: String
        var launcherDetails: String
    }

    static func repairSignals(
        for bottle: Bottle,
        runtime: VectorDoctorRuntimeSnapshot,
        dispatch: VectorDoctorDispatchSnapshot,
        logs: [VectorDoctorLogSnippet],
        remoteFixIDs: [String] = []
    ) -> RepairSignals {
        let logText = logs.map(\.tail).joined(separator: "\n").lowercased()
        let missingMediaDLLs = missingDLLs(mediaPlaybackDLLs, in: bottle)
        let hasMediaLogFault = containsAny(mediaFaultNeedles, in: logText)
        let hasLauncherFault = containsAny(launcherFaultNeedles, in: logText)
        let hasWineserverMismatch = containsAny(wineserverFaultNeedles, in: logText)
        let normalizedRemoteFixIDs = remoteFixIDs.compactMap(VectorDoctorFixID.init(rawValue:))

        return RepairSignals(
            needsRuntimeRepair: !runtime.bundledWinePresent || !runtime.bundledWineserverPresent,
            needsWineserverReset: hasWineserverMismatch,
            needsPatchSync: dispatch.updateAvailable,
            needsMediaRepair: hasMediaLogFault || !missingMediaDLLs.isEmpty,
            needsLauncherDependencyRepair: hasLauncherFault,
            remoteFixIDs: normalizedRemoteFixIDs,
            mediaDetails: mediaDetails(missingDLLs: missingMediaDLLs),
            launcherDetails: launcherDetails(hasFault: hasLauncherFault)
        )
    }

    static func recommendedFixes(
        from signals: RepairSignals,
        protectedAssessment: ProtectedLaunchAssessment?
    ) -> [VectorDoctorFixSuggestion] {
        var fixes: [VectorDoctorFixSuggestion] = []

        appendFix(.repairRuntime, to: &fixes, when: signals.needsRuntimeRepair)
        appendFix(.killMismatchedWineserver, to: &fixes, when: signals.needsWineserverReset)
        appendFix(.reapplyVecPatch, to: &fixes, when: signals.needsPatchSync)
        appendFix(.repairMediaPlayback, to: &fixes, when: signals.needsMediaRepair)
        appendFix(
            .repairLauncherDependencies,
            to: &fixes,
            when: signals.needsLauncherDependencyRepair && protectedAssessment?.shouldBlockLocalLaunch != true
        )
        let protectedLaunchBlocked = protectedAssessment?.shouldBlockLocalLaunch == true
        for remoteFixID in signals.remoteFixIDs {
            if remoteFixID == .repairLauncherDependencies && protectedLaunchBlocked {
                continue
            }
            appendFix(remoteFixID, to: &fixes, when: true)
        }
        appendFix(.exportDiagnosticBundle, to: &fixes, when: true)

        return fixes
    }
}

private extension VectorDoctor {
    static let mediaPlaybackDLLs = [
        "mf.dll",
        "mfplat.dll",
        "mfreadwrite.dll",
        "quartz.dll",
        "devenum.dll",
        "winegstreamer.dll"
    ]

    static let mediaFaultNeedles = [
        "mfplat.dll",
        "mfreadwrite.dll",
        "winegstreamer",
        "wmvcore.dll",
        "quartz.dll",
        "failed to initialize video",
        "failed to play video",
        "video playback"
    ]

    static let launcherFaultNeedles = [
        "mscoree.dll",
        "vcruntime",
        "msvcp",
        "webview",
        "edgewebview",
        "you have reached a page that is not normally shown",
        "microsoft will never ask you to copy or share this url"
    ]

    static let wineserverFaultNeedles = [
        "version mismatch",
        "wrong wineserver is still running"
    ]

    static func appendFix(
        _ id: VectorDoctorFixID,
        to fixes: inout [VectorDoctorFixSuggestion],
        when condition: Bool
    ) {
        guard condition, !fixes.contains(where: { $0.id == id }) else {
            return
        }
        fixes.append(fixSuggestion(for: id))
    }

    static func fixSuggestion(for id: VectorDoctorFixID) -> VectorDoctorFixSuggestion {
        switch id {
        case .repairRuntime:
            return VectorDoctorFixSuggestion(
                id: id,
                title: "Runtime repair",
                detail: "Validate and repair the bottle's mirrored Wine runtime DLLs.",
                actionTitle: "Repair Runtime"
            )
        case .killMismatchedWineserver:
            return VectorDoctorFixSuggestion(
                id: id,
                title: "Wineserver reset",
                detail: "Terminate stale wineserver processes so the next launch uses one matched runtime pair.",
                actionTitle: "Kill Wineserver"
            )
        case .reapplyVecPatch:
            return VectorDoctorFixSuggestion(
                id: id,
                title: "VecPatch update",
                detail: "Fetch current patch rules and re-merge dispatch profiles without duplicating profiles.",
                actionTitle: "Reapply VecPatch"
            )
        case .repairMediaPlayback:
            return VectorDoctorFixSuggestion(
                id: id,
                title: "Media playback repair",
                detail: "Repair Media Foundation/Quartz playback components used by intros and cutscenes.",
                actionTitle: "Repair Media"
            )
        case .repairLauncherDependencies:
            return VectorDoctorFixSuggestion(
                id: id,
                title: "Launcher dependency repair",
                detail: "Install or repair WebView2, .NET, Visual C++ runtimes, and core fonts.",
                actionTitle: "Repair Launchers"
            )
        case .exportDiagnosticBundle:
            return VectorDoctorFixSuggestion(
                id: id,
                title: "Diagnostic export",
                detail: "Create a zipped report with Doctor JSON, logs, bottle settings, host state, and hashes.",
                actionTitle: "Export Bundle"
            )
        }
    }

    static func mediaDetails(missingDLLs: [String]) -> String {
        if missingDLLs.isEmpty {
            return "Recent logs indicate media playback faults."
        }
        return "Missing or drifted media DLLs: \(missingDLLs.prefix(5).joined(separator: ", "))."
    }

    static func launcherDetails(hasFault: Bool) -> String {
        hasFault
            ? "Recent logs indicate launcher, auth, .NET, WebView2, or Visual C++ dependency faults."
            : "Launcher dependencies look healthy."
    }

    static func containsAny(_ needles: [String], in haystack: String) -> Bool {
        needles.contains { haystack.contains($0.lowercased()) }
    }

    static func missingDLLs(_ dllNames: [String], in bottle: Bottle) -> [String] {
        let windowsDirectory = bottle.url.appending(path: "drive_c").appending(path: "windows")
        return dllNames.filter { dllName in
            let system32 = windowsDirectory.appending(path: "system32").appending(path: dllName)
            let syswow64 = windowsDirectory.appending(path: "syswow64").appending(path: dllName)
            return !FileManager.default.fileExists(atPath: system32.path(percentEncoded: false))
                && !FileManager.default.fileExists(atPath: syswow64.path(percentEncoded: false))
        }
    }
}
