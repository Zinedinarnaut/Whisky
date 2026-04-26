//
//  ConfigView.swift
//  Vector
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

import SwiftUI
import AppKit
import os.log
import UniformTypeIdentifiers
import CryptoKit
import VectorKit
#if canImport(FoundationModels)
import FoundationModels
#endif
enum LoadingState {
    case loading
    case modifying
    case success
    case failed
}

struct ConfigView: View {
    @ObservedObject var bottle: Bottle
    @State private var buildVersion: Int = 0
    @State private var retinaMode: Bool = false
    @State private var dpiConfig: Int = 96
    @State private var winVersionLoadingState: LoadingState = .loading
    @State private var buildVersionLoadingState: LoadingState = .loading
    @State private var retinaModeLoadingState: LoadingState = .loading
    @State private var dpiConfigLoadingState: LoadingState = .loading
    @State private var dpiSheetPresented: Bool = false
    @State private var gameProfilesDraft: [BottleGameProfile] = []
    @State private var gameProfilesSaveTask: Task<Void, Never>?
    @State private var snapshotMessage: String = ""
    @State private var snapshotInFlight: Bool = false
    @State private var launchDoctorLoading: Bool = false
    @State private var launchDoctorReport: LaunchDoctorReport?
    @State private var launchDoctorStatusMessage: String = ""
    @State private var vectorDoctorLoading: Bool = false
    @State private var vectorDoctorReport: VectorDoctorReport?
    @State private var vectorDoctorStatusMessage: String = ""
    @State private var missingDependencyFixes: [MissingDependencyFix] = []
    @State private var environmentRepairInFlight: Bool = false
    @State private var dlssHealthModalPresented: Bool = false
    @State private var dlssHealthLoading: Bool = false
    @State private var dlssHealthReport = DLSSRuntimeHealthReport.empty
    @AppStorage("quickSetupSectionExpanded") private var quickSetupSectionExpanded: Bool = true
    @AppStorage("wineSectionExpanded") private var wineSectionExpanded: Bool = false
    @AppStorage("dxvkSectionExpanded") private var dxvkSectionExpanded: Bool = false
    @AppStorage("metalSectionExpanded") private var metalSectionExpanded: Bool = false
    @AppStorage("runtimeSectionExpanded") private var runtimeSectionExpanded: Bool = false
    @AppStorage("steamSectionExpanded") private var steamSectionExpanded: Bool = false
    @AppStorage("compatSectionExpanded") private var compatSectionExpanded: Bool = false
    @AppStorage("launchDoctorSectionExpanded") private var launchDoctorSectionExpanded: Bool = false
    @AppStorage("vectorDoctorSectionExpanded") private var vectorDoctorSectionExpanded: Bool = false
    @AppStorage("gamingSectionExpanded") private var gamingSectionExpanded: Bool = false
    @AppStorage("perfSectionExpanded") private var perfSectionExpanded: Bool = false
    @AppStorage("profilesSectionExpanded") private var profilesSectionExpanded: Bool = false
    @AppStorage("snapshotsSectionExpanded") private var snapshotsSectionExpanded: Bool = false
    @AppStorage("presetsSectionExpanded") private var presetsSectionExpanded: Bool = false
    @AppStorage("dependencySectionExpanded") private var dependencySectionExpanded: Bool = true
    @AppStorage("launchDoctorUseAppleIntelligence") private var launchDoctorUseAppleIntelligence: Bool = true

    private var protectedAssessment: ProtectedLaunchAssessment? {
        VectorProtectedTitlePolicyEngine.scannedProtectedAssessment(for: bottle)
    }

    var body: some View {
        Form {
            if !missingDependencyFixes.isEmpty {
                Section("Fix Missing Dependencies", isExpanded: $dependencySectionExpanded) {
                    Text("Detected runtime/dependency issues for this bottle. Apply a one-click fix.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Repair Environment") {
                            runEnvironmentRepair()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(snapshotInFlight || environmentRepairInFlight)
                        .help(
                            "Runs runtime DLL verify+repair and applies recommended dependency fixes for this bottle."
                        )
                        Spacer()
                        if environmentRepairInFlight {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    ForEach(missingDependencyFixes) { fix in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(fix.title)
                                .font(.subheadline.weight(.semibold))
                            Text(fix.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button(fix.actionTitle) {
                                applyMissingDependencyFix(fix.id)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            Section("config.title.wine", isExpanded: $wineSectionExpanded) {
                SettingItemView(title: "config.winVersion", loadingState: winVersionLoadingState) {
                    Picker("config.winVersion", selection: $bottle.settings.windowsVersion) {
                        ForEach(WinVersion.allCases.reversed(), id: \.self) {
                            Text($0.pretty())
                        }
                    }
                    .help("Select which Windows version this bottle reports to applications.")
                }
                SettingItemView(title: "config.buildVersion", loadingState: buildVersionLoadingState) {
                    TextField("config.buildVersion", value: $buildVersion, formatter: NumberFormatter())
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(PlainTextFieldStyle())
                        .help("Override the Windows build number reported by this bottle.")
                        .onSubmit {
                            buildVersionLoadingState = .modifying
                            Task(priority: .userInitiated) {
                                do {
                                    try await Wine.changeBuildVersion(bottle: bottle, version: buildVersion)
                                    buildVersionLoadingState = .success
                                } catch {
                                    print("Failed to change build version")
                                    buildVersionLoadingState = .failed
                                }
                            }
                        }
                }
                SettingItemView(title: "config.retinaMode", loadingState: retinaModeLoadingState) {
                    Toggle("config.retinaMode", isOn: $retinaMode)
                        .help("Enable high-DPI Retina rendering for Wine windows.")
                        .onChange(of: retinaMode, { _, newValue in
                            Task(priority: .userInitiated) {
                                retinaModeLoadingState = .modifying
                                do {
                                    try await Wine.changeRetinaMode(bottle: bottle, retinaMode: newValue)
                                    retinaModeLoadingState = .success
                                } catch {
                                    print("Failed to change build version")
                                    retinaModeLoadingState = .failed
                                }
                            }
                        })
                }
                Picker("config.enhancedSync", selection: $bottle.settings.enhancedSync) {
                    Text("config.enhancedSync.none").tag(EnhancedSync.none)
                    Text("config.enhacnedSync.esync").tag(EnhancedSync.esync)
                    Text("config.enhacnedSync.msync").tag(EnhancedSync.msync)
                }
                .help("Select Wine synchronization mode. Esync is generally safest; Msync can improve performance on some games.")
                SettingItemView(title: "config.dpi", loadingState: dpiConfigLoadingState) {
                    Button("config.inspect") {
                        dpiSheetPresented = true
                    }
                    .help("Open the DPI editor to adjust default UI scaling for this bottle.")
                    .sheet(isPresented: $dpiSheetPresented) {
                        DPIConfigSheetView(
                            dpiConfig: $dpiConfig,
                            isRetinaMode: $retinaMode,
                            presented: $dpiSheetPresented
                        )
                    }
                }
                if #available(macOS 15, *) {
                    Toggle(isOn: $bottle.settings.avxEnabled) {
                        VStack(alignment: .leading) {
                            Text("config.avx")
                            if bottle.settings.avxEnabled {
                                HStack(alignment: .firstTextBaseline) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .symbolRenderingMode(.multicolor)
                                        .font(.subheadline)
                                    Text("config.avx.warning")
                                        .fontWeight(.light)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    .help("Advertise AVX support to Windows apps. Helps some newer games but may break others.")
                }
            }
            Section("config.title.dxvk", isExpanded: $dxvkSectionExpanded) {
                Toggle(isOn: $bottle.settings.dxvk) {
                    Text("config.dxvk")
                }
                .help("Use DXVK to translate DirectX 9/10/11 to Vulkan.")
                Toggle(isOn: $bottle.settings.dxvkAsync) {
                    Text("config.dxvk.async")
                }
                .help("Allow asynchronous shader compilation in DXVK to reduce stutter at the cost of occasional visual artifacts.")
                .disabled(!bottle.settings.dxvk)
                Picker("config.dxvkHud", selection: $bottle.settings.dxvkHud) {
                    Text("config.dxvkHud.full").tag(DXVKHUD.full)
                    Text("config.dxvkHud.partial").tag(DXVKHUD.partial)
                    Text("config.dxvkHud.fps").tag(DXVKHUD.fps)
                    Text("config.dxvkHud.off").tag(DXVKHUD.off)
                }
                .help("Choose how much DXVK performance/debug info is shown in-game.")
                .disabled(!bottle.settings.dxvk)
            }
            Section("config.title.metal", isExpanded: $metalSectionExpanded) {
                Toggle(isOn: $bottle.settings.metalHud) {
                    Text("config.metalHud")
                }
                .help("Show Metal/MoltenVK debugging HUD when available.")
                Toggle(isOn: $bottle.settings.metalTrace) {
                    Text("config.metalTrace")
                    Text("config.metalTrace.info")
                }
                .help("Capture extra Metal trace information for debugging. This can reduce performance.")
                if let device = MTLCreateSystemDefaultDevice() {
                    // Represents the Apple family 9 GPU features that correspond to the Apple A17, M3, and M4 GPUs.
                    if device.supportsFamily(.apple9) {
                        Toggle(isOn: $bottle.settings.dxrEnabled) {
                            Text("config.dxr")
                            Text("config.dxr.info")
                        }
                        .help("Enable DirectX Raytracing support when the runtime and GPU path support it.")
                    }
                }
            }
            Section("Runtime", isExpanded: $runtimeSectionExpanded) {
                Picker("Runtime Selection", selection: $bottle.settings.runtimeSelection) {
                    ForEach(WineRuntimeSelection.allCases, id: \.self) { selection in
                        Text(runtimeSelectionTitle(selection)).tag(selection)
                    }
                }
                .vectorCompactPicker()
                .help("Choose which Wine runtime binaries this bottle should launch with.")

                if bottle.settings.runtimeSelection == .auto, VectorWineInstaller.isCrossOverBottleURL(bottle.url) {
                    Text("CrossOver bottle detected. Auto runtime will prefer CrossOver's wine/wineserver pair.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if bottle.settings.runtimeSelection == .crossover,
                   VectorWineInstaller.crossOverRuntimeBinaries() == nil {
                    Text("CrossOver runtime selected, but CrossOver wine binaries were not found.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if bottle.settings.runtimeSelection == .custom {
                    VStack(alignment: .leading) {
                        Text("Custom wine binary path")
                        TextField(
                            "e.g. /Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine64",
                            text: $bottle.settings.customWineBinaryPath
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .help("Absolute path to the custom wine or wine64 executable.")
                    }

                    VStack(alignment: .leading) {
                        Text("Custom wineserver binary path")
                        TextField(
                            "e.g. /Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wineserver",
                            text: $bottle.settings.customWineserverBinaryPath
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .help("Absolute path to the wineserver executable that matches the custom Wine binary.")
                    }
                }
            }
            Section("Steam Compatibility", isExpanded: $steamSectionExpanded) {
                Toggle("Use safe launch flags", isOn: $bottle.settings.steamUseSafeLaunchFlags)
                    .help("Adds conservative launch flags that improve Steam startup reliability on problematic setups.")
                Toggle("Use legacy extra flags", isOn: $bottle.settings.steamUseLegacyExtraFlags)
                    .help("Applies older fallback flags used by legacy Steam compatibility flows.")
                Toggle("Force -no-browser", isOn: $bottle.settings.steamForceNoBrowser)
                    .help("Starts Steam without its browser surfaces to avoid CEF-related UI crashes.")
                Toggle("Use legacy bootstrap/update flow", isOn: $bottle.settings.steamUseLegacyBootstrap)
                    .help("Uses an older Steam bootstrap/update path for compatibility testing.")
                Toggle("Reset Steam htmlcache on first launch", isOn: $bottle.settings.steamResetHTMLCacheOnLaunch)
                    .help("Deletes Steam web cache once on next launch to recover from broken web UI state.")
                Toggle("Disable Steam overlay", isOn: $bottle.settings.steamDisableOverlay)
                    .help("Disables Steam overlay injection for improved compatibility and stability.")

                VStack(alignment: .leading) {
                    Text("Steam package archive URL")
                    TextField("Archive URL", text: $bottle.settings.steamPackageArchiveURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .help("Optional URL to a Steam package archive used by compatibility setup flows.")
                }
            }
            Section("Compatibility", isExpanded: $compatSectionExpanded) {
                Picker("Graphics backend", selection: $bottle.settings.graphicsBackendMode) {
                    ForEach(GraphicsBackendMode.allCases, id: \.self) { mode in
                        Text(graphicsBackendTitle(mode)).tag(mode)
                    }
                }
                .vectorCompactPicker()
                .help("Select which rendering translation backend to prefer for this bottle.")

                if bottle.settings.graphicsBackendMode == .dxmt {
                    Text("DXMT requires a DXMT-capable Wine runtime and DXMT DLL payloads in the runtime/prefix. For external non-builtin DXMT installs, use Custom WINEDLLOVERRIDES: dxgi,d3d10core,d3d11=n,b")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("Force DirectX 11 compatibility args", isOn: $bottle.settings.forceD3D11Compatibility)
                    .help("Automatically adds D3D11 launch flags for games that need explicit DirectX 11 mode.")
                Toggle("Enable global media playback compatibility", isOn: $bottle.settings.mediaPlaybackCompatibilityMode)
                    .help(
                        "Adds a global media-focused DLL override layer so intros, cutscenes, and embedded video playback work more reliably across launches."
                    )
                Toggle("Installer compatibility mode", isOn: $bottle.settings.installerCompatibilityMode)
                    .help(
                        "Applies installer-safe runtime and DLL override behavior for setup/install executables."
                    )
                Picker("Runtime system DLL sync", selection: $bottle.settings.runtimeDLLSyncMode) {
                    ForEach(RuntimeDLLSyncMode.allCases, id: \.self) { mode in
                        Text(runtimeDLLSyncModeTitle(mode)).tag(mode)
                    }
                }
                .vectorCompactPicker()
                .help(
                    "Controls runtime system32/syswow64 sync behavior. Verify modes fingerprint DLL drift and can optionally auto-repair."
                )
                Toggle("Enable DLSS runtime translation (DXMT)", isOn: $bottle.settings.dlssRuntimeTranslationEnabled)
                    .help(
                        "Enables DXMT NV extension translation path (DLSS/NGX shim routing) and installs required DXMT payload files at launch."
                    )
                Toggle(
                    "Allow frame generation fallback",
                    isOn: $bottle.settings.dlssFrameGenerationFallbackEnabled
                )
                .disabled(!bottle.settings.dlssRuntimeTranslationEnabled)
                .help(
                    "Allows frame-generation related plugins to initialize when available. Keep disabled for maximum stability."
                )
                Button("Check DLSS Runtime Health") {
                    presentDLSSRuntimeHealthModal()
                }
                .help("Open a runtime health modal with payload and DLL path validation for DLSS translation.")
                Toggle("Enable trainer compatibility mode", isOn: $bottle.settings.trainerSupportMode)
                    .disabled(protectedAssessment != nil)
                    .help("Adjusts runtime behavior for trainer/overlay utilities that rely on injection hooks.")
                Toggle("Use native macOS Game Mode launcher", isOn: $bottle.settings.nativeGameModeLaunchesEnabled)
                    .help("Launches non-Steam games through a game-classified app wrapper so macOS can enable Game Mode in fullscreen.")

                Picker("DLL overrides policy", selection: $bottle.settings.dllOverridesPolicy) {
                    ForEach(DLLOverridesPolicy.allCases, id: \.self) { policy in
                        Text(dllOverridesPolicyTitle(policy)).tag(policy)
                    }
                }
                .vectorCompactPicker()
                .help("Controls default WINEDLLOVERRIDES handling for this bottle.")

                if bottle.settings.dllOverridesPolicy == .custom {
                    VStack(alignment: .leading) {
                        Text("Custom WINEDLLOVERRIDES")
                        TextField("e.g. d3d11=n,b;dxgi=n,b", text: $bottle.settings.customDLLOverrides)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .help("Semicolon-separated DLL override rules passed as WINEDLLOVERRIDES.")
                    }
                }

                Picker("Anti-cheat preflight", selection: $bottle.settings.antiCheatPreflightMode) {
                    ForEach(AntiCheatPreflightMode.allCases, id: \.self) { mode in
                        Text(antiCheatModeTitle(mode)).tag(mode)
                    }
                }
                .vectorCompactPicker()
                .help("Set how strictly Vector should pre-check known anti-cheat compatibility before launch.")
                Toggle("Safe multiplayer mode", isOn: $bottle.settings.safeMultiplayerMode)
                    .help("Blocks trainer launches and enforces anti-cheat-safe preflight defaults for multiplayer safety.")
                Toggle("Allow unsupported anti-cheat launches", isOn: $bottle.settings.allowUnsupportedAntiCheatLaunches)
                    .help("When enabled, launches continue even if anti-cheat checks indicate likely incompatibility.")
                    .disabled(bottle.settings.safeMultiplayerMode || protectedAssessment != nil)
                if bottle.settings.safeMultiplayerMode {
                    Text("Safe multiplayer mode is enabled, so unsupported anti-cheat launches are blocked.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let protectedAssessment, let title = protectedAssessment.matchedTitle {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Protected Multiplayer: Blocked")
                            .font(.subheadline.weight(.semibold))
                        Text("\(title.title) is protected. Trainers, memory tooling, local overrides, and unsafe launch mutations are locked.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Fallback: \(title.fallbackPlayOptions.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Export Studio Review Report") {
                            exportProtectedMultiplayerReport()
                        }
                        .buttonStyle(.bordered)
                        .help("Exports runtime attestation, detected artifacts, policy state, and patch digest as JSON.")
                    }
                }

                Picker("Log profile", selection: $bottle.settings.logProfile) {
                    ForEach(BottleLogProfile.allCases, id: \.self) { profile in
                        Text(logProfileTitle(profile)).tag(profile)
                    }
                }
                .vectorCompactPicker()
                .help("Controls default Wine logging verbosity for launches in this bottle.")

                VStack(alignment: .leading) {
                    Text("Active Steam AppID (for profile matching)")
                    TextField("e.g. 648800", text: $bottle.settings.activeSteamAppID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .help("Current Steam AppID used to match and apply game profiles.")
                }
            }
            Section("Smart Launch Doctor", isExpanded: $launchDoctorSectionExpanded) {
                Toggle("Use Apple Intelligence summaries", isOn: $launchDoctorUseAppleIntelligence)
                    .help("Uses on-device intelligence summarization for diagnosis output when available.")

                Button("Analyze Launch Health") {
                    runLaunchDoctor()
                }
                .help("Analyze recent bottle logs and classify likely launch failures with recommended fixes.")

                if launchDoctorLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                if !launchDoctorStatusMessage.isEmpty {
                    Text(launchDoctorStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let report = launchDoctorReport {
                    HStack {
                        Text("Bottle health score")
                        Spacer()
                        Text("\(report.health.score)/100")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(healthScoreColor(report.health.score))
                    }

                    if !report.findings.isEmpty || !missingDependencyFixes.isEmpty {
                        Button("Repair Environment") {
                            runEnvironmentRepair()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(snapshotInFlight || environmentRepairInFlight)
                        .help("Runs one-click repair based on current health and dependency findings.")
                    }

                    Text(report.intelligenceSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if report.findings.isEmpty {
                        Text("No major launch blockers detected in recent logs.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(report.findings) { finding in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: findingSymbol(for: finding.severity))
                                    .foregroundStyle(findingColor(for: finding.severity))
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(finding.title)
                                        .fontWeight(.semibold)
                                    Text(finding.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if !report.suggestedFixes.isEmpty {
                        Divider()
                        Text("Recommended one-click fixes")
                            .font(.subheadline)
                        ForEach(report.suggestedFixes) { fix in
                            Button(fix.id.title) {
                                applyLaunchDoctorFix(fix.id)
                            }
                            .help(fix.detail)
                        }
                    }

                    if !report.health.risks.isEmpty {
                        Divider()
                        Text("Detected risks")
                            .font(.subheadline)
                        ForEach(report.health.risks, id: \.self) { risk in
                            Text("• \(risk)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Vector Doctor", isExpanded: $vectorDoctorSectionExpanded) {
                Text("Runs host, runtime, bridge, VecPatch, protected-title, and recent-log checks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Run Vector Doctor") {
                        runVectorDoctor()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vectorDoctorLoading)

                    Button("Export Diagnostic Bundle") {
                        exportVectorDoctorReport()
                    }
                    .disabled(vectorDoctorLoading)
                }

                if vectorDoctorLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                if !vectorDoctorStatusMessage.isEmpty {
                    Text(vectorDoctorStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let report = vectorDoctorReport {
                    ForEach(report.checks) { check in
                        vectorDoctorCheckRow(check)
                    }

                    Divider()
                    HStack {
                        Text("VecPatch")
                        Spacer()
                        Text(report.dispatch.message)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    HStack {
                        Text("Memory Bridge")
                        Spacer()
                        Text(report.memoryBridge.message)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Section("Gaming & Patch Dispatch", isExpanded: $gamingSectionExpanded) {
                Toggle("Enable gaming bottle mode", isOn: $bottle.settings.gamingModeEnabled)
                    .help("Turns on gaming-focused defaults and enables launcher/patch automation options.")
                Toggle("Auto snapshot before risky actions", isOn: $bottle.settings.autoSnapshotBeforeRiskyChanges)
                    .help("Creates a snapshot before dispatch sync, Winetricks presets, and profile preset edits.")
                    .disabled(!bottle.settings.gamingModeEnabled)

                Toggle("Auto-install launcher installers", isOn: $bottle.settings.gamingAutoInstallLaunchers)
                    .help("Downloads Steam, Epic, Ubisoft Connect, and GOG installers into this bottle.")
                    .disabled(!bottle.settings.gamingModeEnabled)
                Toggle("Auto-pin launchers", isOn: $bottle.settings.gamingAutoPinLaunchers)
                    .help("Pins detected launcher executables and installer entries for quick access.")
                    .disabled(!bottle.settings.gamingModeEnabled)
                Toggle("Auto-apply known game patches", isOn: $bottle.settings.gamingAutoApplyKnownGamePatches)
                    .help("Keeps built-in compatibility profiles for known games up to date in this bottle.")
                    .disabled(!bottle.settings.gamingModeEnabled)

                Divider()

                Toggle("Enable patch dispatch sync", isOn: $bottle.settings.patchDispatchEnabled)
                    .help("Fetches compatibility patch rules from the configured dispatch service.")
                    .disabled(!bottle.settings.gamingModeEnabled)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Dispatch endpoint URL")
                    TextField(BottleDispatchConfig.defaultEndpointURL, text: $bottle.settings.patchDispatchEndpointURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disabled(!bottle.settings.patchDispatchEnabled || !bottle.settings.gamingModeEnabled)
                }
                .help("HTTPS URL returning patch rules in Vector dispatch JSON format.")

                Stepper(
                    "Dispatch refresh interval: \(bottle.settings.patchDispatchRefreshIntervalMinutes) min",
                    value: $bottle.settings.patchDispatchRefreshIntervalMinutes,
                    in: 1...180
                )
                .disabled(!bottle.settings.patchDispatchEnabled || !bottle.settings.gamingModeEnabled)
                .help("Minimum time between automatic dispatch fetch attempts.")

                Picker("Dispatch channel", selection: $bottle.settings.patchDispatchChannel) {
                    Text("Stable").tag(DispatchPatchChannel.stable)
                    Text("Beta").tag(DispatchPatchChannel.beta)
                    Text("Experimental").tag(DispatchPatchChannel.experimental)
                }
                .vectorCompactPicker()
                .disabled(!bottle.settings.patchDispatchEnabled || !bottle.settings.gamingModeEnabled)
                .help("Choose which patch channel this bottle syncs from.")

                Toggle("Require signed dispatch rules", isOn: $bottle.settings.patchDispatchRequireSignedRules)
                    .disabled(!bottle.settings.patchDispatchEnabled || !bottle.settings.gamingModeEnabled)
                    .help("When enabled, unsigned rules from dispatch are ignored.")

                Toggle("Allow untrusted TLS (dev only)", isOn: $bottle.settings.patchDispatchAllowUntrustedTLS)
                    .disabled(!bottle.settings.patchDispatchEnabled || !bottle.settings.gamingModeEnabled)
                    .help("Reserved for local development endpoints with self-signed certificates.")

                HStack {
                    Button("Sync Dispatch Patches Now") {
                        runDispatchSync(forceRefresh: true)
                    }
                    .disabled(!bottle.settings.patchDispatchEnabled || !bottle.settings.gamingModeEnabled)
                    .help("Fetches the latest dispatch rules immediately and merges them into game profiles.")

                    Button("Install/PIN Launchers Now") {
                        runLauncherBootstrap()
                    }
                    .disabled(!bottle.settings.gamingModeEnabled)
                    .help("Runs launcher bootstrap immediately using this bottle's gaming mode settings.")
                }
            }
            Section("Performance", isExpanded: $perfSectionExpanded) {
                Toggle("Enable shader cache", isOn: $bottle.settings.shaderCacheEnabled)
                    .help("Enable shader caching to reduce repeated shader compilation stutter across runs.")

                VStack(alignment: .leading) {
                    Text("Shader cache path (empty = bottle default)")
                    TextField("DXVKStateCache", text: $bottle.settings.shaderCachePath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .help("Optional custom shader cache file path. Leave empty to use the bottle default.")
                }

                SettingItemView(title: "Frame-rate limit (0 = uncapped)", loadingState: .success) {
                    TextField(
                        "Frame limit",
                        value: $bottle.settings.frameRateLimit,
                        formatter: NumberFormatter()
                    )
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(PlainTextFieldStyle())
                    .help("Set a frame-rate cap for launched programs. Use 0 for uncapped.")
                }

                Toggle("Enable VSync", isOn: $bottle.settings.vsyncEnabled)
                    .help("Synchronize presentation to display refresh to reduce tearing.")
                Toggle("Enable FSR", isOn: $bottle.settings.fsrEnabled)
                    .help("Enable FidelityFX Super Resolution upscaling when supported by the translation stack.")

                HStack {
                    Text("FSR sharpness")
                    Slider(value: $bottle.settings.fsrSharpness, in: 0...5, step: 0.1)
                        .help("Controls FSR sharpening intensity. Higher values are sharper but can introduce halos.")
                    Text("\(bottle.settings.fsrSharpness, specifier: "%.1f")")
                        .font(.system(.body, design: .monospaced))
                }
                .disabled(!bottle.settings.fsrEnabled)
            }
            Section("Game Profiles", isExpanded: $profilesSectionExpanded) {
                if gameProfilesDraft.isEmpty {
                    Text("No profiles configured")
                        .foregroundStyle(.secondary)
                }

                ForEach(gameProfilesDraft.indices, id: \.self) { index in
                    GroupBox("Profile \(index + 1)") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Profile name", text: profileBinding(index, keyPath: \.name))
                                .textFieldStyle(.roundedBorder)
                                .help("Display name for this launch profile.")
                            TextField("Executable match (substring)", text: profileBinding(index, keyPath: \.executableMatch))
                                .textFieldStyle(.roundedBorder)
                                .help("Case-insensitive substring match against the launched executable path.")
                            TextField("Steam AppID match (optional)", text: profileBinding(index, keyPath: \.steamAppID))
                                .textFieldStyle(.roundedBorder)
                                .help("Optional Steam AppID required for this profile to apply.")
                            TextField("Arguments", text: profileBinding(index, keyPath: \.arguments))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .help("Command-line arguments appended when this profile matches.")
                            TextField(
                                "Environment (KEY=VALUE;KEY2=VALUE2)",
                                text: profileEnvironmentBinding(index)
                            )
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .help("Environment variables for this profile using KEY=VALUE pairs separated by semicolons.")

                            HStack {
                                Spacer()
                                Button("Remove Profile", role: .destructive) {
                                    gameProfilesDraft.remove(at: index)
                                }
                                .help("Delete this launch profile.")
                            }
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Add Profile") {
                        gameProfilesDraft.append(BottleGameProfile(name: "New Profile"))
                    }
                    .help("Create a new profile with per-game arguments and environment overrides.")
                }
            }
            Section("Snapshots", isExpanded: $snapshotsSectionExpanded) {
                Text("Use snapshots before risky runtime or compatibility changes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Create Snapshot") {
                        runSnapshotCreate()
                    }
                    .help("Create a restore point of this bottle's current state.")
                    Button("Restore Latest Snapshot") {
                        runSnapshotRestore()
                    }
                    .help("Restore this bottle from the most recent snapshot archive.")
                    Button("Open Snapshot Folder") {
                        bottle.openSnapshotsDirectory()
                    }
                    .help("Open the folder containing saved snapshot archives.")
                }
                .disabled(snapshotInFlight)

                if snapshotInFlight {
                    ProgressView()
                        .controlSize(.small)
                }

                if !snapshotMessage.isEmpty {
                    Text(snapshotMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Dependency Presets", isExpanded: $presetsSectionExpanded) {
                Text("Quick-install common components via Winetricks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Core Gaming") {
                        runWinetricksPreset("vcrun2022 d3dcompiler_47")
                    }
                    .help("Install common runtime dependencies used by many games.")
                    Button("Unity") {
                        runWinetricksPreset("dotnet48 vcrun2022 d3dcompiler_47")
                    }
                    .help("Install dependency set commonly required by Unity games and launchers.")
                    Button("Unreal") {
                        runWinetricksPreset("vcrun2022 d3dx11_43 xact")
                    }
                    .help("Install dependency set commonly required by Unreal Engine games.")
                }
                .disabled(snapshotInFlight)
                HStack {
                    Button("D3D11 Game Preset") {
                        applyD3D11GamePreset()
                    }
                    .help("Apply recommended settings for DirectX 11 titles.")
                    Button("HighOnLife2 Preset") {
                        applyHighOnLife2Preset()
                    }
                    .help("Apply a tuned compatibility preset for HighOnLife2.")
                    Button("Parcel Simulator D3D11 Preset") {
                        applyParcelSimulatorD3D11Preset()
                    }
                    .help("Apply a tuned DirectX 11 compatibility preset for Parcel Simulator.")
                    Button("Content Warning Preset") {
                        applyContentWarningPreset()
                    }
                    .help("Apply a tuned compatibility preset for Content Warning.")
                    Button("Silent Hill f Preset") {
                        applySilentHillFD3D11Preset()
                    }
                    .help("Apply a safer Silent Hill f compatibility preset without forced API launch flags.")
                    Button("WeMod/Trainer Runtime") {
                        runWinetricksPreset("dotnet48 vcrun2022 corefonts")
                    }
                    .help("Install common components needed by WeMod and many trainer runtimes.")
                    Button("Run Trainer EXE") {
                        runTrainerExecutable()
                    }
                    .disabled(protectedAssessment != nil)
                    .help("Pick and run a trainer executable directly inside this bottle.")
                }
                .disabled(snapshotInFlight)
            }
        }
        .formStyle(.grouped)
        .toggleStyle(VectorCompactToggleStyle())
        .background(VectorPanelTokens.background)
        .animation(.vectorDefault, value: wineSectionExpanded)
        .animation(.vectorDefault, value: dxvkSectionExpanded)
        .animation(.vectorDefault, value: metalSectionExpanded)
        .animation(.vectorDefault, value: runtimeSectionExpanded)
        .animation(.vectorDefault, value: steamSectionExpanded)
        .animation(.vectorDefault, value: compatSectionExpanded)
        .animation(.vectorDefault, value: launchDoctorSectionExpanded)
        .animation(.vectorDefault, value: vectorDoctorSectionExpanded)
        .animation(.vectorDefault, value: gamingSectionExpanded)
        .animation(.vectorDefault, value: perfSectionExpanded)
        .animation(.vectorDefault, value: profilesSectionExpanded)
        .animation(.vectorDefault, value: snapshotsSectionExpanded)
        .animation(.vectorDefault, value: presetsSectionExpanded)
        .bottomBar {
            HStack {
                Spacer()
                Button("config.controlPanel") {
                    Task(priority: .userInitiated) {
                        do {
                            try await Wine.control(bottle: bottle)
                        } catch {
                            print("Failed to launch control")
                        }
                    }
                }
                .help("Open Wine Control Panel for advanced Windows-style settings.")
                Button("config.regedit") {
                    Task(priority: .userInitiated) {
                        do {
                            try await Wine.regedit(bottle: bottle)
                        } catch {
                            print("Failed to launch regedit")
                        }
                    }
                }
                .help("Open Registry Editor for manual registry changes in this bottle.")
                Button("config.winecfg") {
                    Task(priority: .userInitiated) {
                        do {
                            try await Wine.cfg(bottle: bottle)
                        } catch {
                            print("Failed to launch winecfg")
                        }
                    }
                }
                .help("Open winecfg for low-level Wine runtime configuration.")
            }
            .padding()
        }
        .navigationTitle("tab.config")
        .onAppear {
            winVersionLoadingState = .success
            gameProfilesDraft = bottle.settings.gameProfiles
            refreshMissingDependencies()

            loadBuildName()

            Task(priority: .userInitiated) {
                do {
                    retinaMode = try await Wine.retinaMode(bottle: bottle)
                    retinaModeLoadingState = .success
                } catch {
                    print(error)
                    retinaModeLoadingState = .failed
                }
            }
            Task(priority: .userInitiated) {
                do {
                    dpiConfig = try await Wine.dpiResolution(bottle: bottle) ?? 0
                    dpiConfigLoadingState = .success
                } catch {
                    print(error)
                    // If DPI has not yet been edited, there will be no registry entry
                    dpiConfigLoadingState = .success
                }
            }
        }
        .onChange(of: gameProfilesDraft) { _, newValue in
            gameProfilesSaveTask?.cancel()
            gameProfilesSaveTask = Task(priority: .utility) {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    bottle.settings.gameProfiles = newValue
                }
            }
        }
        .onChange(of: bottle.settings.windowsVersion) { _, newValue in
            if winVersionLoadingState == .success {
                winVersionLoadingState = .loading
                buildVersionLoadingState = .loading
                Task(priority: .userInitiated) {
                    do {
                        try await Wine.changeWinVersion(bottle: bottle, win: newValue)
                        winVersionLoadingState = .success
                        bottle.settings.windowsVersion = newValue
                        loadBuildName()
                        refreshMissingDependencies()
                    } catch {
                        print(error)
                        winVersionLoadingState = .failed
                    }
                }
            }
        }
        .onChange(of: dpiConfig) {
            if dpiConfigLoadingState == .success {
                Task(priority: .userInitiated) {
                    dpiConfigLoadingState = .modifying
                    do {
                        try await Wine.changeDpiResolution(bottle: bottle, dpi: dpiConfig)
                        dpiConfigLoadingState = .success
                    } catch {
                        print(error)
                        dpiConfigLoadingState = .failed
                    }
                }
            }
        }
        .onDisappear {
            gameProfilesSaveTask?.cancel()
            gameProfilesSaveTask = nil
        }
        .sheet(isPresented: $dlssHealthModalPresented) {
            DLSSRuntimeHealthModalView(
                loading: dlssHealthLoading,
                report: dlssHealthReport,
                snapshotInFlight: snapshotInFlight,
                onRefresh: {
                    refreshDLSSRuntimeHealth()
                },
                onRepair: {
                    enableDLSSRuntimeTranslation()
                }
            )
        }
    }

    func loadBuildName() {
        Task(priority: .userInitiated) {
            do {
                if let buildVersionString = try await Wine.buildVersion(bottle: bottle) {
                    buildVersion = Int(buildVersionString) ?? 0
                } else {
                    buildVersion = 0
                }

                buildVersionLoadingState = .success
            } catch {
                print(error)
                buildVersionLoadingState = .failed
            }
        }
    }

    func runLaunchDoctor() {
        let targetBottle = bottle
        let useAppleIntelligence = launchDoctorUseAppleIntelligence
        launchDoctorLoading = true
        launchDoctorStatusMessage = "Analyzing recent launch logs..."

        Task.detached(priority: .userInitiated) {
            let report = await LaunchIntelligenceService.shared.analyze(
                for: targetBottle,
                preferAppleIntelligence: useAppleIntelligence
            )
            await MainActor.run {
                launchDoctorReport = report
                launchDoctorLoading = false
                launchDoctorStatusMessage = "Latest log: \(report.latestLogName)"
                refreshMissingDependencies()
            }
        }
    }

    private func runVectorDoctor() {
        vectorDoctorLoading = true
        vectorDoctorStatusMessage = "Running Vector Doctor..."

        Task(priority: .userInitiated) {
            let report = await VectorDoctor.report(for: bottle, checkRemote: true)
            vectorDoctorReport = report
            vectorDoctorLoading = false
            vectorDoctorStatusMessage = vectorDoctorSummary(for: report)
        }
    }

    private func exportVectorDoctorReport() {
        vectorDoctorLoading = true
        vectorDoctorStatusMessage = "Preparing diagnostic export..."

        Task(priority: .userInitiated) {
            do {
                let data = try await VectorDoctor.encodedReport(for: bottle, checkRemote: true)
                if let report = try? JSONDecoder().decode(VectorDoctorReport.self, from: data) {
                    vectorDoctorReport = report
                }
                vectorDoctorLoading = false
                presentVectorDoctorSavePanel(data: data)
            } catch {
                vectorDoctorLoading = false
                vectorDoctorStatusMessage = "Failed to export diagnostics: \(error.localizedDescription)"
            }
        }
    }

    private func presentVectorDoctorSavePanel(data: Data) {
        let panel = NSSavePanel()
        panel.title = "Export Vector Doctor Diagnostics"
        panel.nameFieldStringValue = "\(bottle.settings.name)-vector-doctor.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                vectorDoctorStatusMessage = "Exported Vector Doctor diagnostics."
            } catch {
                vectorDoctorStatusMessage = "Failed to save diagnostics: \(error.localizedDescription)"
            }
        }
    }

    private func vectorDoctorSummary(for report: VectorDoctorReport) -> String {
        let blockerCount = report.checks.filter { $0.status == .blocked || $0.status == .failed }.count
        let warningCount = report.checks.filter { $0.status == .warning }.count
        if blockerCount > 0 {
            return "Vector Doctor found \(blockerCount) blocker(s) and \(warningCount) warning(s)."
        }
        if warningCount > 0 {
            return "Vector Doctor found \(warningCount) warning(s)."
        }
        return "Vector Doctor found no major blockers."
    }

    private func applyLaunchDoctorFix(_ fix: LaunchDoctorFixID) {
        switch fix {
        case .switchToCompatibilityRuntime:
            bottle.settings.runtimeSelection = .compatibility
            bottle.settings.customWineBinaryPath = ""
            bottle.settings.customWineserverBinaryPath = ""
            snapshotMessage = "Launch Doctor: switched to compatibility runtime pair."
        case .forceD3D11Compatibility:
            applyD3D11GamePreset()
            snapshotMessage = "Launch Doctor: applied D3D11 compatibility defaults."
        case .installCoreDependencies:
            runWinetricksPreset("dotnet48 vcrun2022 corefonts")
            snapshotMessage = "Launch Doctor: started dependency repair preset."
            refreshMissingDependencies()
        case .steamSafeUiMode:
            bottle.settings.steamUseSafeLaunchFlags = true
            bottle.settings.steamForceNoBrowser = true
            bottle.settings.steamDisableOverlay = true
            bottle.settings.steamResetHTMLCacheOnLaunch = true
            snapshotMessage = "Launch Doctor: enabled Steam safe UI mode."
        case .enableDebugLogs:
            bottle.settings.logProfile = .debug
            snapshotMessage = "Launch Doctor: log profile set to Debug."
        case .enableSafeMultiplayerMode:
            bottle.settings.safeMultiplayerMode = true
            bottle.settings.allowUnsupportedAntiCheatLaunches = false
            bottle.settings.antiCheatPreflightMode = .block
            snapshotMessage = "Launch Doctor: safe multiplayer mode enabled."
        }
    }

    private func vectorDoctorCheckRow(_ check: VectorDoctorCheck) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: vectorDoctorSymbol(for: check.status))
                .foregroundStyle(vectorDoctorColor(for: check.status))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(check.title)
                    .fontWeight(.semibold)
                Text(check.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private func vectorDoctorSymbol(for status: VectorDoctorCheckStatus) -> String {
        switch status {
        case .pass:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .blocked:
            return "lock.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private func vectorDoctorColor(for status: VectorDoctorCheckStatus) -> Color {
        switch status {
        case .pass:
            return .green
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .blocked, .failed:
            return .red
        }
    }

    private func exportProtectedMultiplayerReport() {
        let appID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundle = VectorProtectedTitlePolicyEngine.studioReviewBundle(for: bottle, steamAppID: appID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(bundle) else {
            snapshotMessage = "Failed to encode protected multiplayer report."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export Studio Review Report"
        panel.nameFieldStringValue = "\(bottle.settings.name)-protected-multiplayer-report.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                snapshotMessage = "Exported protected multiplayer report."
            } catch {
                snapshotMessage = "Failed to export report: \(error.localizedDescription)"
            }
        }
    }

    private func refreshMissingDependencies() {
        missingDependencyFixes = MissingDependencyDetector.detect(for: bottle)
    }

    private func applyMissingDependencyFix(_ fixID: MissingDependencyFixID) {
        let plan = DependencyRepairPlan(
            fixIDs: Set([fixID]),
            includeRuntimeDLLRepair: fixID.requiresRuntimeMirrorRepair
        )
        performDependencyRepair(
            plan,
            action: fixID.repairActionDescription,
            trackEnvironmentRepair: false
        )
    }

    private func repairMinecraftDungeonsSignInFlow() {
        if VectorWineInstaller.steamCompatibilityWineBinary() != nil,
           VectorWineInstaller.steamCompatibilityWineserverBinary() != nil {
            bottle.settings.runtimeSelection = .compatibility
            bottle.settings.customWineBinaryPath = ""
            bottle.settings.customWineserverBinaryPath = ""
        }
        let targetBottle = bottle
        runWinetricksPreset("edgewebview2")
        bottle.settings.steamResetHTMLCacheOnLaunch = true
        clearMinecraftDungeonsAuthWebCache()
        clearSteamHTMLCacheResetMarker()
        Task.detached(priority: .userInitiated) {
            let notes = await Self.refreshMinecraftDungeonsMicrosoftAuthState(for: targetBottle)
            guard !notes.isEmpty else {
                return
            }
            await MainActor.run {
                snapshotMessage = "Minecraft Dungeons auth reset: \(notes.joined(separator: ". "))."
            }
        }
        snapshotMessage = "Started Microsoft sign-in repair (compat runtime + WebView2 + Xbox auth reset + callback bridge + auth cache reset)."
    }

    private func clearMinecraftDungeonsAuthWebCache() {
        let usersRoot = bottle.url
            .appending(path: "drive_c")
            .appending(path: "users")
        guard let users = try? FileManager.default.contentsOfDirectory(
            at: usersRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for user in users {
            let candidateRoots = [
                user
                    .appending(path: "AppData")
                    .appending(path: "Local")
                    .appending(path: "Dungeons"),
                user
                    .appending(path: "AppData")
                    .appending(path: "LocalLow")
                    .appending(path: "Mojang Studios")
                    .appending(path: "Dungeons")
            ]

            for root in candidateRoots {
                guard FileManager.default.fileExists(atPath: root.path(percentEncoded: false)),
                      let enumerator = FileManager.default.enumerator(
                          at: root,
                          includingPropertiesForKeys: [.isDirectoryKey],
                          options: [.skipsHiddenFiles]
                      ) else {
                    continue
                }

                for case let entryURL as URL in enumerator {
                    let name = entryURL.lastPathComponent.lowercased()
                    guard name.hasPrefix("webcache") else {
                        continue
                    }
                    do {
                        try FileManager.default.removeItem(at: entryURL)
                    } catch {
                        Logger.wineKit.warning(
                            "Failed to remove Minecraft Dungeons auth cache at \(entryURL.path(percentEncoded: false), privacy: .public)"
                        )
                    }
                }
            }
        }
    }

    private func clearSteamHTMLCacheResetMarker() {
        let markerCandidates = [
            bottle.url
                .appending(path: "drive_c")
                .appending(path: "Program Files (x86)")
                .appending(path: "Steam")
                .appending(path: ".vector-steam-htmlcache-reset-v4"),
            bottle.url
                .appending(path: "drive_c")
                .appending(path: "Program Files")
                .appending(path: "Steam")
                .appending(path: ".vector-steam-htmlcache-reset-v4")
        ]

        for markerURL in markerCandidates {
            let path = markerURL.path(percentEncoded: false)
            guard FileManager.default.fileExists(atPath: path) else {
                continue
            }
            do {
                try FileManager.default.removeItem(at: markerURL)
            } catch {
                Logger.wineKit.warning(
                    "Failed to remove Steam htmlcache reset marker at \(path, privacy: .public)"
                )
            }
        }
    }

    private static func refreshMinecraftDungeonsMicrosoftAuthState(for bottle: Bottle) async -> [String] {
        var notes: [String] = []

        let deletedCredentials = await clearMinecraftDungeonsXboxCredentials(in: bottle)
        if deletedCredentials > 0 {
            notes.append("cleared \(deletedCredentials) stale Xbox credential entries")
        }

        let registeredSchemes = await registerMinecraftDungeonsProtocolHandlers(in: bottle)
        if registeredSchemes > 0 {
            notes.append("registered \(registeredSchemes) Microsoft/Xbox callback handlers")
        }

        return notes
    }

    private static func clearMinecraftDungeonsXboxCredentials(in bottle: Bottle) async -> Int {
        let userRegistryURL = bottle.url.appending(path: "user.reg")
        guard let contents = try? String(contentsOf: userRegistryURL, encoding: .utf8) else {
            return 0
        }

        let keys = contents
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> String? in
                guard line.hasPrefix("[Software\\\\Wine\\\\Credential Manager\\\\Generic: Xbl|"),
                      let endIndex = line.firstIndex(of: "]") else {
                    return nil
                }
                let key = line[line.index(after: line.startIndex)..<endIndex]
                return "HKCU\\\(key.replacingOccurrences(of: #"\\\\"#, with: #"\"#))"
            }

        var deletedCount = 0
        for key in Set(keys) {
            do {
                _ = try await Wine.runWine(
                    ["reg", "delete", key, "/f"],
                    bottle: bottle,
                    collectOutput: false
                )
                deletedCount += 1
            } catch {
                Logger.wineKit.warning(
                    "Failed to remove Xbox credential at \(key, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        return deletedCount
    }

    private static func registerMinecraftDungeonsProtocolHandlers(in bottle: Bottle) async -> Int {
        let steamSchemes = [
            "xbox",
            "xal",
            "xbl",
            "msxbl",
            "ms-xbl-multiplayer",
            "ms-xbl-3d8b930f",
            "ms-xal-3d8b930f"
        ]
        let edgeSchemes = ["microsoft-edge", "microsoft-edge-userdata"]
        let steamCommand = #""C:\Program Files (x86)\Steam\steam.exe" -- "%1""#

        var registeredCount = 0
        for scheme in steamSchemes {
            registeredCount += await writeProtocolHandler(
                scheme: scheme,
                command: steamCommand,
                bottle: bottle
            )
        }

        if let edgeCommand = resolveMinecraftDungeonsEdgeProtocolCommand(in: bottle) {
            for scheme in edgeSchemes {
                registeredCount += await writeProtocolHandler(
                    scheme: scheme,
                    command: edgeCommand,
                    bottle: bottle
                )
            }
        }

        return registeredCount
    }

    private static func writeProtocolHandler(
        scheme: String,
        command: String,
        bottle: Bottle
    ) async -> Int {
        let baseKey = "HKCU\\Software\\Classes\\\(scheme)"

        do {
            _ = try await Wine.runWine(
                [
                    "reg",
                    "add",
                    baseKey,
                    "/ve",
                    "/t",
                    "REG_SZ",
                    "/d",
                    "URL:\(scheme) protocol",
                    "/f"
                ],
                bottle: bottle,
                collectOutput: false
            )
            _ = try await Wine.runWine(
                [
                    "reg",
                    "add",
                    baseKey,
                    "/v",
                    "URL Protocol",
                    "/t",
                    "REG_SZ",
                    "/d",
                    "",
                    "/f"
                ],
                bottle: bottle,
                collectOutput: false
            )
            _ = try await Wine.runWine(
                [
                    "reg",
                    "add",
                    "\(baseKey)\\Shell\\Open\\Command",
                    "/ve",
                    "/t",
                    "REG_SZ",
                    "/d",
                    command,
                    "/f"
                ],
                bottle: bottle,
                collectOutput: false
            )
            return 1
        } catch {
            Logger.wineKit.warning(
                "Failed to register \(scheme, privacy: .public) protocol: \(error.localizedDescription, privacy: .public)"
            )
            return 0
        }
    }

    private static func resolveMinecraftDungeonsEdgeProtocolCommand(in bottle: Bottle) -> String? {
        let fileManager = FileManager.default
        let installations = [
            (
                bottle.url
                    .appending(path: "drive_c")
                    .appending(path: "Program Files (x86)")
                    .appending(path: "Microsoft")
                    .appending(path: "EdgeWebView")
                    .appending(path: "Application"),
                #"C:\Program Files (x86)\Microsoft\EdgeWebView\Application"#
            ),
            (
                bottle.url
                    .appending(path: "drive_c")
                    .appending(path: "Program Files (x86)")
                    .appending(path: "Microsoft")
                    .appending(path: "EdgeCore"),
                #"C:\Program Files (x86)\Microsoft\EdgeCore"#
            )
        ]

        for (hostRoot, windowsRoot) in installations {
            guard let versionURLs = try? fileManager.contentsOfDirectory(
                at: hostRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            let versionNames = versionURLs.compactMap { url -> String? in
                guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                      values.isDirectory == true else {
                    return nil
                }
                let version = url.lastPathComponent
                guard isEdgeVersionDirectoryName(version) else {
                    return nil
                }

                let executableURL = url.appending(path: "msedge.exe")
                let executablePath = executableURL.path(percentEncoded: false)
                guard fileManager.fileExists(atPath: executablePath) else {
                    return nil
                }

                return version
            }.sorted {
                $0.localizedStandardCompare($1) == .orderedDescending
            }

            guard let version = versionNames.first else {
                continue
            }

            let executableURL = hostRoot.appending(path: version).appending(path: "msedge.exe")
            let executablePath = executableURL.path(percentEncoded: false)
            guard fileManager.fileExists(atPath: executablePath) else {
                continue
            }

            return
                #""\#(windowsRoot)\\\#(version)\msedge.exe" --disable-gpu --disable-gpu-compositing "#
                + #"--disable-accelerated-video-decode --disable-low-latency-dxva "#
                + #"--disable-zero-copy-dxgi-video --single-argument "%1""#
        }

        return nil
    }

    private static func isEdgeVersionDirectoryName(_ name: String) -> Bool {
        guard name.first?.isNumber == true, name.contains(".") else {
            return false
        }

        return name.allSatisfy { character in
            character.isNumber || character == "."
        }
    }

    private func runEnvironmentRepair() {
        let detectedFixIDs = Set(missingDependencyFixes.map(\.id))
        let plan = DependencyRepairPlan(
            fixIDs: detectedFixIDs,
            includeRuntimeDLLRepair: true
        )
        performDependencyRepair(plan, action: "environment repair", trackEnvironmentRepair: true)
    }

    private func presentDLSSRuntimeHealthModal() {
        dlssHealthModalPresented = true
        refreshDLSSRuntimeHealth()
    }

    private func refreshDLSSRuntimeHealth() {
        let targetBottle = bottle
        dlssHealthLoading = true
        Task.detached(priority: .userInitiated) {
            let report = await Self.inspectDLSSRuntimeHealth(for: targetBottle)
            await MainActor.run {
                dlssHealthReport = report
                dlssHealthLoading = false
            }
        }
    }

    private static func inspectDLSSRuntimeHealth(for bottle: Bottle) -> DLSSRuntimeHealthReport {
        let fileManager = FileManager.default
        var items: [DLSSRuntimeHealthItem] = []

        let payloadRoot = VectorWineInstaller.libraryFolder.appending(path: "DXMT")
        let payloadPaths = [
            payloadRoot.appending(path: "x86_64-windows").appending(path: "nvapi64.dll"),
            payloadRoot.appending(path: "x86_64-windows").appending(path: "nvngx.dll"),
            payloadRoot.appending(path: "x86_64-unix").appending(path: "winemetal.so")
        ]
        let missingPayloadPaths = payloadPaths.filter {
            !fileManager.fileExists(atPath: $0.path(percentEncoded: false))
        }
        items.append(
            DLSSRuntimeHealthItem(
                title: "DXMT payload files",
                detail: missingPayloadPaths.isEmpty
                    ? "DXMT payload contains required DLSS translation artifacts."
                    : "Missing: \(missingPayloadPaths.map { $0.lastPathComponent }.joined(separator: ", "))",
                status: missingPayloadPaths.isEmpty ? .healthy : .missing
            )
        )

        let runtimeWineBinary = selectedRuntimeWineBinaryForHealth(for: bottle)
        let runtimeWineFolder = resolveRuntimeWineFolderForHealth(
            using: runtimeWineBinary,
            fileManager: fileManager
        )
        let runtimePaths = [
            runtimeWineFolder.appending(path: "x86_64-windows").appending(path: "nvapi64.dll"),
            runtimeWineFolder.appending(path: "x86_64-windows").appending(path: "nvngx.dll")
        ]
        let missingRuntimePaths = runtimePaths.filter {
            !fileManager.fileExists(atPath: $0.path(percentEncoded: false))
        }
        items.append(
            DLSSRuntimeHealthItem(
                title: "Runtime DLL deployment",
                detail: missingRuntimePaths.isEmpty
                    ? "Runtime has DLSS translation DLLs in \(runtimeWineFolder.path(percentEncoded: false))."
                    : "Missing in runtime: \(missingRuntimePaths.map { $0.lastPathComponent }.joined(separator: ", "))",
                status: missingRuntimePaths.isEmpty ? .healthy : .missing
            )
        )

        let windowsDirectory = bottle.url.appending(path: "drive_c").appending(path: "windows")
        let system32Paths = [
            windowsDirectory.appending(path: "system32").appending(path: "nvapi64.dll"),
            windowsDirectory.appending(path: "system32").appending(path: "nvngx.dll")
        ]
        let missingSystem32Paths = system32Paths.filter {
            !fileManager.fileExists(atPath: $0.path(percentEncoded: false))
        }
        items.append(
            DLSSRuntimeHealthItem(
                title: "Bottle system32 deployment",
                detail: missingSystem32Paths.isEmpty
                    ? "Bottle system32 includes DLSS translation DLLs."
                    : "Missing in system32: \(missingSystem32Paths.map { $0.lastPathComponent }.joined(separator: ", "))",
                status: missingSystem32Paths.isEmpty ? .healthy : .missing
            )
        )

        items.append(
            DLSSRuntimeHealthItem(
                title: "DLSS translation toggle",
                detail: bottle.settings.dlssRuntimeTranslationEnabled
                    ? "Enabled."
                    : "Disabled. Enable this in Compatibility settings.",
                status: bottle.settings.dlssRuntimeTranslationEnabled ? .healthy : .warning
            )
        )
        items.append(
            DLSSRuntimeHealthItem(
                title: "Graphics backend mode",
                detail: bottle.settings.graphicsBackendMode == .dxmt
                    ? "DXMT selected."
                    : "Current backend is \(bottle.settings.graphicsBackendMode.rawValue). DXMT is recommended.",
                status: bottle.settings.graphicsBackendMode == .dxmt ? .healthy : .warning
            )
        )

        let customOverrides = bottle.settings.customDLLOverrides
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if bottle.settings.dllOverridesPolicy == .custom, !customOverrides.isEmpty {
            let hasNVAPIDisable = containsDisabledOverride(module: "nvapi", in: customOverrides)
                || containsDisabledOverride(module: "nvapi64", in: customOverrides)
            let hasNVNGXDisable = containsDisabledOverride(module: "nvngx", in: customOverrides)
                || containsDisabledOverride(module: "nvngx_dlss", in: customOverrides)
                || containsDisabledOverride(module: "sl.dlss", in: customOverrides)
            items.append(
                DLSSRuntimeHealthItem(
                    title: "Custom DLL overrides",
                    detail: hasNVAPIDisable || hasNVNGXDisable
                        ? "Custom overrides disable NVAPI/NVNGX modules. This can block DLSS translation."
                        : "No DLSS-blocking custom overrides detected.",
                    status: hasNVAPIDisable || hasNVNGXDisable ? .warning : .healthy
                )
            )
        }

        let missingCount = items.filter { $0.status == .missing }.count
        let warningCount = items.filter { $0.status == .warning }.count
        let summary: String
        if missingCount > 0 {
            summary = "DLSS runtime translation is not ready. Repair is recommended."
        } else if warningCount > 0 {
            summary = "DLSS runtime translation is mostly ready, with configuration warnings."
        } else {
            summary = "DLSS runtime translation is healthy for this bottle."
        }

        return DLSSRuntimeHealthReport(generatedAt: Date(), summary: summary, items: items)
    }

    nonisolated fileprivate static func selectedRuntimeWineBinaryForHealth(for bottle: Bottle) -> URL {
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
            let customPath = bottle.settings.customWineBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if FileManager.default.isExecutableFile(atPath: customPath) {
                return URL(filePath: customPath)
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

    nonisolated fileprivate static func resolveRuntimeWineFolderForHealth(
        using runtimeWineBinary: URL,
        fileManager: FileManager
    ) -> URL {
        let runtimeRoot = runtimeWineBinary.deletingLastPathComponent().deletingLastPathComponent()
        let runtimeWineFolder = runtimeRoot.appending(path: "lib").appending(path: "wine")
        if fileManager.fileExists(atPath: runtimeWineFolder.path(percentEncoded: false)) {
            return runtimeWineFolder
        }

        return VectorWineInstaller.libraryFolder
            .appending(path: "Wine")
            .appending(path: "lib")
            .appending(path: "wine")
    }

    private static func containsDisabledOverride(module: String, in overrides: String) -> Bool {
        let entries = overrides.split(separator: ";", omittingEmptySubsequences: true)
        for rawEntry in entries {
            let entry = rawEntry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !entry.isEmpty else { continue }
            let parts = entry.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let modules = parts[0]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            guard modules.contains(module.lowercased()) else { continue }
            let overrideMode = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if overrideMode.contains("d") {
                return true
            }
        }
        return false
    }

    private func enableDLSSRuntimeTranslation() {
        let targetBottle = bottle
        snapshotInFlight = true
        Task.detached(priority: .userInitiated) {
            let snapshotNote = await Self.createAutoSnapshotIfEnabled(
                for: targetBottle,
                action: "DLSS runtime translation setup"
            )
            do {
                try await Wine.enableDLSSRuntimeTranslation(bottle: targetBottle)
                await MainActor.run {
                    targetBottle.settings.graphicsBackendMode = .dxmt
                    targetBottle.settings.dlssRuntimeTranslationEnabled = true
                    targetBottle.settings.fsrEnabled = true
                    if targetBottle.settings.dllOverridesPolicy == .disableNvapi {
                        targetBottle.settings.dllOverridesPolicy = .auto
                    }
                    sanitizeDLSSDisabledOverrides(in: targetBottle)
                    snapshotMessage = "\(snapshotNote)Enabled DXMT DLSS runtime translation."
                    snapshotInFlight = false
                    refreshMissingDependencies()
                    if dlssHealthModalPresented {
                        refreshDLSSRuntimeHealth()
                    }
                }
            } catch {
                await MainActor.run {
                    snapshotMessage = "\(snapshotNote)DLSS runtime translation failed: \(error.localizedDescription)"
                    snapshotInFlight = false
                    refreshMissingDependencies()
                    if dlssHealthModalPresented {
                        refreshDLSSRuntimeHealth()
                    }
                }
            }
        }
    }

    private func performDependencyRepair(
        _ plan: DependencyRepairPlan,
        action: String,
        trackEnvironmentRepair: Bool
    ) {
        guard !plan.isEmpty else {
            snapshotMessage = "No missing dependency repairs were needed."
            return
        }

        let targetBottle = bottle
        if trackEnvironmentRepair {
            environmentRepairInFlight = true
        }
        snapshotInFlight = true

        Task.detached(priority: .userInitiated) {
            let snapshotNote = await Self.createAutoSnapshotIfEnabled(for: targetBottle, action: action)
            var repairNotes: [String] = []

            if plan.repairRuntimeDLLMirror {
                do {
                    try Wine.repairRuntimeSystemDLLMirror(for: targetBottle)
                    repairNotes.append("validated the runtime DLL mirror")
                } catch {
                    repairNotes.append("runtime DLL validation failed: \(error.localizedDescription)")
                }
            }

            if plan.enableDXVKPayload {
                do {
                    try Wine.enableDXVK(bottle: targetBottle)
                    repairNotes.append("reinstalled the DXVK DLL payload")
                } catch {
                    repairNotes.append("DXVK payload repair failed: \(error.localizedDescription)")
                }
            }

            if plan.enableDXMTPayload {
                do {
                    try await Wine.enableDXMT(bottle: targetBottle)
                    repairNotes.append("validated the DXMT payload")
                } catch {
                    repairNotes.append("DXMT payload repair failed: \(error.localizedDescription)")
                }
            }

            if plan.enableDLSSRuntimeTranslation {
                do {
                    try await Wine.enableDLSSRuntimeTranslation(bottle: targetBottle)
                    await MainActor.run {
                        targetBottle.settings.graphicsBackendMode = .dxmt
                        targetBottle.settings.dlssRuntimeTranslationEnabled = true
                        targetBottle.settings.fsrEnabled = true
                        if targetBottle.settings.dllOverridesPolicy == .disableNvapi {
                            targetBottle.settings.dllOverridesPolicy = .auto
                        }
                        sanitizeDLSSDisabledOverrides(in: targetBottle)
                    }
                    repairNotes.append("validated the DLSS translation runtime")
                } catch {
                    repairNotes.append("DLSS translation repair failed: \(error.localizedDescription)")
                }
            }

            if plan.enableMediaPlaybackCompatibility {
                await MainActor.run {
                    targetBottle.settings.mediaPlaybackCompatibilityMode = true
                }
                repairNotes.append("enabled media playback compatibility mode")
            }

            if plan.resetMinecraftAuthCaches {
                await MainActor.run {
                    targetBottle.settings.steamResetHTMLCacheOnLaunch = true
                    clearMinecraftDungeonsAuthWebCache()
                    clearSteamHTMLCacheResetMarker()
                }
                let authNotes = await Self.refreshMinecraftDungeonsMicrosoftAuthState(for: targetBottle)
                if authNotes.isEmpty {
                    repairNotes.append("reset cached Microsoft auth web data")
                } else {
                    repairNotes.append(
                        "reset cached Microsoft auth web data and \(authNotes.joined(separator: ", "))"
                    )
                }
            }

            if let winetricksCommand = plan.winetricksCommand {
                await Winetricks.runCommand(command: winetricksCommand, bottle: targetBottle)
                repairNotes.append("started Winetricks repair: \(winetricksCommand)")
            }

            await MainActor.run {
                refreshMissingDependencies()
                if dlssHealthModalPresented {
                    refreshDLSSRuntimeHealth()
                }

                let details = repairNotes.joined(separator: ". ")
                snapshotMessage = details.isEmpty
                    ? "\(snapshotNote)Repair flow completed."
                    : "\(snapshotNote)Repair flow completed: \(details)."
                snapshotInFlight = false
                if trackEnvironmentRepair {
                    environmentRepairInFlight = false
                }
            }
        }
    }

    private func sanitizeDLSSDisabledOverrides(in bottle: Bottle) {
        guard bottle.settings.dllOverridesPolicy == .custom else {
            return
        }

        let disabledNames: Set<String> = [
            "nvapi",
            "nvapi64",
            "nvngx",
            "_nvngx",
            "nvngx_dlss",
            "nvngx_dlssd",
            "nvngx_dlssg",
            "sl.interposer",
            "sl.common",
            "sl.dlss",
            "sl.dlss_g",
            "sl.deepdvc",
            "sl.reflex",
            "sl.pcl"
        ]
        let sanitized = stripDLLOverrides(
            bottle.settings.customDLLOverrides,
            removing: disabledNames
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        bottle.settings.customDLLOverrides = sanitized
        if sanitized.isEmpty {
            bottle.settings.dllOverridesPolicy = .auto
        }
    }

    private func stripDLLOverrides(_ value: String, removing names: Set<String>) -> String {
        guard !value.isEmpty else {
            return value
        }

        let entries = value.split(separator: ";", omittingEmptySubsequences: true)
        var rebuilt: [String] = []
        for rawEntry in entries {
            let entry = rawEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !entry.isEmpty else { continue }

            let parts = entry.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                if !names.contains(entry.lowercased()) {
                    rebuilt.append(entry)
                }
                continue
            }

            let moduleNames = parts[0]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let filteredModules = moduleNames.filter { !names.contains($0.lowercased()) }
            guard !filteredModules.isEmpty else {
                continue
            }

            let overrideValue = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            rebuilt.append("\(filteredModules.joined(separator: ","))=\(overrideValue)")
        }

        return rebuilt.joined(separator: ";")
    }

    private func findingSymbol(for severity: LaunchDoctorSeverity) -> String {
        switch severity {
        case .critical:
            return "xmark.octagon.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    private func findingColor(for severity: LaunchDoctorSeverity) -> Color {
        switch severity {
        case .critical:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }

    func healthScoreColor(_ score: Int) -> Color {
        switch score {
        case 80...:
            return .green
        case 60...79:
            return .yellow
        case 40...59:
            return .orange
        default:
            return .red
        }
    }

    func runtimeSelectionTitle(_ selection: WineRuntimeSelection) -> String {
        switch selection {
        case .auto:
            return "Auto"
        case .bundled:
            return "Bundled Runtime"
        case .compatibility:
            return "Compatibility Runtime"
        case .crossover:
            return "CrossOver Runtime"
        case .custom:
            return "Custom Runtime"
        }
    }

    func graphicsBackendTitle(_ mode: GraphicsBackendMode) -> String {
        switch mode {
        case .auto:
            return "Auto"
        case .dxvk:
            return "DXVK"
        case .dxmt:
            return "DXMT (D3D10/11)"
        case .wined3d:
            return "WineD3D"
        case .d3dMetal:
            return "D3DMetal"
        }
    }

    func runtimeDLLSyncModeTitle(_ mode: RuntimeDLLSyncMode) -> String {
        switch mode {
        case .missingOnly:
            return "Missing Only"
        case .verifyOnly:
            return "Verify (Warn)"
        case .verifyAndRepair:
            return "Verify + Repair"
        }
    }

    func dllOverridesPolicyTitle(_ policy: DLLOverridesPolicy) -> String {
        switch policy {
        case .auto:
            return "Auto"
        case .disableNvapi:
            return "Disable NVAPI"
        case .custom:
            return "Custom"
        }
    }

    func antiCheatModeTitle(_ mode: AntiCheatPreflightMode) -> String {
        switch mode {
        case .off:
            return "Off"
        case .warn:
            return "Warn"
        case .block:
            return "Block"
        }
    }

    func logProfileTitle(_ profile: BottleLogProfile) -> String {
        switch profile {
        case .quiet:
            return "Quiet"
        case .debug:
            return "Debug"
        case .deepDebug:
            return "Deep Debug"
        }
    }

    func profileBinding(_ index: Int, keyPath: WritableKeyPath<BottleGameProfile, String>) -> Binding<String> {
        Binding(
            get: {
                guard gameProfilesDraft.indices.contains(index) else { return "" }
                return gameProfilesDraft[index][keyPath: keyPath]
            },
            set: { newValue in
                guard gameProfilesDraft.indices.contains(index) else { return }
                gameProfilesDraft[index][keyPath: keyPath] = newValue
            }
        )
    }

    func profileEnvironmentBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard gameProfilesDraft.indices.contains(index) else { return "" }
                let values = gameProfilesDraft[index].environment
                    .sorted(by: { $0.key.lowercased() < $1.key.lowercased() })
                    .map { "\($0.key)=\($0.value)" }
                return values.joined(separator: ";")
            },
            set: { newValue in
                guard gameProfilesDraft.indices.contains(index) else { return }

                var parsed: [String: String] = [:]
                let pairs = newValue
                    .split(whereSeparator: { $0 == ";" || $0 == "\n" })
                    .map { String($0) }
                for pair in pairs {
                    let components = pair.split(separator: "=", maxSplits: 1).map(String.init)
                    guard components.count == 2 else { continue }
                    let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !key.isEmpty else { continue }
                    parsed[key] = value
                }

                gameProfilesDraft[index].environment = parsed
            }
        )
    }

    func runSnapshotCreate() {
        snapshotInFlight = true
        let targetBottle = bottle
        Task.detached(priority: .userInitiated) {
            do {
                let archiveURL = try targetBottle.createSnapshotArchive()
                await MainActor.run {
                    snapshotMessage = "Created \(archiveURL.lastPathComponent)"
                    snapshotInFlight = false
                }
            } catch {
                await MainActor.run {
                    snapshotMessage = "Snapshot failed: \(error.localizedDescription)"
                    snapshotInFlight = false
                }
            }
        }
    }

    static func createAutoSnapshotIfEnabled(for targetBottle: Bottle, action: String) async -> String {
        guard targetBottle.settings.autoSnapshotBeforeRiskyChanges else {
            return ""
        }

        do {
            let archiveURL = try targetBottle.createSnapshotArchive()
            return "Auto snapshot \(archiveURL.lastPathComponent) before \(action). "
        } catch {
            return "Auto snapshot failed before \(action): \(error.localizedDescription). "
        }
    }

    func createAutoSnapshotIfEnabled(action: String) -> String {
        guard bottle.settings.autoSnapshotBeforeRiskyChanges else {
            return ""
        }

        do {
            let archiveURL = try bottle.createSnapshotArchive()
            return "Auto snapshot \(archiveURL.lastPathComponent) before \(action). "
        } catch {
            return "Auto snapshot failed before \(action): \(error.localizedDescription). "
        }
    }

    func runSnapshotRestore() {
        snapshotInFlight = true
        let targetBottle = bottle
        Task.detached(priority: .userInitiated) {
            do {
                let archiveURL = try targetBottle.restoreLatestSnapshotArchive()
                await MainActor.run {
                    snapshotMessage = "Restored \(archiveURL.lastPathComponent)"
                    snapshotInFlight = false
                }
                await MainActor.run {
                    BottleVM.shared.loadBottles()
                }
            } catch {
                await MainActor.run {
                    snapshotMessage = "Restore failed: \(error.localizedDescription)"
                    snapshotInFlight = false
                }
            }
        }
    }

    func runWinetricksPreset(_ command: String) {
        let targetBottle = bottle
        snapshotInFlight = true
        Task.detached(priority: .userInitiated) {
            let snapshotNote = await Self.createAutoSnapshotIfEnabled(for: targetBottle, action: "Winetricks preset")
            await Winetricks.runCommand(command: command, bottle: targetBottle)
            await MainActor.run {
                snapshotMessage = "\(snapshotNote)Started Winetricks preset: \(command)"
                snapshotInFlight = false
            }
        }
    }

    func runDispatchSync(forceRefresh: Bool) {
        let targetBottle = bottle
        snapshotInFlight = true
        Task.detached(priority: .userInitiated) {
            let snapshotNote = await Self.createAutoSnapshotIfEnabled(for: targetBottle, action: "dispatch sync")
            await BottleGamingModeManager.syncDispatchProfiles(for: targetBottle, forceRefresh: forceRefresh)
            await MainActor.run {
                snapshotMessage = "\(snapshotNote)Dispatch patches synced."
                snapshotInFlight = false
            }
        }
    }

    func runLauncherBootstrap() {
        let targetBottle = bottle
        snapshotInFlight = true
        Task.detached(priority: .userInitiated) {
            let snapshotNote = await Self.createAutoSnapshotIfEnabled(for: targetBottle, action: "launcher bootstrap")
            if targetBottle.settings.gamingAutoApplyKnownGamePatches {
                BottleGamingModeManager.ensureKnownGameProfiles(in: targetBottle)
            }
            await BottleGamingModeManager.installGamingLaunchersIfEnabled(for: targetBottle)
            await MainActor.run {
                targetBottle.updateInstalledPrograms()
                snapshotMessage = "\(snapshotNote)Launcher bootstrap complete."
                snapshotInFlight = false
            }
        }
    }

    func applyParcelSimulatorD3D11Preset() {
        runPresetWithSnapshot(action: "Parcel Simulator preset") { snapshotNote in
            applyD3D11GameBaseSettings()
            bottle.settings.steamDisableOverlay = true
            bottle.settings.activeSteamAppID = "2424010"

            var profiles = bottle.settings.gameProfiles
            let parcelName = "Parcel Simulator Builtin D3D11"
            var parcelProfile = BottleGameProfile(
                name: parcelName,
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
            )
            if let index = profiles.firstIndex(where: { $0.name.caseInsensitiveCompare(parcelName) == .orderedSame }) {
                parcelProfile.id = profiles[index].id
                profiles[index] = parcelProfile
            } else {
                profiles.append(parcelProfile)
            }

            bottle.settings.gameProfiles = profiles
            gameProfilesDraft = profiles
            snapshotMessage = "\(snapshotNote)Applied Parcel Simulator D3D11 preset."
        }
    }

    func applyContentWarningPreset() {
        runPresetWithSnapshot(action: "Content Warning preset") { snapshotNote in
            applyD3D11GameBaseSettings()
            bottle.settings.steamDisableOverlay = true
            bottle.settings.activeSteamAppID = "2881650"

            var profiles = bottle.settings.gameProfiles
            let profileName = "Content Warning Builtin D3D11"
            var profile = BottleGameProfile(
                name: profileName,
                executableMatch: "content warning.exe",
                steamAppID: "2881650",
                arguments: "-force-d3d11",
                environment: [
                    "WINEDLLOVERRIDES": "dxgi,d3d11,d3d10core,d3d9=b;nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            )
            if let index = profiles.firstIndex(where: { existing in
                existing.name.caseInsensitiveCompare(profileName) == .orderedSame
                    || (existing.executableMatch.caseInsensitiveCompare("content warning.exe") == .orderedSame
                        && existing.steamAppID == "2881650")
            }) {
                profile.id = profiles[index].id
                profiles[index] = profile
            } else {
                profiles.append(profile)
            }

            bottle.settings.gameProfiles = profiles
            gameProfilesDraft = profiles
            snapshotMessage = "\(snapshotNote)Applied Content Warning compatibility preset."
        }
    }

    func applySilentHillFD3D11Preset() {
        runPresetWithSnapshot(action: "Silent Hill f preset") { snapshotNote in
            bottle.settings.runtimeSelection = .auto
            bottle.settings.graphicsBackendMode = .dxvk
            bottle.settings.dxvk = true
            bottle.settings.dxvkAsync = true
            bottle.settings.shaderCacheEnabled = true
            bottle.settings.forceD3D11Compatibility = true
            bottle.settings.dllOverridesPolicy = .auto
            bottle.settings.steamDisableOverlay = true
            bottle.settings.activeSteamAppID = "2947440"

            var profiles = bottle.settings.gameProfiles
            let profileName = "Silent Hill f Builtin Profile"
            var profile = BottleGameProfile(
                name: profileName,
                executableMatch: "silenthillf-win64-shipping.exe",
                steamAppID: "2947440",
                arguments: "-force-d3d11 -dx11 -d3d11",
                environment: [
                    "WINEDLLOVERRIDES": "dxgi,d3d11,d3d10core,d3d9=n,b;nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            )

            if let index = profiles.firstIndex(where: { existing in
                existing.name.caseInsensitiveCompare(profileName) == .orderedSame
                    || (existing.executableMatch.caseInsensitiveCompare("silenthillf-win64-shipping.exe") == .orderedSame
                        && existing.steamAppID == "2947440")
            }) {
                profile.id = profiles[index].id
                profiles[index] = profile
            } else {
                profiles.append(profile)
            }

            bottle.settings.gameProfiles = profiles
            gameProfilesDraft = profiles
            snapshotMessage = "\(snapshotNote)Applied Silent Hill f compatibility preset."
        }
    }

    func applyD3D11GamePreset(createSnapshot: Bool = true) {
        runPresetWithSnapshot(action: "D3D11 preset", createSnapshot: createSnapshot) { snapshotNote in
            applyD3D11GameBaseSettings()
            snapshotMessage = "\(snapshotNote)Applied D3D11 game preset."
        }
    }

    func applyHighOnLife2Preset() {
        runPresetWithSnapshot(action: "HighOnLife2 preset") { snapshotNote in
            bottle.settings.runtimeSelection = .bundled
            bottle.settings.graphicsBackendMode = .d3dMetal
            bottle.settings.dxvk = false
            bottle.settings.dxvkAsync = false
            bottle.settings.shaderCacheEnabled = true
            bottle.settings.forceD3D11Compatibility = false
            bottle.settings.dllOverridesPolicy = .auto
            bottle.settings.steamDisableOverlay = true
            bottle.settings.activeSteamAppID = "2069250"

            let wineBinary = VectorWineInstaller.binFolder
                .appending(path: "wine64")
                .path(percentEncoded: false)
            let wineserverBinary = VectorWineInstaller.binFolder
                .appending(path: "wineserver")
                .path(percentEncoded: false)

            var profiles = bottle.settings.gameProfiles
            let profileName = "HighOnLife2 Builtin D3D12"
            var profile = BottleGameProfile(
                name: profileName,
                executableMatch: "highonlife2-win64-shipping.exe",
                steamAppID: "2069250",
                arguments: "-dx12 -ngxdisable",
                environment: [
                    "WINEDLLOVERRIDES":
                        "dxgi,d3d11,d3d10core,d3d9,d3d12,d3d12core=b;nvapi,nvapi64=d;amd_fidelityfx_upscaler_dx12,amd_fidelityfx_framegeneration_dx12=n,b;nvngx,_nvngx,nvngx_dlss,nvngx_dlssd,nvngx_dlssg,sl.interposer,sl.common,sl.dlss,sl.dlss_g,sl.deepdvc,sl.reflex,sl.pcl=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0",
                    "VECTOR_WINE_BIN_OVERRIDE": wineBinary,
                    "VECTOR_WINESERVER_BIN_OVERRIDE": wineserverBinary
                ]
            )

            if let existingIndex = profiles.firstIndex(where: { existing in
                existing.name.caseInsensitiveCompare(profileName) == .orderedSame
                    || (existing.executableMatch.caseInsensitiveCompare("highonlife2-win64-shipping.exe") == .orderedSame
                        && existing.steamAppID == "2069250")
            }) {
                profile.id = profiles[existingIndex].id
                profiles[existingIndex] = profile
            } else {
                profiles.append(profile)
            }

            bottle.settings.gameProfiles = profiles
            gameProfilesDraft = profiles
            snapshotMessage = "\(snapshotNote)Applied HighOnLife2 compatibility preset."
        }
    }

    private func applyD3D11GameBaseSettings() {
        bottle.settings.runtimeSelection = .auto
        bottle.settings.graphicsBackendMode = .d3dMetal
        bottle.settings.dxvk = true
        bottle.settings.dxvkAsync = true
        bottle.settings.shaderCacheEnabled = true
        bottle.settings.forceD3D11Compatibility = true
        bottle.settings.dllOverridesPolicy = .auto
    }

    private func runPresetWithSnapshot(
        action: String,
        createSnapshot: Bool = true,
        apply: @escaping @MainActor (String) -> Void
    ) {
        let targetBottle = bottle
        snapshotInFlight = true

        Task.detached(priority: .userInitiated) {
            let snapshotNote = createSnapshot
                ? await Self.createAutoSnapshotIfEnabled(for: targetBottle, action: action)
                : ""
            await MainActor.run {
                apply(snapshotNote)
                snapshotInFlight = false
            }
        }
    }

    func runTrainerExecutable() {
        if let protectedAssessment, let title = protectedAssessment.matchedTitle {
            snapshotMessage = "Trainer launch blocked for protected title: \(title.title)"
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if let exeType = UTType(filenameExtension: "exe") {
            panel.allowedContentTypes = [exeType]
        }
        panel.directoryURL = bottle.url.appending(path: "drive_c")

        let targetBottle = bottle
        panel.begin { response in
            guard response == .OK, let trainerURL = panel.url else { return }

            Task.detached(priority: .userInitiated) {
                do {
                    try await Wine.runProgram(
                        at: trainerURL,
                        bottle: targetBottle,
                        environment: ["WINE_DISABLE_WRITE_WATCH": "1"]
                    )
                    await MainActor.run {
                        snapshotMessage = "Launched trainer: \(trainerURL.lastPathComponent)"
                    }
                } catch {
                    await MainActor.run {
                        snapshotMessage = "Trainer launch failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

private enum MissingDependencyFixID: String, Sendable {
    case runtimeDLLMirror
    case dotNet
    case visualCpp
    case dxvkPayload
    case dxmtPayload
    case dlssPayload
    case mediaPlayback
    case edgeWebView2Auth
    case minecraftDungeonsSignInLoop

    var repairActionDescription: String {
        switch self {
        case .runtimeDLLMirror:
            return "runtime DLL repair"
        case .dotNet:
            return ".NET dependency repair"
        case .visualCpp:
            return "Visual C++ dependency repair"
        case .dxvkPayload:
            return "DXVK payload repair"
        case .dxmtPayload:
            return "DXMT payload repair"
        case .dlssPayload:
            return "DLSS translation repair"
        case .mediaPlayback:
            return "media playback repair"
        case .edgeWebView2Auth:
            return "WebView2 auth repair"
        case .minecraftDungeonsSignInLoop:
            return "Minecraft Dungeons sign-in repair"
        }
    }

    var requiresRuntimeMirrorRepair: Bool {
        switch self {
        case .runtimeDLLMirror, .mediaPlayback, .dxvkPayload, .dxmtPayload, .dlssPayload:
            return true
        case .dotNet, .visualCpp, .edgeWebView2Auth, .minecraftDungeonsSignInLoop:
            return false
        }
    }
}

private struct MissingDependencyFix: Identifiable, Sendable {
    let id: MissingDependencyFixID
    let title: String
    let detail: String
    let actionTitle: String
}

private struct DependencyRepairPlan: Sendable {
    let fixIDs: Set<MissingDependencyFixID>
    let repairRuntimeDLLMirror: Bool
    let enableDXVKPayload: Bool
    let enableDXMTPayload: Bool
    let enableDLSSRuntimeTranslation: Bool
    let enableMediaPlaybackCompatibility: Bool
    let resetMinecraftAuthCaches: Bool
    let winetricksVerbs: [String]

    init(fixIDs: Set<MissingDependencyFixID>, includeRuntimeDLLRepair: Bool) {
        self.fixIDs = fixIDs
        self.repairRuntimeDLLMirror = includeRuntimeDLLRepair || fixIDs.contains {
            $0.requiresRuntimeMirrorRepair
        }
        self.enableDXVKPayload = fixIDs.contains(.dxvkPayload)
        self.enableDXMTPayload = fixIDs.contains(.dxmtPayload)
        self.enableDLSSRuntimeTranslation = fixIDs.contains(.dlssPayload)
        self.enableMediaPlaybackCompatibility = fixIDs.contains(.mediaPlayback)
        self.resetMinecraftAuthCaches = fixIDs.contains(.minecraftDungeonsSignInLoop)

        var verbs: [String] = []
        Self.appendIfNeeded("dotnet48", to: &verbs, when: fixIDs.contains(.dotNet))
        Self.appendIfNeeded(
            "vcrun2022",
            to: &verbs,
            when: fixIDs.contains(.dotNet) || fixIDs.contains(.visualCpp)
        )
        Self.appendIfNeeded("corefonts", to: &verbs, when: fixIDs.contains(.dotNet))
        Self.appendIfNeeded("quartz", to: &verbs, when: fixIDs.contains(.mediaPlayback))
        Self.appendIfNeeded("l3codecx", to: &verbs, when: fixIDs.contains(.mediaPlayback))
        Self.appendIfNeeded("devenum", to: &verbs, when: fixIDs.contains(.mediaPlayback))
        Self.appendIfNeeded(
            "edgewebview2",
            to: &verbs,
            when: fixIDs.contains(.edgeWebView2Auth) || fixIDs.contains(.minecraftDungeonsSignInLoop)
        )
        self.winetricksVerbs = verbs
    }

    var isEmpty: Bool {
        fixIDs.isEmpty
            && !repairRuntimeDLLMirror
            && !enableDXVKPayload
            && !enableDXMTPayload
            && !enableDLSSRuntimeTranslation
            && !enableMediaPlaybackCompatibility
            && !resetMinecraftAuthCaches
            && winetricksVerbs.isEmpty
    }

    var winetricksCommand: String? {
        guard !winetricksVerbs.isEmpty else {
            return nil
        }
        return winetricksVerbs.joined(separator: " ")
    }

    private static func appendIfNeeded(_ verb: String, to verbs: inout [String], when condition: Bool) {
        guard condition, !verbs.contains(verb) else {
            return
        }
        verbs.append(verb)
    }
}

private enum MissingDependencyDetector {
    private struct RuntimeDLLMirrorHealth {
        let missingDLLs: [String]
        let mismatchedDLLs: [String]

        var needsRepair: Bool {
            !missingDLLs.isEmpty || !mismatchedDLLs.isEmpty
        }
    }

    private static let runtimeMirrorCriticalDLLs = [
        "dxgi.dll",
        "d3d11.dll",
        "d3d10core.dll",
        "d3d9.dll",
        "mfplat.dll",
        "quartz.dll",
        "winegstreamer.dll"
    ]
    private static let dxvkCriticalDLLs = [
        "dxgi.dll",
        "d3d11.dll",
        "d3d10core.dll"
    ]
    private static let mediaPlaybackDLLs = [
        "mf.dll",
        "mfplat.dll",
        "mfreadwrite.dll",
        "quartz.dll",
        "devenum.dll",
        "winegstreamer.dll"
    ]

    static func detect(for bottle: Bottle) -> [MissingDependencyFix] {
        let combinedLog = latestBottleLogs(for: bottle).joined(separator: "\n")
        var fixes: [MissingDependencyFix] = []
        let runtimeMirrorHealth = inspectRuntimeDLLMirror(for: bottle)
        let hasWebView2Runtime = hasEdgeWebView2Runtime(in: bottle)
        let hasDotNetRuntime = hasDotNetRuntime(in: bottle)
        let hasVisualCppRuntime = hasVisualCppRuntime(in: bottle)
        let missingMediaComponents = missingMediaPlaybackDLLs(in: bottle)
        let dxvkExpected = expectsDXVK(for: bottle)
        let dxmtExpected = expectsDXMT(for: bottle)
        let hasDXVKPayload = hasDXVKPayloadInBottle(in: bottle)
        let hasDLSSRuntimePayload = hasDLSSRuntimePayload(in: bottle)
        let shouldSuggestRuntimeMirrorRepair = shouldSuggestRuntimeMirrorRepair(
            runtimeMirrorHealth,
            dxvkExpected: dxvkExpected,
            hasDXVKPayload: hasDXVKPayload
        )

        if shouldSuggestRuntimeMirrorRepair {
            let detail = runtimeMirrorDetail(from: runtimeMirrorHealth)
            fixes.append(
                MissingDependencyFix(
                    id: .runtimeDLLMirror,
                    title: "Runtime DLL Mirror Drift Detected",
                    detail: detail,
                    actionTitle: "Repair Runtime DLL Mirror"
                )
            )
        }

        let hasDotNetMissing = combinedLog.localizedCaseInsensitiveContains("mscoree.dll")
            || combinedLog.localizedCaseInsensitiveContains("mscorsvw.exe")
        if hasDotNetMissing || !hasDotNetRuntime && bottle.settings.trainerSupportMode {
            fixes.append(
                MissingDependencyFix(
                    id: .dotNet,
                    title: ".NET Runtime Components Missing",
                    detail: hasDotNetMissing
                        ? "Logs show mscoree/.NET loader failures for this bottle."
                        : "Trainer and launcher compatibility mode is enabled, but the bottle does not appear to have the required .NET runtime files yet.",
                    actionTitle: "Install .NET + Core Dependencies"
                )
            )
        }

        let hasVisualCppMissing = combinedLog.localizedCaseInsensitiveContains("vcruntime")
            || combinedLog.localizedCaseInsensitiveContains("msvcp")
        if hasVisualCppMissing || !hasVisualCppRuntime && hasDotNetMissing {
            fixes.append(
                MissingDependencyFix(
                    id: .visualCpp,
                    title: "Visual C++ Runtime Missing",
                    detail: hasVisualCppMissing
                        ? "Game/runtime logs indicate missing VC runtime binaries."
                        : "Core VC runtime DLLs are missing from the bottle runtime.",
                    actionTitle: "Install Visual C++ Runtime"
                )
            )
        }

        if dxvkExpected && !hasDXVKPayload {
            fixes.append(
                MissingDependencyFix(
                    id: .dxvkPayload,
                    title: "DXVK Runtime DLLs Missing",
                    detail: "This bottle expects DXVK, but the DXVK DLL payload is not fully deployed into the Windows system directories.",
                    actionTitle: "Repair DXVK Runtime"
                )
            )
        }

        if dxmtExpected && !Wine.isDXMTPayloadReady() {
            fixes.append(
                MissingDependencyFix(
                    id: .dxmtPayload,
                    title: "DXMT Payload Missing",
                    detail: "This bottle is expected to use DXMT, but the DXMT payload is not fully installed yet.",
                    actionTitle: "Install DXMT Payload"
                )
            )
        }

        let hasDLSSMissing = combinedLog.localizedCaseInsensitiveContains("nvngx_dlss")
            || combinedLog.localizedCaseInsensitiveContains("sl.dlss")
            || combinedLog.localizedCaseInsensitiveContains("streamline")
            || combinedLog.localizedCaseInsensitiveContains("dlss")
                && combinedLog.localizedCaseInsensitiveContains("not found")
        if bottle.settings.dlssRuntimeTranslationEnabled && (!hasDLSSRuntimePayload || hasDLSSMissing) {
            fixes.append(
                MissingDependencyFix(
                    id: .dlssPayload,
                    title: "DLSS Runtime Payload Missing",
                    detail: "DLSS-related translation DLLs are unavailable or incomplete in this runtime/prefix. Vector can reinstall and validate the DXMT-based DLSS translation path.",
                    actionTitle: "Enable DLSS Translation Runtime"
                )
            )
        }

        let hasMediaPlaybackMissing =
            !missingMediaComponents.isEmpty
            || combinedLog.localizedCaseInsensitiveContains("mfplat.dll")
            || combinedLog.localizedCaseInsensitiveContains("mfreadwrite.dll")
            || combinedLog.localizedCaseInsensitiveContains("winegstreamer")
            || combinedLog.localizedCaseInsensitiveContains("wmvcore.dll")
            || combinedLog.localizedCaseInsensitiveContains("quartz.dll")
            || combinedLog.localizedCaseInsensitiveContains("failed to initialize video")
            || combinedLog.localizedCaseInsensitiveContains("failed to play video")
            || combinedLog.localizedCaseInsensitiveContains("video playback")
        if hasMediaPlaybackMissing {
            fixes.append(
                MissingDependencyFix(
                    id: .mediaPlayback,
                    title: "Media Playback Components Missing",
                    detail: missingMediaComponents.isEmpty
                        ? "Logs indicate missing Media Foundation/Quartz playback components."
                        : "Critical media playback DLLs are missing or out of sync: \(missingMediaComponents.prefix(4).joined(separator: ", ")).",
                    actionTitle: "Repair Media Playback Components"
                )
            )
        }

        let isMinecraftDungeonsBottle = {
            let activeSteamAppID = bottle.settings.activeSteamAppID
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if activeSteamAppID == "1672970" {
                return true
            }

            let pinnedDungeons = bottle.settings.pins.contains { pin in
                guard let url = pin.url else {
                    return false
                }

                let path = url.path(percentEncoded: false).lowercased()
                return path.contains("minecraftdungeons") || path.hasSuffix("/dungeons.exe")
            }
            let profiledDungeons = bottle.settings.gameProfiles.contains { profile in
                let executable = profile.executableMatch.lowercased()
                return executable.contains("dungeons") || profile.steamAppID == "1672970"
            }

            return pinnedDungeons
                || profiledDungeons
                || combinedLog.localizedCaseInsensitiveContains("minecraftdungeons")
                || combinedLog.localizedCaseInsensitiveContains("dungeons-win64-shipping")
        }()
        let hasWebAuthIssue = combinedLog.localizedCaseInsensitiveContains("webview")
            || combinedLog.localizedCaseInsensitiveContains("edgewebview")
            || combinedLog.localizedCaseInsensitiveContains("login page")
        let hasMinecraftDungeonsSignInLoop = combinedLog.localizedCaseInsensitiveContains(
            "you have reached a page that is not normally shown"
        ) || combinedLog.localizedCaseInsensitiveContains(
            "microsoft will never ask you to copy or share this url"
        )

        if !isMinecraftDungeonsBottle && !hasWebView2Runtime && hasWebAuthIssue {
            fixes.append(
                MissingDependencyFix(
                    id: .edgeWebView2Auth,
                    title: "WebView2 Runtime Missing",
                    detail: "The bottle is hitting an auth/webview flow, but Edge WebView2 does not appear to be installed.",
                    actionTitle: "Install WebView2 Runtime"
                )
            )
        }

        if isMinecraftDungeonsBottle {
            let missingWebViewRuntime = !hasWebView2Runtime
            if hasMinecraftDungeonsSignInLoop || missingWebViewRuntime || hasWebAuthIssue {
                let detail: String
                if hasMinecraftDungeonsSignInLoop {
                    detail =
                        "Detected Microsoft callback loop. Repair will install WebView2 and reset stale auth web cache."
                } else if missingWebViewRuntime {
                    detail = "Edge WebView2 runtime is missing for Minecraft Dungeons sign-in in this bottle."
                } else {
                    detail = "Runs the Microsoft sign-in repair flow (WebView2 + auth cache reset) for this title."
                }

                fixes.append(
                    MissingDependencyFix(
                        id: .minecraftDungeonsSignInLoop,
                        title: "Minecraft Dungeons Microsoft Sign-In Repair",
                        detail: detail,
                        actionTitle: "Repair Microsoft Sign-In"
                    )
                )
            }
        }

        return fixes
    }

    private static func expectsDXVK(for bottle: Bottle) -> Bool {
        if bottle.settings.graphicsBackendMode == .dxvk {
            return true
        }
        return bottle.settings.graphicsBackendMode == .auto
            && bottle.settings.inferredGraphicsBackendMode == .dxvk
    }

    private static func expectsDXMT(for bottle: Bottle) -> Bool {
        if bottle.settings.graphicsBackendMode == .dxmt {
            return true
        }
        if bottle.settings.graphicsBackendMode == .auto,
           bottle.settings.inferredGraphicsBackendMode == .dxmt {
            return true
        }
        return bottle.settings.dlssRuntimeTranslationEnabled
    }

    private static func hasDotNetRuntime(in bottle: Bottle) -> Bool {
        let windows = bottle.url.appending(path: "drive_c").appending(path: "windows")
        let candidates = [
            windows.appending(path: "system32").appending(path: "mscoree.dll"),
            windows.appending(path: "syswow64").appending(path: "mscoree.dll"),
            windows
                .appending(path: "Microsoft.NET")
                .appending(path: "Framework")
                .appending(path: "v4.0.30319")
                .appending(path: "mscorlib.dll")
        ]
        return candidates.contains {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    private static func hasVisualCppRuntime(in bottle: Bottle) -> Bool {
        let windows = bottle.url.appending(path: "drive_c").appending(path: "windows")
        let candidates = [
            windows.appending(path: "system32").appending(path: "vcruntime140.dll"),
            windows.appending(path: "system32").appending(path: "msvcp140.dll"),
            windows.appending(path: "syswow64").appending(path: "vcruntime140.dll"),
            windows.appending(path: "syswow64").appending(path: "msvcp140.dll")
        ]
        return candidates.contains {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    private static func hasDXVKPayloadInBottle(in bottle: Bottle) -> Bool {
        let windows = bottle.url.appending(path: "drive_c").appending(path: "windows")
        let candidates = dxvkCriticalDLLs.flatMap { dllName in
            [
                windows.appending(path: "system32").appending(path: dllName),
                windows.appending(path: "syswow64").appending(path: dllName)
            ]
        }
        return candidates.allSatisfy {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    private static func hasDLSSRuntimePayload(in bottle: Bottle) -> Bool {
        let fileManager = FileManager.default
        let windowsDirectory = bottle.url.appending(path: "drive_c").appending(path: "windows")
        let runtimeWineBinary = ConfigView.selectedRuntimeWineBinaryForHealth(for: bottle)
        let runtimeWineFolder = ConfigView.resolveRuntimeWineFolderForHealth(
            using: runtimeWineBinary,
            fileManager: fileManager
        )

        let paths = [
            runtimeWineFolder.appending(path: "x86_64-windows").appending(path: "nvapi64.dll"),
            runtimeWineFolder.appending(path: "x86_64-windows").appending(path: "nvngx.dll"),
            windowsDirectory.appending(path: "system32").appending(path: "nvapi64.dll"),
            windowsDirectory.appending(path: "system32").appending(path: "nvngx.dll")
        ]
        return paths.allSatisfy { fileManager.fileExists(atPath: $0.path(percentEncoded: false)) }
    }

    private static func missingMediaPlaybackDLLs(in bottle: Bottle) -> [String] {
        let runtimeMirrorHealth = inspectRuntimeDLLMirror(for: bottle)
        let allIssues = Set(runtimeMirrorHealth.missingDLLs + runtimeMirrorHealth.mismatchedDLLs)
        return mediaPlaybackDLLs.filter { allIssues.contains($0) }
    }

    private static func runtimeMirrorDetail(from health: RuntimeDLLMirrorHealth) -> String {
        if !health.missingDLLs.isEmpty {
            let dllList = health.missingDLLs.prefix(4).joined(separator: ", ")
            return "Vector found missing runtime DLLs in the bottle Windows directories: \(dllList)."
        }

        let dllList = health.mismatchedDLLs.prefix(4).joined(separator: ", ")
        return "Vector found runtime DLL drift between the selected runtime and the bottle: \(dllList)."
    }

    private static func inspectRuntimeDLLMirror(for bottle: Bottle) -> RuntimeDLLMirrorHealth {
        let fileManager = FileManager.default
        let runtimeWineBinary = ConfigView.selectedRuntimeWineBinaryForHealth(for: bottle)
        let runtimeWineFolder = ConfigView.resolveRuntimeWineFolderForHealth(
            using: runtimeWineBinary,
            fileManager: fileManager
        )
        let windowsDirectory = bottle.url.appending(path: "drive_c").appending(path: "windows")
        var missing = Set<String>()
        var mismatched = Set<String>()
        var fingerprintCache: [String: String] = [:]

        compareRuntimeDLLs(
            runtimeMirrorCriticalDLLs,
            from: runtimeWineFolder.appending(path: "x86_64-windows"),
            to: windowsDirectory.appending(path: "system32"),
            missing: &missing,
            mismatched: &mismatched,
            fingerprintCache: &fingerprintCache
        )
        compareRuntimeDLLs(
            runtimeMirrorCriticalDLLs,
            from: runtimeWineFolder.appending(path: "i386-windows"),
            to: windowsDirectory.appending(path: "syswow64"),
            missing: &missing,
            mismatched: &mismatched,
            fingerprintCache: &fingerprintCache
        )

        return RuntimeDLLMirrorHealth(
            missingDLLs: missing.sorted(),
            mismatchedDLLs: mismatched.sorted()
        )
    }

    private static func shouldSuggestRuntimeMirrorRepair(
        _ health: RuntimeDLLMirrorHealth,
        dxvkExpected: Bool,
        hasDXVKPayload: Bool
    ) -> Bool {
        guard health.needsRepair else {
            return false
        }
        guard health.mismatchedDLLs.isEmpty else {
            return true
        }

        let dxvkSpecificIssues = dxvkExpected && !hasDXVKPayload ? Set(dxvkCriticalDLLs) : []
        let mediaSpecificIssues = Set(mediaPlaybackDLLs)
        let specificIssues = dxvkSpecificIssues.union(mediaSpecificIssues)

        return health.missingDLLs.contains { !specificIssues.contains($0) }
    }

    private static func compareRuntimeDLLs(
        _ dllNames: [String],
        from sourceDirectory: URL,
        to destinationDirectory: URL,
        missing: inout Set<String>,
        mismatched: inout Set<String>,
        fingerprintCache: inout [String: String]
    ) {
        let fileManager = FileManager.default
        for dllName in dllNames {
            let sourceURL = sourceDirectory.appending(path: dllName)
            let destinationURL = destinationDirectory.appending(path: dllName)
            let sourcePath = sourceURL.path(percentEncoded: false)
            let destinationPath = destinationURL.path(percentEncoded: false)

            guard fileManager.fileExists(atPath: sourcePath) else {
                continue
            }

            guard fileManager.fileExists(atPath: destinationPath) else {
                missing.insert(dllName)
                continue
            }

            let sourceFingerprint = fingerprint(for: sourceURL, cache: &fingerprintCache)
            let destinationFingerprint = fingerprint(for: destinationURL, cache: &fingerprintCache)
            if sourceFingerprint != destinationFingerprint {
                mismatched.insert(dllName)
            }
        }
    }

    private static func fingerprint(for fileURL: URL, cache: inout [String: String]) -> String {
        let path = fileURL.path(percentEncoded: false)
        if let cached = cache[path] {
            return cached
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return "missing"
        }

        let digest = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        cache[path] = digest
        return digest
    }

    private static func hasEdgeWebView2Runtime(in bottle: Bottle) -> Bool {
        let bottleRoot = bottle.url
        let candidates = [
            bottleRoot
                .appending(path: "drive_c")
                .appending(path: "Program Files (x86)")
                .appending(path: "Microsoft")
                .appending(path: "EdgeWebView")
                .appending(path: "Application"),
            bottleRoot
                .appending(path: "drive_c")
                .appending(path: "Program Files")
                .appending(path: "Microsoft")
                .appending(path: "EdgeWebView")
                .appending(path: "Application"),
            bottleRoot
                .appending(path: "drive_c")
                .appending(path: "windows")
                .appending(path: "system32")
                .appending(path: "WebView2Loader.dll")
        ]

        return candidates.contains {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    private static func latestBottleLogs(for bottle: Bottle) -> [String] {
        let logsURL = Wine.logsFolder
        let bottlePath = bottle.url.path(percentEncoded: false)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logsURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let sortedLogs = files
            .filter { $0.pathExtension == "log" }
            .sorted {
                let lhsDate = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let rhsDate = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return lhsDate > rhsDate
            }

        var matches: [String] = []
        for fileURL in sortedLogs {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }
            guard content.contains("Bottle URL: \(bottlePath)")
                    || content.contains("Bottle Name: \(bottle.settings.name)") else {
                continue
            }
            matches.append(content)
            if matches.count >= 8 {
                break
            }
        }
        return matches
    }
}

private enum LaunchDoctorSeverity: String, Sendable {
    case critical
    case warning
    case info
}

private enum LaunchDoctorFixID: String, CaseIterable, Sendable, Identifiable {
    case switchToCompatibilityRuntime
    case forceD3D11Compatibility
    case installCoreDependencies
    case steamSafeUiMode
    case enableDebugLogs
    case enableSafeMultiplayerMode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .switchToCompatibilityRuntime:
            return "Use Compatibility Runtime Pair"
        case .forceD3D11Compatibility:
            return "Force D3D11 Compatibility Path"
        case .installCoreDependencies:
            return "Install Core Dependencies"
        case .steamSafeUiMode:
            return "Apply Steam Safe UI Mode"
        case .enableDebugLogs:
            return "Enable Debug Log Profile"
        case .enableSafeMultiplayerMode:
            return "Enable Safe Multiplayer Mode"
        }
    }
}

private struct LaunchDoctorFixSuggestion: Identifiable, Sendable {
    let id: LaunchDoctorFixID
    let detail: String
}

private struct LaunchDoctorFinding: Identifiable, Sendable {
    let id = UUID()
    let severity: LaunchDoctorSeverity
    let title: String
    let detail: String
}

private struct BottleHealthReport: Sendable {
    let score: Int
    let risks: [String]
}

private struct LaunchDoctorReport: Sendable {
    let latestLogName: String
    let intelligenceSummary: String
    let health: BottleHealthReport
    let findings: [LaunchDoctorFinding]
    let suggestedFixes: [LaunchDoctorFixSuggestion]
}

private actor LaunchIntelligenceService {
    static let shared = LaunchIntelligenceService()

    func analyze(for bottle: Bottle, preferAppleIntelligence: Bool) async -> LaunchDoctorReport {
        let logs = latestBottleLogs(for: bottle, maxCount: 8)
        let latestLogName = logs.first?.url.lastPathComponent ?? "No log found"
        let combinedLog = logs.map(\.content).joined(separator: "\n")

        var findings: [LaunchDoctorFinding] = []
        var suggestedFixes: [LaunchDoctorFixSuggestion] = []

        addFinding(
            condition: combinedLog.localizedCaseInsensitiveContains("version mismatch")
                || combinedLog.localizedCaseInsensitiveContains("wrong wineserver is still running"),
            severity: .critical,
            title: "Wine/Wineserver version mismatch detected",
            detail: "Launch logs indicate mixed runtime binaries. Use a consistent wine/wineserver pair.",
            fix: .switchToCompatibilityRuntime,
            findings: &findings,
            fixes: &suggestedFixes
        )
        addFinding(
            condition: combinedLog.localizedCaseInsensitiveContains("DirectX 12 is not supported"),
            severity: .critical,
            title: "DirectX 12 unsupported",
            detail: "The title requested DirectX 12 but this environment cannot provide it reliably.",
            fix: .forceD3D11Compatibility,
            findings: &findings,
            fixes: &suggestedFixes
        )
        addFinding(
            condition: combinedLog.localizedCaseInsensitiveContains("A D3D11-compatible GPU")
                || combinedLog.localizedCaseInsensitiveContains("Feature Level 11.0"),
            severity: .critical,
            title: "D3D11 feature-level requirement failed",
            detail: "The game could not initialize a required D3D11 path. Apply DX11 compatibility settings.",
            fix: .forceD3D11Compatibility,
            findings: &findings,
            fixes: &suggestedFixes
        )
        addFinding(
            condition: combinedLog.localizedCaseInsensitiveContains("Library mscoree.dll")
                || combinedLog.localizedCaseInsensitiveContains("mscorsvw.exe"),
            severity: .warning,
            title: ".NET runtime components are missing",
            detail: "The logs indicate missing mscoree/.NET dependencies often required by launchers and tools.",
            fix: .installCoreDependencies,
            findings: &findings,
            fixes: &suggestedFixes
        )
        addFinding(
            condition: combinedLog.localizedCaseInsensitiveContains("steamwebhelper")
                || combinedLog.localizedCaseInsensitiveContains("-cef-disable-gpu"),
            severity: .info,
            title: "Steam UI fallback behavior detected",
            detail: "CEF/GPU-safe startup arguments are in use. If Steam windows are blank, apply safe UI mode.",
            fix: .steamSafeUiMode,
            findings: &findings,
            fixes: &suggestedFixes
        )
        addFinding(
            condition: combinedLog.localizedCaseInsensitiveContains("status code '1'"),
            severity: .warning,
            title: "Process terminated with status 1",
            detail: "A launch process exited early without a clear success path. Use debug logs for deeper trace.",
            fix: .enableDebugLogs,
            findings: &findings,
            fixes: &suggestedFixes
        )

        let health = makeHealthReport(for: bottle, combinedLog: combinedLog)
        let intelligenceSummary = await makeIntelligenceSummary(
            findings: findings,
            healthScore: health.score,
            preferAppleIntelligence: preferAppleIntelligence
        )

        return LaunchDoctorReport(
            latestLogName: latestLogName,
            intelligenceSummary: intelligenceSummary,
            health: health,
            findings: findings,
            suggestedFixes: suggestedFixes
        )
    }
}

private extension LaunchIntelligenceService {
    struct BottleLogEntry {
        let url: URL
        let content: String
    }

    func latestBottleLogs(for bottle: Bottle, maxCount: Int) -> [BottleLogEntry] {
        let logsURL = Wine.logsFolder
        let bottlePath = bottle.url.path(percentEncoded: false)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logsURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let candidates = files
            .filter { $0.pathExtension == "log" }
            .sorted {
                let lhsDate = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let rhsDate = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return lhsDate > rhsDate
            }

        var matches: [BottleLogEntry] = []
        for logURL in candidates {
            guard let data = try? Data(contentsOf: logURL, options: [.mappedIfSafe]),
                  let content = String(data: data, encoding: .utf8) else {
                continue
            }
            if content.contains("Bottle URL: \(bottlePath)")
                || content.contains("Bottle Name: \(bottle.settings.name)") {
                matches.append(BottleLogEntry(url: logURL, content: content))
            }
            if matches.count >= maxCount {
                break
            }
        }

        return matches
    }

    func addFinding(
        condition: Bool,
        severity: LaunchDoctorSeverity,
        title: String,
        detail: String,
        fix: LaunchDoctorFixID,
        findings: inout [LaunchDoctorFinding],
        fixes: inout [LaunchDoctorFixSuggestion]
    ) {
        guard condition else { return }
        findings.append(
            LaunchDoctorFinding(
                severity: severity,
                title: title,
                detail: detail
            )
        )

        if !fixes.contains(where: { $0.id == fix }) {
            fixes.append(LaunchDoctorFixSuggestion(id: fix, detail: fixDetail(for: fix)))
        }
    }

    func fixDetail(for fix: LaunchDoctorFixID) -> String {
        switch fix {
        case .switchToCompatibilityRuntime:
            return "Switches this bottle to a matched wine/wineserver runtime pair."
        case .forceD3D11Compatibility:
            return "Applies DirectX 11 fallback defaults and graphics compatibility options."
        case .installCoreDependencies:
            return "Runs dotnet48 + vcrun2022 + corefonts via Winetricks."
        case .steamSafeUiMode:
            return "Enables conservative Steam CEF/browser/overlay-safe startup options."
        case .enableDebugLogs:
            return "Sets the bottle log profile to Debug for deeper diagnostics."
        case .enableSafeMultiplayerMode:
            return "Enforces anti-cheat-safe launch behavior and blocks trainer launches."
        }
    }

    func makeHealthReport(for bottle: Bottle, combinedLog: String) -> BottleHealthReport {
        var score = 100
        var risks: [String] = []

        if bottle.settings.runtimeSelection == .custom {
            let winePath = bottle.settings.customWineBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let wineserverPath = bottle.settings.customWineserverBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !(FileManager.default.isExecutableFile(atPath: winePath)
                && FileManager.default.isExecutableFile(atPath: wineserverPath)) {
                score -= 20
                risks.append("Custom runtime is enabled but binary paths look invalid.")
            }
        }

        if bottle.settings.patchDispatchEnabled
            && !bottle.settings.patchDispatchEndpointURL.lowercased().hasPrefix("https://") {
            score -= 8
            risks.append("Patch dispatch endpoint is not HTTPS.")
        }

        if bottle.settings.patchDispatchEnabled && !bottle.settings.patchDispatchRequireSignedRules {
            score -= 8
            risks.append("Unsigned patch rules are allowed.")
        }

        if bottle.settings.allowUnsupportedAntiCheatLaunches {
            score -= 12
            risks.append("Unsupported anti-cheat launches are allowed.")
        }

        if !bottle.settings.safeMultiplayerMode {
            score -= 5
            risks.append("Safe multiplayer mode is disabled.")
        }

        if combinedLog.localizedCaseInsensitiveContains("version mismatch") {
            score -= 25
            risks.append("Recent logs include wine/wineserver version mismatch.")
        }

        if combinedLog.localizedCaseInsensitiveContains("DirectX 12 is not supported")
            || combinedLog.localizedCaseInsensitiveContains("A D3D11-compatible GPU") {
            score -= 18
            risks.append("Recent logs include graphics backend capability failures.")
        }

        return BottleHealthReport(score: min(100, max(0, score)), risks: risks)
    }

    func makeIntelligenceSummary(
        findings: [LaunchDoctorFinding],
        healthScore: Int,
        preferAppleIntelligence: Bool
    ) async -> String {
        let topFinding = findings.first?.title ?? "No high-confidence finding"
        let fallbackSummary = "On-device fallback summary: Top issue is \(topFinding). Health score is \(healthScore)/100."
        guard preferAppleIntelligence else {
            return "Intelligence service disabled. \(fallbackSummary)"
        }

        #if canImport(FoundationModels)
        if #available(macOS 15.0, *) {
            let prompt = """
            Summarize this game launch diagnosis in 2 short sentences.
            Include the most likely root cause and best next fix.

            Top finding: \(topFinding)
            Health score: \(healthScore)/100
            """
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    return "Apple Intelligence summary: \(text)"
                }
            } catch {
                return "\(fallbackSummary) Apple Intelligence unavailable: \(error.localizedDescription)."
            }
        }
        #endif

        return fallbackSummary
    }
}

private enum DLSSRuntimeHealthStatus: Sendable {
    case healthy
    case warning
    case missing

    var iconName: String {
        switch self {
        case .healthy:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .missing:
            return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .healthy:
            return .green
        case .warning:
            return .orange
        case .missing:
            return .red
        }
    }
}

private struct DLSSRuntimeHealthItem: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let detail: String
    let status: DLSSRuntimeHealthStatus
}

private struct DLSSRuntimeHealthReport: Sendable {
    let generatedAt: Date
    let summary: String
    let items: [DLSSRuntimeHealthItem]

    static let empty = DLSSRuntimeHealthReport(
        generatedAt: Date.distantPast,
        summary: "No health report generated yet.",
        items: []
    )
}

private struct DLSSRuntimeHealthModalView: View {
    let loading: Bool
    let report: DLSSRuntimeHealthReport
    let snapshotInFlight: Bool
    let onRefresh: () -> Void
    let onRepair: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var generatedAtText: String {
        guard report.generatedAt != .distantPast else {
            return "Not yet generated"
        }
        return report.generatedAt.formatted(date: .abbreviated, time: .standard)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("DLSS Runtime Health")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(generatedAtText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(report.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if loading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking runtime payload and DLL deployment...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(report.items) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.status.iconName)
                                .foregroundStyle(item.status.color)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxHeight: 280)

            HStack {
                Button("Close") {
                    dismiss()
                }
                Spacer()
                Button("Refresh") {
                    onRefresh()
                }
                .disabled(loading || snapshotInFlight)
                Button("Enable & Repair") {
                    onRepair()
                }
                .buttonStyle(.borderedProminent)
                .disabled(snapshotInFlight)
            }
        }
        .padding(18)
        .frame(width: 600, height: 470)
    }
}

struct DPIConfigSheetView: View {
    @Binding var dpiConfig: Int
    @Binding var isRetinaMode: Bool
    @Binding var presented: Bool
    @State var stagedChanges: Float
    @FocusState var textFocused: Bool

    init(dpiConfig: Binding<Int>, isRetinaMode: Binding<Bool>, presented: Binding<Bool>) {
        self._dpiConfig = dpiConfig
        self._isRetinaMode = isRetinaMode
        self._presented = presented
        self.stagedChanges = Float(dpiConfig.wrappedValue)
    }

    var body: some View {
        VStack {
            HStack {
                Text("configDpi.title")
                    .fontWeight(.bold)
                Spacer()
            }
            Divider()
            GroupBox(label: Label("configDpi.preview", systemImage: "text.magnifyingglass")) {
                VStack {
                    HStack {
                        Text("configDpi.previewText")
                            .padding(16)
                            .font(.system(size:
                                (10 * CGFloat(stagedChanges)) / 72 *
                                          (isRetinaMode ? 0.5 : 1)
                            ))
                        Spacer()
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: 80)
            }
            HStack {
                Slider(value: $stagedChanges, in: 96...480, step: 24, onEditingChanged: { _ in
                    textFocused = false
                })
                .help("Adjust DPI scaling for Windows UI inside this bottle.")
                TextField(String(), value: $stagedChanges, format: .number)
                    .frame(width: 40)
                    .focused($textFocused)
                    .help("Type an exact DPI value between 96 and 480.")
                Text("configDpi.dpi")
            }
            Spacer()
            HStack {
                Spacer()
                Button("create.cancel") {
                    presented = false
                }
                .keyboardShortcut(.cancelAction)
                .help("Close without applying DPI changes.")
                Button("button.ok") {
                    dpiConfig = Int(stagedChanges)
                    presented = false
                }
                .keyboardShortcut(.defaultAction)
                .help("Apply the selected DPI value.")
            }
        }
        .padding()
        .frame(width: ViewWidth.medium, height: 240)
    }
}

struct SettingItemView<Content: View>: View {
    let title: String.LocalizationValue
    let loadingState: LoadingState
    @ViewBuilder var content: () -> Content

    @Namespace private var viewId
    @Namespace private var progressViewId

    var body: some View {
        HStack {
            Text(String(localized: title))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                switch loadingState {
                case .loading, .modifying:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .matchedGeometryEffect(id: progressViewId, in: viewId)
                case .success:
                    content()
                        .labelsHidden()
                        .disabled(loadingState != .success)
                case .failed:
                    Text("config.notAvailable")
                        .font(.caption).foregroundStyle(.red)
                        .multilineTextAlignment(.trailing)
                }
            }.animation(.default, value: loadingState)
        }
    }
}
