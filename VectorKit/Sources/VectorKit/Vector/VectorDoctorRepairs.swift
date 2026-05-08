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

// swiftlint:disable file_length

extension VectorDoctor {
    struct RepairSignals {
        var needsRuntimeRepair: Bool
        var needsWineserverReset: Bool
        var needsPatchSync: Bool
        var needsMediaRepair: Bool
        var needsLauncherDependencyRepair: Bool
        var needsWebViewAuthRepair: Bool
        var needsRuntimeDependencyRepair: Bool
        var needsGraphicsPayloadRepair: Bool
        var needsSteamWebHelperFallback: Bool
        var needsXboxManualFallback: Bool
        var remoteFixIDs: [VectorDoctorFixID]
        var mediaDetails: String
        var launcherDetails: String
        var graphicsDetails: String
        var steamDetails: String
    }

    // swiftlint:disable:next function_body_length
    static func repairSignals(
        for bottle: Bottle,
        runtime: VectorDoctorRuntimeSnapshot,
        dispatch: VectorDoctorDispatchSnapshot,
        logs: [VectorDoctorLogSnippet],
        remoteFixIDs: [String] = []
    ) -> RepairSignals {
        let logText = logs.map(\.tail).joined(separator: "\n").lowercased()
        let hasMediaLogFault = containsAny(mediaFaultNeedles, in: logText)
        let hasWebViewAuthFault = containsAny(webViewAuthFaultNeedles, in: logText)
        let hasRuntimeDependencyFault = containsAny(runtimeDependencyFaultNeedles, in: logText)
        let hasSteamWebHelperFault = containsAny(steamWebHelperFaultNeedles, in: logText)
        let hasWineserverMismatch = containsAny(wineserverFaultNeedles, in: logText)
        let normalizedRemoteFixIDs = remoteFixIDs.compactMap(VectorDoctorFixID.init(rawValue:))
        let missingMediaDLLs = missingDLLs(mediaPlaybackDLLs, in: bottle)
        let missingRuntimeDLLs = missingDLLs(runtimeDependencyDLLs, in: bottle)
        let missingDotNetMarkers = missingDotNetRuntimeMarkers(in: bottle)
        let graphicsIssues = graphicsPayloadIssues(in: bottle)
        let missingXboxServices = missingXboxIdentityServiceNames(in: bottle)
        let hasMediaMetadataSignal = normalizedRemoteFixIDs.contains(.repairMediaPlayback)
        let hasLauncherMetadataSignal = normalizedRemoteFixIDs.contains(.repairLauncherDependencies)
        let hasRuntimeDependencyFileSignal = runtimeDependencyFileSignal(
            missingDLLs: missingRuntimeDLLs,
            missingDotNetMarkers: missingDotNetMarkers,
            hasRuntimeDependencyFault: hasRuntimeDependencyFault,
            hasLauncherMetadataSignal: hasLauncherMetadataSignal,
            trainerSupportMode: bottle.settings.trainerSupportMode
        )
        let hasRepairableLauncherFault = hasWebViewAuthFault
            || hasRuntimeDependencyFault
            || hasRuntimeDependencyFileSignal
            || hasLauncherMetadataSignal
        let hasXboxManualFallback = hasWebViewAuthFault && !missingXboxServices.isEmpty

        return RepairSignals(
            needsRuntimeRepair: !runtime.bundledWinePresent || !runtime.bundledWineserverPresent,
            needsWineserverReset: hasWineserverMismatch,
            needsPatchSync: dispatch.updateAvailable,
            needsMediaRepair: hasMediaLogFault || !missingMediaDLLs.isEmpty || hasMediaMetadataSignal,
            needsLauncherDependencyRepair: hasRepairableLauncherFault,
            needsWebViewAuthRepair: hasWebViewAuthFault,
            needsRuntimeDependencyRepair: hasRuntimeDependencyFault || hasRuntimeDependencyFileSignal,
            needsGraphicsPayloadRepair: !graphicsIssues.isEmpty,
            needsSteamWebHelperFallback: hasSteamWebHelperFault,
            needsXboxManualFallback: hasXboxManualFallback,
            remoteFixIDs: normalizedRemoteFixIDs,
            mediaDetails: mediaDetails(
                missingDLLs: missingMediaDLLs,
                hasMediaLogFault: hasMediaLogFault,
                hasMediaMetadataSignal: hasMediaMetadataSignal
            ),
            launcherDetails: launcherDetails(
                missingDLLs: missingRuntimeDLLs,
                missingDotNetMarkers: missingDotNetMarkers,
                flags: LauncherDetailFlags(
                    hasWebViewAuthFault: hasWebViewAuthFault,
                    hasRuntimeDependencyFault: hasRuntimeDependencyFault,
                    hasLauncherMetadataSignal: hasLauncherMetadataSignal
                ),
                missingXboxServices: missingXboxServices
            ),
            graphicsDetails: graphicsDetails(issues: graphicsIssues),
            steamDetails: steamDetails(hasFault: hasSteamWebHelperFault)
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
    struct LauncherDetailFlags {
        var hasWebViewAuthFault: Bool
        var hasRuntimeDependencyFault: Bool
        var hasLauncherMetadataSignal: Bool
    }

    static let mediaPlaybackDLLs = [
        "mf.dll",
        "mfplat.dll",
        "mfreadwrite.dll",
        "mfplay.dll",
        "evr.dll",
        "quartz.dll",
        "devenum.dll",
        "wmvcore.dll",
        "msmpeg2vdec.dll",
        "msmpeg2adec.dll",
        "winegstreamer.dll"
    ]

    static let dotNetRuntimeDLLs = [
        "mscoree.dll",
        "mscorsvw.exe",
        "fusion.dll"
    ]

    static let visualCppRuntimeDLLs = [
        "vcruntime140.dll",
        "vcruntime140_1.dll",
        "msvcp140.dll",
        "concrt140.dll",
        "ucrtbase.dll",
        "api-ms-win-crt-runtime-l1-1-0.dll"
    ]

    static let dxvkPayloadDLLs = [
        "dxgi.dll",
        "d3d11.dll",
        "d3d10core.dll"
    ]

    static let dxmtCorePayloadDLLs = [
        "dxgi.dll",
        "d3d11.dll",
        "d3d10core.dll"
    ]

    static let dlssPayloadDLLs = [
        "nvapi64.dll",
        "nvngx.dll"
    ]

    static var runtimeDependencyDLLs: [String] {
        dotNetRuntimeDLLs + visualCppRuntimeDLLs
    }

    static let mediaFaultNeedles = [
        "media foundation",
        "mfplat.dll",
        "mfreadwrite.dll",
        "mfplay.dll",
        "evr.dll",
        "winegstreamer",
        "wmvcore.dll",
        "msmpeg2vdec.dll",
        "msmpeg2adec.dll",
        "quartz.dll",
        "imfsource",
        "codec",
        "failed to initialize video",
        "failed to play video",
        "video playback"
    ]

    static let webViewAuthFaultNeedles = [
        "webview2",
        "webview",
        "edgewebview",
        "microsoft-edge",
        "login.live.com",
        "account.live.com",
        "sisu.xboxlive.com",
        "xboxlive",
        "xbox auth",
        "ms-xal",
        "ms-xbl",
        "xbl_ticket",
        "you have reached a page that is not normally shown",
        "microsoft will never ask you to copy or share this url"
    ]

    static let runtimeDependencyFaultNeedles = [
        "mscoree.dll",
        "mscorsvw.exe",
        "fusion.dll",
        "vcruntime",
        "vcruntime140_1.dll",
        "msvcp",
        "msvcr",
        "concrt140.dll",
        "ucrtbase.dll",
        "api-ms-win-crt",
        "import_dll"
    ]

    static let steamWebHelperFaultNeedles = [
        "steamwebhelper",
        "steamwebhelper.exe",
        "steam helper",
        "steam cef",
        "cef",
        "htmlcache",
        "steamwebhelper crashed",
        "steamwebhelper, a critical steam component"
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
                detail: "Repair mirrored Media Foundation/Quartz DLLs and enable media compatibility mode.",
                actionTitle: "Repair Media"
            )
        case .repairLauncherDependencies:
            return VectorDoctorFixSuggestion(
                id: id,
                title: "Launcher dependency repair",
                detail: "Install repairable WebView2, .NET, Visual C++ runtime, and core font dependencies.",
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

    static func mediaDetails(
        missingDLLs: [String],
        hasMediaLogFault: Bool,
        hasMediaMetadataSignal: Bool
    ) -> String {
        if missingDLLs.isEmpty, hasMediaMetadataSignal {
            return "Compatibility metadata recommends the media playback repair for this game."
        }
        if missingDLLs.isEmpty, hasMediaLogFault {
            return "Recent logs indicate Media Foundation, codec, Quartz, or winegstreamer video faults."
        }
        var details = ["Missing or drifted media DLLs: \(missingDLLs.prefix(5).joined(separator: ", "))."]
        if hasMediaMetadataSignal {
            details.append("Compatibility metadata also recommends the media playback repair.")
        }
        return details.joined(separator: " ")
    }

    static func launcherDetails(
        missingDLLs: [String],
        missingDotNetMarkers: [String],
        flags: LauncherDetailFlags,
        missingXboxServices: [String]
    ) -> String {
        var details: [String] = []
        if flags.hasLauncherMetadataSignal {
            details.append("Compatibility metadata recommends launcher dependency repair for this game.")
        }
        if flags.hasWebViewAuthFault {
            details.append("Recent logs match Microsoft/Xbox/WebView2 auth-loop signals.")
        }
        if flags.hasRuntimeDependencyFault {
            details.append("Recent logs mention .NET, Visual C++, UCRT, or loader DLL failures.")
        }
        let missingVisualCppDLLs = missingDLLs.filter { visualCppRuntimeDLLs.contains($0) }
        if !missingVisualCppDLLs.isEmpty {
            let dlls = missingVisualCppDLLs.prefix(4).joined(separator: ", ")
            details.append("Missing Visual C++/UCRT DLL candidates: \(dlls).")
        }
        if !missingDotNetMarkers.isEmpty {
            details.append("Missing .NET runtime markers: \(missingDotNetMarkers.prefix(4).joined(separator: ", ")).")
        }
        if flags.hasWebViewAuthFault, !missingXboxServices.isEmpty {
            let services = missingXboxServices.prefix(4).joined(separator: ", ")
            details.append(
                "Xbox Identity/Gaming Services are unavailable in this prefix (\(services)); Vector can reset "
                    + "WebView/cache/callback state, but the Microsoft Store service layer is a manual fallback."
            )
        }

        return details.isEmpty ? "Launcher dependencies look healthy." : details.joined(separator: " ")
    }

    static func graphicsDetails(issues: [String]) -> String {
        guard !issues.isEmpty else {
            return "DXVK/DXMT/DLSS payloads required by current settings are present or not requested."
        }
        return issues.joined(separator: " ")
    }

    static func steamDetails(hasFault: Bool) -> String {
        hasFault
            ? "Steam webhelper/CEF logs were detected. Vector can apply safe UI flags and clear htmlcache; "
                + "it cannot install a replacement Steam CEF runtime."
            : "No Steam webhelper/CEF fallback signals detected in recent logs."
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

    static func graphicsPayloadIssues(in bottle: Bottle) -> [String] {
        var issues: [String] = []
        let missingDXVK = missingDLLCopies(dxvkPayloadDLLs, in: bottle)
        if expectsDXVK(for: bottle), !missingDXVK.isEmpty {
            issues.append(
                "DXVK is selected, but core DXVK DLLs are missing: \(formattedDLLCopies(missingDXVK))."
            )
        }
        if expectsDXMT(for: bottle) {
            if !Wine.isDXMTPayloadReady() {
                issues.append("DXMT is selected, but Vector's cached DXMT payload is incomplete.")
            }
            let missingDXMT = missingDLLCopies(dxmtCorePayloadDLLs, in: bottle)
            if !missingDXMT.isEmpty {
                issues.append(
                    "DXMT core DLL deployment is incomplete: \(formattedDLLCopies(missingDXMT))."
                )
            }
            if bottle.settings.dlssRuntimeTranslationEnabled, !hasDLSSRuntimePayload(for: bottle) {
                let missingDLSS = missingDLLCopies(dlssPayloadDLLs, in: bottle, directories: ["system32"])
                let suffix = missingDLSS.isEmpty ? "" : ": \(formattedDLLCopies(missingDLSS))"
                issues.append("DLSS translation is enabled, but NVAPI/NVNGX DLLs are missing\(suffix).")
            }
        }
        return issues
    }

    static func expectsDXVK(for bottle: Bottle) -> Bool {
        bottle.settings.graphicsBackendMode == .dxvk
            || bottle.settings.graphicsBackendMode == .auto
                && bottle.settings.inferredGraphicsBackendMode == .dxvk
    }

    static func expectsDXMT(for bottle: Bottle) -> Bool {
        bottle.settings.graphicsBackendMode == .dxmt
            || bottle.settings.graphicsBackendMode == .auto
                && bottle.settings.inferredGraphicsBackendMode == .dxmt
            || bottle.settings.dlssRuntimeTranslationEnabled
    }

    static func hasDLLs(_ dllNames: [String], in bottle: Bottle) -> Bool {
        missingDLLs(dllNames, in: bottle).isEmpty
    }

    static func missingDLLCopies(
        _ dllNames: [String],
        in bottle: Bottle,
        directories: [String] = ["system32", "syswow64"]
    ) -> [String] {
        let windowsDirectory = bottle.url.appending(path: "drive_c").appending(path: "windows")
        let fileManager = FileManager.default
        return directories.flatMap { directory in
            dllNames.compactMap { dllName in
                let url = windowsDirectory.appending(path: directory).appending(path: dllName)
                return fileManager.fileExists(atPath: url.path(percentEncoded: false))
                    ? nil
                    : "\(directory)/\(dllName)"
            }
        }
    }

    static func formattedDLLCopies(_ copies: [String]) -> String {
        let formatted = copies.prefix(6).joined(separator: ", ")
        if copies.count <= 6 {
            return formatted
        }
        return "\(formatted), +\(copies.count - 6) more"
    }

    static func missingDotNetRuntimeMarkers(in bottle: Bottle) -> [String] {
        var missing = missingDLLs(dotNetRuntimeDLLs, in: bottle)
        let windows = bottle.url.appending(path: "drive_c").appending(path: "windows")
        let frameworkCandidates = [
            windows
                .appending(path: "Microsoft.NET")
                .appending(path: "Framework")
                .appending(path: "v4.0.30319")
                .appending(path: "mscorlib.dll"),
            windows
                .appending(path: "Microsoft.NET")
                .appending(path: "Framework64")
                .appending(path: "v4.0.30319")
                .appending(path: "mscorlib.dll")
        ]
        let hasFramework = frameworkCandidates.contains {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
        if !hasFramework {
            missing.append("Microsoft.NET Framework v4")
        }
        return missing
    }

    static func runtimeDependencyFileSignal(
        missingDLLs: [String],
        missingDotNetMarkers: [String],
        hasRuntimeDependencyFault: Bool,
        hasLauncherMetadataSignal: Bool,
        trainerSupportMode: Bool
    ) -> Bool {
        guard hasRuntimeDependencyFault || hasLauncherMetadataSignal || trainerSupportMode else {
            return false
        }

        return !missingDLLs.isEmpty || !missingDotNetMarkers.isEmpty
    }

    static func hasDLSSRuntimePayload(for bottle: Bottle) -> Bool {
        let fileManager = FileManager.default
        let windowsDirectory = bottle.url.appending(path: "drive_c").appending(path: "windows")
        let runtimeWineFolder = runtimeWineFolder(for: bottle)
        let paths = [
            runtimeWineFolder.appending(path: "x86_64-windows").appending(path: "nvapi64.dll"),
            runtimeWineFolder.appending(path: "x86_64-windows").appending(path: "nvngx.dll"),
            windowsDirectory.appending(path: "system32").appending(path: "nvapi64.dll"),
            windowsDirectory.appending(path: "system32").appending(path: "nvngx.dll")
        ]
        return paths.allSatisfy { fileManager.fileExists(atPath: $0.path(percentEncoded: false)) }
    }

    static func runtimeWineFolder(for bottle: Bottle) -> URL {
        let runtimeWineBinary = selectedRuntimeWineBinary(for: bottle)
        let runtimeRoot = runtimeWineBinary.deletingLastPathComponent().deletingLastPathComponent()
        let runtimeWineFolder = runtimeRoot.appending(path: "lib").appending(path: "wine")
        if FileManager.default.fileExists(atPath: runtimeWineFolder.path(percentEncoded: false)) {
            return runtimeWineFolder
        }

        return VectorWineInstaller.libraryFolder
            .appending(path: "Wine")
            .appending(path: "lib")
            .appending(path: "wine")
    }

    static func selectedRuntimeWineBinary(for bottle: Bottle) -> URL {
        switch bottle.settings.runtimeSelection {
        case .bundled:
            return VectorWineInstaller.binFolder.appending(path: "wine64")
        case .compatibility:
            return VectorWineInstaller.steamCompatibilityWineBinary()
                ?? VectorWineInstaller.binFolder.appending(path: "wine64")
        case .crossover:
            return VectorWineInstaller.crossOverRuntimeBinaries()?.wine
                ?? VectorWineInstaller.binFolder.appending(path: "wine64")
        case .custom:
            let path = bottle.settings.customWineBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(filePath: path)
            }
            return VectorWineInstaller.binFolder.appending(path: "wine64")
        case .auto:
            if VectorWineInstaller.isCrossOverBottleURL(bottle.url),
               let runtime = VectorWineInstaller.crossOverRuntimeBinaries()?.wine {
                return runtime
            }
            return VectorWineInstaller.binFolder.appending(path: "wine64")
        }
    }

    static func missingXboxIdentityServiceNames(in bottle: Bottle) -> [String] {
        let expectedServices = [
            "GamingServices",
            "GamingServicesNet",
            "XblAuthManager",
            "XblGameSave",
            "XboxGipSvc",
            "XboxNetApiSvc"
        ]
        let systemRegistryURL = bottle.url.appending(path: "system.reg")
        guard let contents = try? String(contentsOf: systemRegistryURL, encoding: .utf8).lowercased() else {
            return expectedServices
        }

        return expectedServices.filter { service in
            let registryKey = #"system\\currentcontrolset\\services\\"# + service.lowercased()
            return !contents.contains(registryKey)
        }
    }
}
