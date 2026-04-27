//
//  Program+AdvancedRuntime.swift
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

import AppKit
import Foundation
import os.log

extension Program {
    private static let runtimeWineOverrideEnvironmentKey = "VECTOR_WINE_BIN_OVERRIDE"
    private static let runtimeWineserverOverrideEnvironmentKey = "VECTOR_WINESERVER_BIN_OVERRIDE"
    private static let steamExecutableName = "steam.exe"
    private static let steamUsersDirectoryName = "userdata"
    private static let steamUserLocalConfigSuffix = "config/localconfig.vdf"
    private static let highOnLife2SteamAppID = "2069250"
    private static let highOnLife2LegacySteamAppID = "2676880"
    private static let highOnLife2SteamLaunchOptions = "-dx12"
    private static let highOnLife2ExecutableName = "highonlife2-win64-shipping.exe"
    private static let highOnLife2ProfileArguments = "-dx12 -ngxdisable"
    private static let highOnLife2BuiltinD3DOverrides = "dxgi,d3d11,d3d10core,d3d9,d3d12,d3d12core=b"
    private static let highOnLife2FSRNativeOverrides =
        "amd_fidelityfx_upscaler_dx12,amd_fidelityfx_framegeneration_dx12=n,b"
    private static let highOnLife2NvidiaPluginDisableOverrides =
        "nvngx,_nvngx,nvngx_dlss,nvngx_dlssd,nvngx_dlssg,sl.interposer,sl.common,sl.dlss,sl.dlss_g,sl.deepdvc,sl.reflex,sl.pcl=d"
    private static let highOnLife2FSRDLLNames = [
        "amd_fidelityfx_upscaler_dx12.dll",
        "amd_fidelityfx_framegeneration_dx12.dll"
    ]
    private static let highOnLife2DLLOverridesToStrip: Set<String> = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9",
        "d3d12",
        "d3d12core",
        "nvapi",
        "nvapi64",
        "amd_fidelityfx_upscaler_dx12",
        "amd_fidelityfx_framegeneration_dx12",
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
    private static let parcelSimulatorSteamAppID = "2424010"
    private static let parcelSimulatorSteamLaunchOptions = "-force-d3d11"
    private static let parcelSimulatorExecutableName = "parcel-win64-shipping.exe"
    private static let parcelSimulatorLauncherExecutableName = "parcel.exe"
    private static let parcelSimulatorProfileArguments = "-force-d3d11 -dx11 -d3d11"
    private static let parcelSimulatorBuiltinD3DOverrides = "dxgi,d3d11,d3d10core,d3d9=b"
    private static let parcelSimulatorDLLOverridesToStrip: Set<String> = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9",
        "nvapi",
        "nvapi64"
    ]
    private static let minecraftDungeonsSteamAppID = "1672970"
    private static let minecraftDungeonsSteamLaunchOptions =
        "-force-d3d11 -dx11 -d3d11 -cef-disable-gpu -cef-disable-gpu-compositing "
        + "-cef-disable-accelerated-video-decode -cef-disable-low-latency-dxva "
        + "-cef-disable-zero-copy-dxgi-video -nosound"
    private static let minecraftDungeonsExecutableName = "dungeons-win64-shipping.exe"
    private static let minecraftDungeonsLauncherExecutableNames: Set<String> = [
        "minecraftdungeons.exe",
        "dungeons.exe"
    ]
    private static let minecraftDungeonsProfileArguments =
        "-force-d3d11 -dx11 -d3d11 -cef-disable-gpu -cef-disable-gpu-compositing "
        + "-cef-disable-accelerated-video-decode -cef-disable-low-latency-dxva "
        + "-cef-disable-zero-copy-dxgi-video -nosound"
    private static let minecraftDungeonsBuiltinD3DOverrides = "dxgi,d3d11,d3d10core,d3d9=n,b"
    private static let minecraftDungeonsDLLOverridesToStrip: Set<String> = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9",
        "nvapi",
        "nvapi64"
    ]
    private static let contentWarningSteamAppID = "2881650"
    private static let contentWarningSteamLaunchOptions = "-force-d3d11 -dx11 -d3d11"
    private static let contentWarningExecutableName = "content warning.exe"
    private static let contentWarningProfileArguments = "-force-d3d11 -dx11 -d3d11"
    private static let contentWarningDXVKD3DOverrides = "dxgi,d3d11,d3d10core,d3d9=n,b"
    private static let contentWarningDLLOverridesToStrip: Set<String> = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9",
        "nvapi",
        "nvapi64"
    ]
    private static let titanfall2SteamAppID = "1237970"
    private static let titanfall2ExecutableName = "titanfall2.exe"
    private static let titanfall2ProfileArguments = ""
    private static let titanfall2DXVKD3DOverrides = "dxgi,d3d11,d3d10core,d3d9=n,b"
    private static let titanfall2DLLOverridesToStrip: Set<String> = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9",
        "nvapi",
        "nvapi64"
    ]
    private static let originExecutableNames: Set<String> = [
        "origin.exe",
        "eadesktop.exe",
        "eaappinstaller.exe",
        "eadesktopinstaller.exe",
        "ealauncher.exe"
    ]
    private static let originProfileArguments = ""
    private static let originVersionOverride = "version=n,b"
    private static let originDLLOverridesToStrip: Set<String> = [
        "version",
        "nvapi",
        "nvapi64"
    ]
    private static let silentHillFSteamAppID = "2947440"
    private static let silentHillFSteamLaunchOptions = "-dx11"
    private static let silentHillFExecutableName = "silenthillf-win64-shipping.exe"
    private static let silentHillFLauncherExecutableNames: Set<String> = [
        "silenthillf.exe",
        "silent hill f.exe"
    ]
    private static let silentHillFProfileArguments = "-force-d3d11 -dx11 -d3d11"
    private static let silentHillFDXVKD3D11Overrides = "dxgi,d3d9,d3d10core,d3d11=n,b"
    private static let silentHillFDLLOverridesToStrip: Set<String> = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9",
        "d3d12",
        "d3d12core",
        "vulkan-1",
        "libegl",
        "libglesv2",
        "nvapi",
        "nvapi64"
    ]
    private static let forzaHorizon6SteamAppID = "2483190"
    private static let forzaHorizon6ExecutableName = "forzahorizon6.exe"
    private static let forzaHorizon6ProfileArguments = "-dx12 -d3d12"
    private static let forzaHorizon6D3DMetalOverrides =
        "dxgi,d3d11,d3d10core,d3d9=b;d3d12,d3d12core=n,b"
    private static let electronExecutableNames: Set<String> = [
        "wand.exe",
        "wemod.exe",
        "trainer runtime.exe",
        "trainerruntime.exe",
        "squirrel.exe"
    ]
    private static let electronCompatibilityArguments = [
        "--disable-gpu",
        "--disable-gpu-compositing",
        "--disable-features=RendererCodeIntegrity,CalculateNativeWinOcclusion",
        "--no-sandbox"
    ]
    private static let electronDLLOverridesToStrip: Set<String> = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9",
        "d3d12",
        "d3d12core",
        "vulkan-1",
        "libegl",
        "libglesv2"
    ]
    private static let installerExecutableNames: Set<String> = [
        "setup.exe",
        "install.exe",
        "installer.exe",
        "bootstrapper.exe",
        "updater.exe",
        "update.exe",
        "patcher.exe",
        "msiexec.exe",
        "unins000.exe"
    ]
    private static let installerDLLOverridesToStrip: Set<String> = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9",
        "d3d12",
        "d3d12core",
        "vulkan-1",
        "libegl",
        "libglesv2"
    ]
    private static let mediaPlaybackNativeBuiltinOverrides =
        "mf,mfplat,mfreadwrite,mfplay,evr,quartz,devenum,wmvcore,"
        + "msmpeg2vdec,msmpeg2adec,winegstreamer=n,b"
    private static let mediaPlaybackPatchEnvironmentKey = "VECTOR_MEDIA_PLAYBACK_PATCH_ACTIVE"
    private static let protonStyleCompatEnvironmentKey = "VECTOR_PROTON_STYLE_COMPAT"
    private static let protonMediaShimsEnvironmentKey = "VECTOR_PROTON_MEDIA_SHIMS"
    private static let mediaFoundationModeEnvironmentKey = "VECTOR_MEDIA_FOUNDATION_MODE"
    private static let protonStyleMediaFoundationMode = "proton-style"
    private static let mediaPlaybackDLLOverridesToStrip: Set<String> = [
        "mf",
        "mfplat",
        "mfreadwrite",
        "mfplay",
        "evr",
        "quartz",
        "devenum",
        "wmvcore",
        "msmpeg2vdec",
        "msmpeg2adec",
        "winegstreamer"
    ]
    private static let graphicsBackendDLLOverrideModules: Set<String> = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9"
    ]
    private static let dlssTranslationBuiltinD3DOverrides = "dxgi,d3d11,d3d10core=b"
    private static let dlssTranslationDLLOverridesToStrip: Set<String> = [
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
    private static let dlssFrameGenerationDisableOverrides = "nvngx_dlssg,sl.dlss_g=d"
    private static let dxmtNVExtensionsEnvironmentKey = "DXMT_ENABLE_NVEXT"
    private static let dlssTranslationMarkerEnvironmentKey = "VECTOR_DLSS_TRANSLATION_ACTIVE"
    private static let effectiveBackendEnvironmentKey = "VECTOR_EFFECTIVE_GRAPHICS_BACKEND"
    private static let effectiveFallbackBackendEnvironmentKey = "VECTOR_EFFECTIVE_GRAPHICS_BACKEND_FALLBACK"
    private static let highOnLife2EngineIniMarker = "; Vector HighOnLife2 compatibility overrides"
    private static let highOnLife2EngineIniBlock = """
; Vector HighOnLife2 compatibility overrides
[/Script/StreamlineRHI.StreamlineSettings]
bEnableStreamlineD3D11=False
bEnableStreamlineD3D12=False
bEnableDLSSFGInPlayInEditorViewports=False

[/Script/DLSS.DLSSSettings]
bEnableDLSSD3D11=False
bEnableDLSSD3D12=False
bEnableDLSSVulkan=False
bEnableDLSSInEditorViewports=False
bEnableDLSSInPlayInEditorViewports=False

[SystemSettings]
r.NGX.Enable=0
r.Streamline.InitializePlugin=0
r.Streamline.DLSS.Enable=0
r.Streamline.Reflex.Enable=0
r.Streamline.DLSSG.Enable=0
r.FidelityFX.FSR3.Enabled=0
r.FidelityFX.FI.Enabled=0
r.FidelityFX.DLSSFG.Enabled=0
"""
    private static let minecraftDungeonsEngineIniMarker = "; Vector Minecraft Dungeons browser overrides"
    private static let minecraftDungeonsEngineIniBlock = """
; Vector Minecraft Dungeons browser overrides
[/Script/WebBrowserWidget.WebBrowserSettings]
bCEFGPUAcceleration=False
"""

    func applyBottleRuntimeSelection(to environment: inout [String: String]) {
        switch bottle.settings.runtimeSelection {
        case .auto:
            if shouldAutoUseCrossOverRuntime {
                _ = applyCrossOverRuntimeOverride(to: &environment)
            }
        case .bundled:
            let bundledWine = VectorWineInstaller.binFolder.appending(path: "wine64")
            let bundledWineserver = VectorWineInstaller.binFolder.appending(path: "wineserver")
            environment[Self.runtimeWineOverrideEnvironmentKey] = bundledWine.path(percentEncoded: false)
            environment[Self.runtimeWineserverOverrideEnvironmentKey] = bundledWineserver.path(percentEncoded: false)
        case .compatibility:
            guard let wineBinary = VectorWineInstaller.steamCompatibilityWineBinary(),
                  let wineserverBinary = VectorWineInstaller.steamCompatibilityWineserverBinary() else {
                Logger.wineKit.warning(
                    "Compatibility runtime selected but no compatibility runtime binaries were found."
                )
                return
            }

            environment[Self.runtimeWineOverrideEnvironmentKey] = wineBinary.path(percentEncoded: false)
            environment[Self.runtimeWineserverOverrideEnvironmentKey] = wineserverBinary.path(percentEncoded: false)
        case .crossover:
            guard applyCrossOverRuntimeOverride(to: &environment) else {
                Logger.wineKit.warning(
                    "CrossOver runtime selected but no CrossOver runtime binaries were found."
                )
                return
            }
        case .custom:
            let customWinePath = bottle.settings.customWineBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let customWineserverPath = bottle.settings.customWineserverBinaryPath
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if FileManager.default.isExecutableFile(atPath: customWinePath) {
                environment[Self.runtimeWineOverrideEnvironmentKey] = customWinePath
            }
            if FileManager.default.isExecutableFile(atPath: customWineserverPath) {
                environment[Self.runtimeWineserverOverrideEnvironmentKey] = customWineserverPath
            }
        }
    }

    func applySteamUIRuntimeFallback(to environment: inout [String: String]) {
        guard isSteamProgramPath else { return }
        guard bottle.settings.runtimeSelection == .bundled else { return }
        guard !steamSettingsLaunchesApp() else { return }
        guard let compatibilityWineBinary = VectorWineInstaller.steamCompatibilityWineBinary(),
              let compatibilityWineserverBinary = VectorWineInstaller.steamCompatibilityWineserverBinary() else {
            return
        }

        // Steam's current CEF helper can fail on older bundled runtimes.
        // For Steam UI launches, prefer the dedicated Steam compatibility runtime when available.
        environment[Self.runtimeWineOverrideEnvironmentKey] = compatibilityWineBinary.path(percentEncoded: false)
        environment[Self.runtimeWineserverOverrideEnvironmentKey] =
            compatibilityWineserverBinary.path(percentEncoded: false)
    }

    private var shouldAutoUseCrossOverRuntime: Bool {
        bottle.settings.runtimeSelection == .auto && VectorWineInstaller.isCrossOverBottleURL(bottle.url)
    }

    private var allowsCompatibilityRuntimeOverride: Bool {
        switch bottle.settings.runtimeSelection {
        case .custom, .crossover:
            return false
        case .auto:
            return !VectorWineInstaller.isCrossOverBottleURL(bottle.url)
        case .bundled, .compatibility:
            return true
        }
    }

    @discardableResult
    private func applyCrossOverRuntimeOverride(to environment: inout [String: String]) -> Bool {
        guard let runtime = VectorWineInstaller.crossOverRuntimeBinaries() else {
            return false
        }

        environment[Self.runtimeWineOverrideEnvironmentKey] = runtime.wine.path(percentEncoded: false)
        environment[Self.runtimeWineserverOverrideEnvironmentKey] = runtime.wineserver.path(percentEncoded: false)
        return true
    }

    func applyProfileEnvironment(to environment: inout [String: String]) {
        guard !isSteamProgramPath else { return }
        guard let profile = resolvedGameProfile() else { return }

        applyProfileGraphicsBackendOverrides(profile, to: &environment)

        for (key, value) in profile.environment {
            let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedKey.isEmpty else { continue }
            environment[normalizedKey] = value
        }

        if bottle.settings.trainerSupportMode,
           isTrainerExecutablePath,
           !bottle.settings.safeMultiplayerMode {
            environment["WINE_DISABLE_WRITE_WATCH"] = "1"
        }
    }

    func applyInstallerCompatibilityEnvironmentOverrides(to environment: inout [String: String]) {
        guard shouldApplyInstallerCompatibilityMode else {
            return
        }

        if allowsCompatibilityRuntimeOverride,
           let compatibilityWine = VectorWineInstaller.steamCompatibilityWineBinary(),
           let compatibilityWineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() {
            environment[Self.runtimeWineOverrideEnvironmentKey] = compatibilityWine.path(percentEncoded: false)
            environment[Self.runtimeWineserverOverrideEnvironmentKey] = compatibilityWineserver.path(percentEncoded: false)
        }

        let currentOverrides = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitizedOverrides = stripDLLOverrides(
            from: currentOverrides,
            names: Self.installerDLLOverridesToStrip
        )
        if sanitizedOverrides.isEmpty {
            environment.removeValue(forKey: "WINEDLLOVERRIDES")
        } else {
            environment["WINEDLLOVERRIDES"] = sanitizedOverrides
        }

        environment["WINE_DISABLE_WRITE_WATCH"] = "1"
        environment["VECTOR_INSTALLER_COMPAT_MODE"] = "1"
    }

    private func applyProtonStyleMediaMarkers(to environment: inout [String: String]) {
        environment[Self.protonStyleCompatEnvironmentKey] = "1"
        environment[Self.protonMediaShimsEnvironmentKey] = "1"
        environment[Self.mediaFoundationModeEnvironmentKey] = Self.protonStyleMediaFoundationMode
    }

    func applyMediaPlaybackEnvironmentOverrides(to environment: inout [String: String]) {
        guard bottle.settings.mediaPlaybackCompatibilityMode else {
            return
        }
        guard !isSteamProgramPath else {
            return
        }

        let currentOverrides = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitizedOverrides = stripDLLOverrides(
            from: currentOverrides,
            names: Self.mediaPlaybackDLLOverridesToStrip
        )
        if sanitizedOverrides.isEmpty {
            environment["WINEDLLOVERRIDES"] = Self.mediaPlaybackNativeBuiltinOverrides
        } else {
            environment["WINEDLLOVERRIDES"] = "\(Self.mediaPlaybackNativeBuiltinOverrides);\(sanitizedOverrides)"
        }

        environment[Self.mediaPlaybackPatchEnvironmentKey] = "1"
        applyProtonStyleMediaMarkers(to: &environment)
    }

    func applyHighOnLife2EnvironmentOverrides(to environment: inout [String: String]) {
        guard !isSteamProgramPath else { return }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplyHighOnLife2Compatibility(activeSteamAppID: activeSteamAppID) else {
            return
        }

        // Force the bundled runtime for this title to avoid compatibility-runtime
        // D3D11 feature-level regressions on Apple Silicon.
        environment[Self.runtimeWineOverrideEnvironmentKey] = VectorWineInstaller.binFolder
            .appending(path: "wine64")
            .path(percentEncoded: false)
        environment[Self.runtimeWineserverOverrideEnvironmentKey] = VectorWineInstaller.binFolder
            .appending(path: "wineserver")
            .path(percentEncoded: false)

        applyHighOnLife2DLLOverrides(to: &environment)
        environment["DXVK_ENABLE_NVAPI"] = "0"
        environment["PROTON_ENABLE_NVAPI"] = "0"
        environment["SteamNoOverlayUIDrawing"] = "1"
        environment["DISABLE_VK_LAYER_VALVE_steam_overlay"] = "1"
    }

    func applyParcelSimulatorEnvironmentOverrides(to environment: inout [String: String]) {
        guard !isSteamProgramPath else { return }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplyParcelSimulatorCompatibility(activeSteamAppID: activeSteamAppID) else {
            return
        }

        applyParcelSimulatorDLLOverrides(to: &environment)
        environment["DXVK_ENABLE_NVAPI"] = "0"
        environment["PROTON_ENABLE_NVAPI"] = "0"
        environment["SteamNoOverlayUIDrawing"] = "1"
        environment["DISABLE_VK_LAYER_VALVE_steam_overlay"] = "1"
    }

    func applyMinecraftDungeonsEnvironmentOverrides(to environment: inout [String: String]) {
        guard !isSteamProgramPath else { return }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplyMinecraftDungeonsCompatibility(activeSteamAppID: activeSteamAppID) else {
            return
        }

        // This title's Microsoft sign-in webview can be fragile when global
        // media playback overrides are present. Keep auth path as clean as possible.
        let currentOverrides = environment["WINEDLLOVERRIDES"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let overridesWithoutMedia = stripDLLOverrides(
            from: currentOverrides,
            names: Self.mediaPlaybackDLLOverridesToStrip
        )
        if overridesWithoutMedia.isEmpty {
            environment.removeValue(forKey: "WINEDLLOVERRIDES")
        } else {
            environment["WINEDLLOVERRIDES"] = overridesWithoutMedia
        }
        environment.removeValue(forKey: Self.mediaPlaybackPatchEnvironmentKey)
        applyProtonStyleMediaMarkers(to: &environment)

        if allowsCompatibilityRuntimeOverride,
           let compatibilityWine = VectorWineInstaller.steamCompatibilityWineBinary(),
           let compatibilityWineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() {
            // Prefer the newer compatibility runtime for the Microsoft sign-in
            // overlay and callback handoff. The older bundled runtime is more
            // likely to get stuck on the "page not normally shown" auth loop.
            environment[Self.runtimeWineOverrideEnvironmentKey] = compatibilityWine
                .path(percentEncoded: false)
            environment[Self.runtimeWineserverOverrideEnvironmentKey] = compatibilityWineserver
                .path(percentEncoded: false)
        }

        applyMinecraftDungeonsDLLOverrides(to: &environment)
        environment["DXVK_ENABLE_NVAPI"] = "0"
        environment["PROTON_ENABLE_NVAPI"] = "0"
        environment["SteamNoOverlayUIDrawing"] = "1"
        environment["DISABLE_VK_LAYER_VALVE_steam_overlay"] = "1"
    }

    func applyContentWarningEnvironmentOverrides(to environment: inout [String: String]) {
        guard !isSteamProgramPath else { return }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplyContentWarningCompatibility(activeSteamAppID: activeSteamAppID) else {
            return
        }

        applyContentWarningDLLOverrides(to: &environment)
        environment["DXVK_ENABLE_NVAPI"] = "0"
        environment["PROTON_ENABLE_NVAPI"] = "0"
        environment["SteamNoOverlayUIDrawing"] = "1"
        environment["DISABLE_VK_LAYER_VALVE_steam_overlay"] = "1"
    }

    func applyTitanfall2EnvironmentOverrides(to environment: inout [String: String]) {
        guard !isSteamProgramPath else { return }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplyTitanfall2Compatibility(activeSteamAppID: activeSteamAppID) else {
            return
        }

        applyTitanfall2DLLOverrides(to: &environment)
        environment["DXVK_ENABLE_NVAPI"] = "0"
        environment["PROTON_ENABLE_NVAPI"] = "0"
        environment["SteamNoOverlayUIDrawing"] = "1"
        environment["DISABLE_VK_LAYER_VALVE_steam_overlay"] = "1"
    }

    func applyOriginEnvironmentOverrides(to environment: inout [String: String]) {
        guard !isSteamProgramPath else { return }
        guard shouldApplyOriginCompatibility else {
            return
        }

        if allowsCompatibilityRuntimeOverride,
           let compatibilityWine = VectorWineInstaller.steamCompatibilityWineBinary(),
           let compatibilityWineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() {
            environment[Self.runtimeWineOverrideEnvironmentKey] = compatibilityWine.path(percentEncoded: false)
            environment[Self.runtimeWineserverOverrideEnvironmentKey] = compatibilityWineserver.path(percentEncoded: false)
        }

        applyOriginDLLOverrides(to: &environment)
        environment["DXVK_ENABLE_NVAPI"] = "0"
        environment["PROTON_ENABLE_NVAPI"] = "0"
        environment["SteamNoOverlayUIDrawing"] = "1"
        environment["DISABLE_VK_LAYER_VALVE_steam_overlay"] = "1"
    }

    func applySilentHillFEnvironmentOverrides(to environment: inout [String: String]) {
        guard !isSteamProgramPath else { return }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplySilentHillFCompatibility(activeSteamAppID: activeSteamAppID) else {
            return
        }

        let current = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitized = stripDLLOverrides(from: current, names: Self.silentHillFDLLOverridesToStrip)
        if sanitized.isEmpty {
            environment["WINEDLLOVERRIDES"] = Self.silentHillFDXVKD3D11Overrides
        } else {
            environment["WINEDLLOVERRIDES"] = "\(Self.silentHillFDXVKD3D11Overrides);\(sanitized)"
        }
        appendDLLOverride(&environment, override: "nvapi,nvapi64=d")

        environment["DXVK_ENABLE_NVAPI"] = "0"
        environment["PROTON_ENABLE_NVAPI"] = "0"
        environment["SteamNoOverlayUIDrawing"] = "1"
        environment["DISABLE_VK_LAYER_VALVE_steam_overlay"] = "1"
    }

    func applyElectronWindowEnvironmentOverrides(to environment: inout [String: String]) {
        guard shouldApplyElectronWindowCompatibility else {
            return
        }

        // Prefer the newer compatibility runtime for Electron-based apps.
        if allowsCompatibilityRuntimeOverride,
           let compatibilityWine = VectorWineInstaller.steamCompatibilityWineBinary(),
           let compatibilityWineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() {
            environment[Self.runtimeWineOverrideEnvironmentKey] = compatibilityWine.path(percentEncoded: false)
            environment[Self.runtimeWineserverOverrideEnvironmentKey] = compatibilityWineserver.path(percentEncoded: false)
        }

        let current = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitized = stripDLLOverrides(from: current, names: Self.electronDLLOverridesToStrip)
        if sanitized.isEmpty {
            environment["WINEDLLOVERRIDES"] = "nvapi,nvapi64=d"
        } else {
            environment["WINEDLLOVERRIDES"] = sanitized
            appendDLLOverride(&environment, override: "nvapi,nvapi64=d")
        }

        environment["ROSETTA_ADVERTISE_AVX"] = "1"
        environment["DXVK_ENABLE_NVAPI"] = "0"
        environment["PROTON_ENABLE_NVAPI"] = "0"
        environment["SteamNoOverlayUIDrawing"] = "1"
        environment["DISABLE_VK_LAYER_VALVE_steam_overlay"] = "1"
    }

    func applyDLSSRuntimeTranslationEnvironmentOverrides(to environment: inout [String: String]) {
        guard bottle.settings.dlssRuntimeTranslationEnabled else {
            return
        }

        // Avoid applying broad global overrides to steam.exe directly.
        guard !isSteamProgramPath else {
            return
        }

        let currentOverrides = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitizedOverrides = stripDLLOverrides(
            from: currentOverrides,
            names: Self.dlssTranslationDLLOverridesToStrip
        )
        if sanitizedOverrides.isEmpty {
            environment["WINEDLLOVERRIDES"] = Self.dlssTranslationBuiltinD3DOverrides
        } else {
            environment["WINEDLLOVERRIDES"] =
                "\(Self.dlssTranslationBuiltinD3DOverrides);\(sanitizedOverrides)"
        }

        if !bottle.settings.dlssFrameGenerationFallbackEnabled {
            appendDLLOverride(&environment, override: Self.dlssFrameGenerationDisableOverrides)
        }

        environment[Self.dxmtNVExtensionsEnvironmentKey] = "1"
        environment[Self.dlssTranslationMarkerEnvironmentKey] = "1"
        environment["VECTOR_FORCE_DISABLE_DXVK"] = "1"
        environment.removeValue(forKey: "DXVK_ENABLE_NVAPI")
        environment.removeValue(forKey: "PROTON_ENABLE_NVAPI")
    }

    func electronWindowArguments() -> [String] {
        guard shouldApplyElectronWindowCompatibility else {
            return []
        }

        return Self.electronCompatibilityArguments
    }

    func profileArguments() -> [String] {
        guard !isSteamProgramPath else { return [] }
        guard let profile = resolvedGameProfile() else { return [] }

        let arguments = profile.arguments.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !arguments.isEmpty else { return [] }

        return arguments.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    func minecraftDungeonsCompatibilityArguments() -> [String] {
        guard !isSteamProgramPath else { return [] }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplyMinecraftDungeonsCompatibility(activeSteamAppID: activeSteamAppID) else {
            return []
        }

        return Self.minecraftDungeonsProfileArguments
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    func d3d11CompatibilityArguments() -> [String] {
        guard bottle.settings.forceD3D11Compatibility else { return [] }
        guard !isSteamProgramPath else { return [] }
        guard !shouldApplyElectronWindowCompatibility else { return [] }
        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shouldApplyMinecraftDungeonsCompatibility(activeSteamAppID: activeSteamAppID) else {
            return []
        }
        if let profile = resolvedGameProfile(), profileRequestsDX12(profile) {
            return []
        }
        return ["-force-d3d11", "-dx11", "-d3d11"]
    }

    func resolvedLaunchExecutableURL(arguments: inout [String]) -> URL {
        guard !isSteamProgramPath else {
            return url
        }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        if shouldApplyParcelSimulatorCompatibility(activeSteamAppID: activeSteamAppID),
           url.lastPathComponent.caseInsensitiveCompare("parcel.exe") == .orderedSame {
            let gameRoot = url.deletingLastPathComponent()
            let candidates = [
                gameRoot
                    .appending(path: "parcel")
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: "parcel-Win64-Shipping.exe"),
                gameRoot
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: "parcel-Win64-Shipping.exe")
            ]

            if let shippingExecutable = candidates.first(where: {
                FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
            }) {
                return shippingExecutable
            }
        }

        let minecraftDungeonsLauncherName = url.lastPathComponent.lowercased()
        if shouldApplyMinecraftDungeonsCompatibility(activeSteamAppID: activeSteamAppID),
           Self.minecraftDungeonsLauncherExecutableNames.contains(minecraftDungeonsLauncherName) {
            let gameRoot = url.deletingLastPathComponent()
            let candidates = [
                gameRoot
                    .appending(path: "Dungeons")
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: "Dungeons-Win64-Shipping.exe"),
                gameRoot
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: "Dungeons-Win64-Shipping.exe"),
                // Some non-Steam builds ship the playable binary as Dungeons.exe in Win64.
                gameRoot
                    .appending(path: "Dungeons")
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: "Dungeons.exe"),
                gameRoot
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: "Dungeons.exe"),
                gameRoot
                    .appending(path: "Dungeons-Win64-Shipping.exe")
            ]

            if let shippingExecutable = candidates.first(where: {
                FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
            }) {
                return shippingExecutable
            }
        }

        let silentHillFLauncherName = url.lastPathComponent.lowercased()
        if shouldApplySilentHillFCompatibility(activeSteamAppID: activeSteamAppID),
           Self.silentHillFLauncherExecutableNames.contains(silentHillFLauncherName) {
            let gameRoot = url.deletingLastPathComponent()
            let candidates = [
                gameRoot
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: "SilentHillf-Win64-Shipping.exe"),
                gameRoot
                    .appending(path: "SilentHillf")
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: "SilentHillf-Win64-Shipping.exe"),
                gameRoot
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: Self.silentHillFExecutableName),
                gameRoot
                    .appending(path: "SilentHillf")
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: Self.silentHillFExecutableName)
            ]

            if let shippingExecutable = candidates.first(where: {
                FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
            }) {
                return shippingExecutable
            }
        }

        if shouldApplyTitanfall2Compatibility(activeSteamAppID: activeSteamAppID),
           url.lastPathComponent.caseInsensitiveCompare("Titanfall2Launcher.exe") == .orderedSame {
            let gameRoot = url.deletingLastPathComponent()
            let candidates = [
                gameRoot.appending(path: "Titanfall2.exe"),
                gameRoot.appending(path: "bin").appending(path: "x64_retail").appending(path: "Titanfall2.exe")
            ]

            if let shippingExecutable = candidates.first(where: {
                FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
            }) {
                return shippingExecutable
            }
        }

        guard shouldApplyHighOnLife2Compatibility(activeSteamAppID: activeSteamAppID) else {
            return url
        }

        guard url.lastPathComponent.caseInsensitiveCompare("HighOnLife2.exe") == .orderedSame else {
            return url
        }

        let gameRoot = url.deletingLastPathComponent()
        let candidates = [
            gameRoot
                .appending(path: "HighOnLife2")
                .appending(path: "Binaries")
                .appending(path: "Win64")
                .appending(path: "HighOnLife2-Win64-Shipping.exe"),
            gameRoot
                .appending(path: "Binaries")
                .appending(path: "Win64")
                .appending(path: "HighOnLife2-Win64-Shipping.exe")
        ]

        guard let shippingExecutable = candidates.first(where: {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }) else {
            return url
        }

        if !arguments.contains(where: { $0.caseInsensitiveCompare("HighOnLife2") == .orderedSame }) {
            arguments.insert("HighOnLife2", at: 0)
        }

        return shippingExecutable
    }

    func prepareLaunchCompatibilityShims() {
        if isSteamProgramPath {
            prepareSteamInstalledGameShims()
            return
        }
        if shouldApplyOriginCompatibility
            || shouldApplyTitanfall2Compatibility(
                activeSteamAppID: bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
            ) {
            ensureOriginCompatibilityConfig()
        }
        ensureHighOnLife2NGXShimIfNeeded(for: url)
        ensureHighOnLife2FSRShimsIfNeeded(for: url)
        ensureHighOnLife2EngineIniOverrides()
        ensureMinecraftDungeonsEngineIniOverrides()
    }

    func applySteamEnvironmentOverrides(to environment: inout [String: String]) {
        guard isSteamProgramPath else { return }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)

        if shouldApplyHighOnLife2SteamEnvironmentOverrides(activeSteamAppID: activeSteamAppID) {
            // Keep High On Life 2 DLL overrides app-scoped via AppDefaults.
            // Applying broad WINEDLLOVERRIDES to steam.exe destabilizes steamwebhelper.
            environment["DXVK_ENABLE_NVAPI"] = "0"
            environment["PROTON_ENABLE_NVAPI"] = "0"
        }
        if shouldApplyParcelSimulatorSteamEnvironmentOverrides(activeSteamAppID: activeSteamAppID) {
            // Keep Parcel Simulator overrides app-scoped through AppDefaults.
            environment["DXVK_ENABLE_NVAPI"] = "0"
            environment["PROTON_ENABLE_NVAPI"] = "0"
        }
        if shouldApplyMinecraftDungeonsSteamEnvironmentOverrides(activeSteamAppID: activeSteamAppID) {
            // Minecraft Dungeons is commonly launched from inside Steam, so the
            // child process may not receive Vector's per-executable profile.
            // Keep a DXVK D3D11 route in the Steam environment and protect
            // steamwebhelper.exe through AppDefaults before launch.
            environment["DXVK_ENABLE_NVAPI"] = "0"
            environment["PROTON_ENABLE_NVAPI"] = "0"
            environment["DXVK_ASYNC"] = "1"
            environment[Self.effectiveBackendEnvironmentKey] = GraphicsBackendMode.dxvk.rawValue
            environment[Self.effectiveFallbackBackendEnvironmentKey] = GraphicsBackendMode.wined3d.rawValue
            environment.removeValue(forKey: "VECTOR_FORCE_DISABLE_DXVK")

            if allowsCompatibilityRuntimeOverride,
               let compatibilityWine = VectorWineInstaller.steamCompatibilityWineBinary(),
               let compatibilityWineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() {
                // Steam-based Minecraft Dungeons launches need the newer
                // compatibility runtime for the Microsoft auth overlay.
                environment[Self.runtimeWineOverrideEnvironmentKey] = compatibilityWine
                    .path(percentEncoded: false)
                environment[Self.runtimeWineserverOverrideEnvironmentKey] = compatibilityWineserver
                    .path(percentEncoded: false)
            }

            // Avoid global media playback shim interference on auth webviews.
            let currentOverrides = environment["WINEDLLOVERRIDES"]?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let overridesWithoutMedia = stripDLLOverrides(
                from: currentOverrides,
                names: Self.mediaPlaybackDLLOverridesToStrip
            )
            if overridesWithoutMedia.isEmpty {
                environment.removeValue(forKey: "WINEDLLOVERRIDES")
            } else {
                environment["WINEDLLOVERRIDES"] = overridesWithoutMedia
            }
            environment.removeValue(forKey: Self.mediaPlaybackPatchEnvironmentKey)
            applyProtonStyleMediaMarkers(to: &environment)
            applyMinecraftDungeonsDLLOverrides(to: &environment)
        }
        if shouldApplyContentWarningSteamEnvironmentOverrides(activeSteamAppID: activeSteamAppID) {
            // Keep Content Warning overrides app-scoped through AppDefaults.
            environment["DXVK_ENABLE_NVAPI"] = "0"
            environment["PROTON_ENABLE_NVAPI"] = "0"
        }
        if shouldApplyTitanfall2SteamEnvironmentOverrides(activeSteamAppID: activeSteamAppID) {
            // Keep Titanfall 2 overrides app-scoped through AppDefaults.
            environment["DXVK_ENABLE_NVAPI"] = "0"
            environment["PROTON_ENABLE_NVAPI"] = "0"

            // EA bootstrap and launcher startup are more reliable on the newer
            // Steam compatibility runtime than the bundled legacy runtime.
            if allowsCompatibilityRuntimeOverride,
               let compatibilityWine = VectorWineInstaller.steamCompatibilityWineBinary(),
               let compatibilityWineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() {
                environment[Self.runtimeWineOverrideEnvironmentKey] = compatibilityWine.path(percentEncoded: false)
                environment[Self.runtimeWineserverOverrideEnvironmentKey] = compatibilityWineserver.path(percentEncoded: false)
            }
        }
        if shouldApplySilentHillFSteamEnvironmentOverrides(activeSteamAppID: activeSteamAppID) {
            // Keep Silent Hill f overrides app-scoped through AppDefaults.
            environment["DXVK_ENABLE_NVAPI"] = "0"
            environment["PROTON_ENABLE_NVAPI"] = "0"
        }

        if bottle.settings.steamDisableOverlay {
            environment["SteamNoOverlayUIDrawing"] = "1"
            environment["DISABLE_VK_LAYER_VALVE_steam_overlay"] = "1"
        }
    }

    func shouldLaunchSilentHillFViaSteam(activeSteamAppID: String) -> Bool {
        shouldApplySilentHillFCompatibility(activeSteamAppID: activeSteamAppID)
    }

    func shouldLaunchMinecraftDungeonsViaSteam(activeSteamAppID: String) -> Bool {
        guard shouldApplyMinecraftDungeonsCompatibility(activeSteamAppID: activeSteamAppID) else {
            return false
        }
        guard !isSteamProgramPath else {
            return false
        }

        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedAppID == Self.minecraftDungeonsSteamAppID {
            return true
        }

        let normalizedPath = url.path(percentEncoded: false).lowercased()
        return normalizedPath.contains("/steamapps/common/minecraftdungeons/")
            || normalizedPath.contains("/steamapps/common/minecraft dungeons/")
            || normalizedPath.contains("/steamapps/common/dungeons/")
    }

    func steamLaunchExecutableURL() -> URL? {
        let steamCandidates = [
            bottle.url
                .appending(path: "drive_c")
                .appending(path: "Program Files (x86)")
                .appending(path: "Steam")
                .appending(path: "steam.exe"),
            bottle.url
                .appending(path: "drive_c")
                .appending(path: "Program Files")
                .appending(path: "Steam")
                .appending(path: "steam.exe")
        ]

        return steamCandidates.first {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    func silentHillFSteamLaunchArguments() -> [String] {
        steamLaunchArguments(appID: Self.silentHillFSteamAppID, launchOptions: Self.silentHillFSteamLaunchOptions)
    }

    func minecraftDungeonsSteamLaunchArguments() -> [String] {
        steamLaunchArguments(
            appID: Self.minecraftDungeonsSteamAppID,
            launchOptions: Self.minecraftDungeonsSteamLaunchOptions
        )
    }

    private func steamLaunchArguments(appID: String, launchOptions: String) -> [String] {
        var arguments = ["-applaunch", appID]
        arguments.append(contentsOf: launchOptions.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        return arguments
    }

    func sanitizeSteamEnvironment(
        _ environment: inout [String: String],
        usingCompatibilityRuntime: Bool
    ) {
        if usingCompatibilityRuntime, steamSettingsLaunchesApp() {
            // Preserve bottle graphics env only for direct Steam app-launch
            // commands. Plain Steam client startup must stay on Wine builtins.
            return
        }

        let shouldPreserveGraphicsPipeline = bottle.settings.forceD3D11Compatibility
            || bottle.settings.graphicsBackendMode == .dxvk
            || bottle.settings.graphicsBackendMode == .dxmt
            || bottle.settings.dxvk

        environment["LC_ALL"] = "C"
        environment["LANG"] = "C"
        environment.removeValue(forKey: "LANGUAGE")
        environment["DXVK_ASYNC"] = "0"
        environment["DXVK_HUD"] = "0"
        environment["DXVK_LOG_LEVEL"] = "none"
        environment["VECTOR_FORCE_DISABLE_DXVK"] = "1"
        environment[Wine.steamGraphicsIsolationEnvKey] = "1"
        environment.removeValue(forKey: Self.effectiveBackendEnvironmentKey)
        environment.removeValue(forKey: Self.effectiveFallbackBackendEnvironmentKey)
        if shouldPreserveGraphicsPipeline {
            environment.removeValue(forKey: "WINEDLLOVERRIDES")
            environment.removeValue(forKey: "ROSETTA_ADVERTISE_AVX")
        } else {
            environment.removeValue(forKey: "WINEDLLOVERRIDES")
            environment["ROSETTA_ADVERTISE_AVX"] = "0"
        }
    }

    func steamPackageArchiveURL() -> String {
        let fallbackURL = BottleSteamConfig.defaultArchiveURL
        let configuredURL = bottle.settings.steamPackageArchiveURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !configuredURL.isEmpty else {
            return fallbackURL
        }

        return configuredURL
    }

    func shouldProceedWithLaunchPreflight() async -> Bool {
        let detections = detectedAntiCheatArtifacts(maxCount: 12)
        let protectedAssessment = VectorProtectedTitlePolicyEngine.assessLaunch(
            programURL: url,
            bottle: bottle,
            activeSteamAppID: bottle.settings.activeSteamAppID,
            detectedArtifacts: detections
        )
        if protectedAssessment.shouldBlockLocalLaunch, let title = protectedAssessment.matchedTitle {
            await MainActor.run {
                _ = antiCheatConfirmationAlert(
                    title: "\(title.title) requires official anti-cheat support",
                    message: protectedLaunchBlockMessage(for: protectedAssessment),
                    continueTitle: nil
                )
            }
            return false
        }

        guard !isSteamProgramPath else { return true }

        if bottle.settings.safeMultiplayerMode, isTrainerExecutablePath {
            await MainActor.run {
                _ = antiCheatConfirmationAlert(
                    title: "Launch blocked by Safe Multiplayer Mode",
                    message: """
                    Safe Multiplayer Mode is enabled for this bottle.
                    Trainer/injection executables are blocked to reduce anti-cheat and multiplayer risk.
                    """,
                    continueTitle: nil
                )
            }
            return false
        }

        let mode: AntiCheatPreflightMode = bottle.settings.safeMultiplayerMode
            ? .block
            : bottle.settings.antiCheatPreflightMode
        guard mode != .off else {
            return true
        }

        guard !detections.isEmpty else {
            return true
        }

        if bottle.settings.allowUnsupportedAntiCheatLaunches, !bottle.settings.safeMultiplayerMode {
            return true
        }

        let details = detections.joined(separator: "\n")
        switch mode {
        case .off:
            return true
        case .warn:
            return await MainActor.run {
                antiCheatConfirmationAlert(
                    title: "Potential anti-cheat detected",
                    message: """
                    Vector detected anti-cheat artifacts for \(self.url.lastPathComponent).
                    The title may fail to launch or may not be supported.

                    \(details)
                    """,
                    continueTitle: "Continue"
                )
            }
        case .block:
            await MainActor.run {
                _ = antiCheatConfirmationAlert(
                    title: "Launch blocked by anti-cheat preflight",
                    message: """
                    Vector blocked this launch because anti-cheat artifacts were detected and this bottle
                    is set to block unsupported anti-cheat launches.

                    \(details)
                    """,
                    continueTitle: nil
                )
            }
            return false
        }
    }

    @MainActor
    private func antiCheatConfirmationAlert(title: String, message: String, continueTitle: String?) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning

        if let continueTitle {
            alert.addButton(withTitle: continueTitle)
            alert.addButton(withTitle: "Cancel")
            return alert.runModal() == .alertFirstButtonReturn
        }

        alert.addButton(withTitle: "OK")
        alert.runModal()
        return false
    }

    private func protectedLaunchBlockMessage(for assessment: ProtectedLaunchAssessment) -> String {
        let title = assessment.matchedTitle?.title ?? "This protected title"
        let reasons = assessment.reasons.joined(separator: "\n")
        let fallbackOptions = assessment.matchedTitle?.fallbackPlayOptions
            .map { "- \($0)" }
            .joined(separator: "\n") ?? "- Windows PC\n- Officially supported SteamOS/Proton device\n- Remote Play"
        let artifacts = assessment.detectedArtifacts.prefix(6)
            .map { "- \($0)" }
            .joined(separator: "\n")
        let artifactSection = artifacts.isEmpty ? "" : "\n\nDetected artifacts:\n\(artifacts)"

        return """
        \(title) is classified as blocked anti-cheat/protected multiplayer in Vector.

        \(reasons)

        Supported alternatives:
        \(fallbackOptions)\(artifactSection)
        """
    }

    private var isSteamProgramPath: Bool {
        url.lastPathComponent.caseInsensitiveCompare(Self.steamExecutableName) == .orderedSame
    }

    private var isTrainerExecutablePath: Bool {
        let lowercasedPath = url.path(percentEncoded: false).lowercased()
        return lowercasedPath.contains("wemod")
            || lowercasedPath.contains("cheat engine")
            || lowercasedPath.contains("trainer")
    }

    private var isInstallerExecutablePath: Bool {
        let executableName = url.lastPathComponent.lowercased()
        if Self.installerExecutableNames.contains(executableName) {
            return true
        }

        return executableName.contains("setup")
            || executableName.contains("installer")
            || executableName.contains("install")
            || executableName.contains("bootstrap")
            || executableName.contains("update")
            || executableName.contains("patcher")
    }

    private var shouldApplyInstallerCompatibilityMode: Bool {
        bottle.settings.installerCompatibilityMode
            && !isSteamProgramPath
            && isInstallerExecutablePath
    }

    private func resolvedGameProfile() -> BottleGameProfile? {
        let steamAppID = bottle.settings.activeSteamAppID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let programPath = url.path(percentEncoded: false)

        if let profile = bottle.settings.profile(
            forProgramPath: programPath,
            steamAppID: steamAppID
        ) {
            return profile
        }

        return inferredBuiltInProfile(
            forProgramPath: programPath,
            steamAppID: steamAppID
        )
    }

    private func inferredBuiltInProfile(
        forProgramPath programPath: String,
        steamAppID: String
    ) -> BottleGameProfile? {
        let normalizedProgramPath = programPath.lowercased()

        let isHighOnLife2 = isHighOnLife2Executable(
            path: normalizedProgramPath,
            activeSteamAppID: steamAppID
        )
        if isHighOnLife2 {
            return BottleGameProfile(
                name: "Auto: High On Life 2",
                executableMatch: Self.highOnLife2ExecutableName,
                arguments: Self.highOnLife2ProfileArguments,
                environment: [
                    "WINEDLLOVERRIDES":
                        "\(Self.highOnLife2BuiltinD3DOverrides);nvapi,nvapi64=d;\(Self.highOnLife2FSRNativeOverrides);\(Self.highOnLife2NvidiaPluginDisableOverrides)",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            )
        }

        let isParcelSimulator = isParcelSimulatorExecutable(
            path: normalizedProgramPath,
            activeSteamAppID: steamAppID
        )
        if isParcelSimulator {
            return BottleGameProfile(
                name: "Auto: Parcel Simulator",
                executableMatch: Self.parcelSimulatorExecutableName,
                arguments: Self.parcelSimulatorProfileArguments,
                environment: [
                    "WINEDLLOVERRIDES": "\(Self.parcelSimulatorBuiltinD3DOverrides);nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            )
        }

        let isMinecraftDungeons = isMinecraftDungeonsExecutable(
            path: normalizedProgramPath,
            activeSteamAppID: steamAppID
        )
        if isMinecraftDungeons {
            return BottleGameProfile(
                name: "Auto: Minecraft Dungeons",
                executableMatch: Self.minecraftDungeonsExecutableName,
                arguments: Self.minecraftDungeonsProfileArguments,
                environment: [
                    "WINEDLLOVERRIDES": "\(Self.minecraftDungeonsBuiltinD3DOverrides);nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0",
                    Self.protonStyleCompatEnvironmentKey: "1",
                    Self.protonMediaShimsEnvironmentKey: "1",
                    Self.mediaFoundationModeEnvironmentKey: Self.protonStyleMediaFoundationMode
                ]
            )
        }

        let isContentWarning = isContentWarningExecutable(
            path: normalizedProgramPath,
            activeSteamAppID: steamAppID
        )
        if isContentWarning {
            return BottleGameProfile(
                name: "Auto: Content Warning",
                executableMatch: Self.contentWarningExecutableName,
                arguments: Self.contentWarningProfileArguments,
                environment: [
                    "WINEDLLOVERRIDES": "\(Self.contentWarningDXVKD3DOverrides);nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            )
        }

        let isTitanfall2 = isTitanfall2Executable(
            path: normalizedProgramPath,
            activeSteamAppID: steamAppID
        )
        if isTitanfall2 {
            return BottleGameProfile(
                name: "Auto: Titanfall 2",
                executableMatch: Self.titanfall2ExecutableName,
                arguments: Self.titanfall2ProfileArguments,
                environment: [
                    "WINEDLLOVERRIDES": "\(Self.titanfall2DXVKD3DOverrides);nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            )
        }

        let isOrigin = isOriginExecutable(path: normalizedProgramPath)
        if isOrigin {
            return BottleGameProfile(
                name: "Auto: Origin / EA App",
                executableMatch: url.lastPathComponent.lowercased(),
                arguments: Self.originProfileArguments,
                environment: [
                    "WINEDLLOVERRIDES": "\(Self.originVersionOverride);nvapi,nvapi64=d",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0"
                ]
            )
        }

        let isForzaHorizon6 = isForzaHorizon6Executable(
            path: normalizedProgramPath,
            activeSteamAppID: steamAppID
        )
        if isForzaHorizon6 {
            return BottleGameProfile(
                name: "Auto: Forza Horizon 6",
                executableMatch: Self.forzaHorizon6ExecutableName,
                arguments: Self.forzaHorizon6ProfileArguments,
                environment: [
                    "WINEDLLOVERRIDES": "\(Self.forzaHorizon6D3DMetalOverrides);nvapi,nvapi64=d",
                    "VECTOR_FORCE_DISABLE_DXVK": "1",
                    "SteamNoOverlayUIDrawing": "1",
                    "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                    "DXVK_ENABLE_NVAPI": "0",
                    "PROTON_ENABLE_NVAPI": "0",
                    "ROSETTA_ADVERTISE_AVX": "1"
                ],
                graphicsBackendOverride: .d3dMetal,
                fallbackGraphicsBackend: .dxvk
            )
        }

        let isSilentHillF = isSilentHillFExecutable(
            path: normalizedProgramPath,
            activeSteamAppID: steamAppID
        )
        guard isSilentHillF else {
            return nil
        }

        return BottleGameProfile(
            name: "Auto: Silent Hill f",
            executableMatch: Self.silentHillFExecutableName,
            arguments: Self.silentHillFProfileArguments,
            environment: [
                "WINEDLLOVERRIDES": "\(Self.silentHillFDXVKD3D11Overrides);nvapi,nvapi64=d",
                "SteamNoOverlayUIDrawing": "1",
                "DISABLE_VK_LAYER_VALVE_steam_overlay": "1",
                "DXVK_ENABLE_NVAPI": "0",
                "PROTON_ENABLE_NVAPI": "0"
            ]
        )
    }

    func shouldApplyHighOnLife2Compatibility(activeSteamAppID: String) -> Bool {
        if isHighOnLife2Executable(path: url.path(percentEncoded: false).lowercased(), activeSteamAppID: activeSteamAppID) {
            return true
        }

        guard isSteamProgramPath else {
            return false
        }

        return steamContainsHighOnLife2Install(inSteamRoot: url.deletingLastPathComponent())
    }

    func shouldApplyParcelSimulatorCompatibility(activeSteamAppID: String) -> Bool {
        if isParcelSimulatorExecutable(path: url.path(percentEncoded: false).lowercased(), activeSteamAppID: activeSteamAppID) {
            return true
        }

        guard isSteamProgramPath else {
            return false
        }

        return steamContainsParcelSimulatorInstall(inSteamRoot: url.deletingLastPathComponent())
    }

    func shouldApplyMinecraftDungeonsCompatibility(activeSteamAppID: String) -> Bool {
        if isMinecraftDungeonsExecutable(path: url.path(percentEncoded: false).lowercased(), activeSteamAppID: activeSteamAppID) {
            return true
        }

        guard isSteamProgramPath else {
            return false
        }

        return steamContainsMinecraftDungeonsInstall(inSteamRoot: url.deletingLastPathComponent())
    }

    func shouldApplyContentWarningCompatibility(activeSteamAppID: String) -> Bool {
        if isContentWarningExecutable(path: url.path(percentEncoded: false).lowercased(), activeSteamAppID: activeSteamAppID) {
            return true
        }

        guard isSteamProgramPath else {
            return false
        }

        return steamContainsContentWarningInstall(inSteamRoot: url.deletingLastPathComponent())
    }

    func shouldApplyTitanfall2Compatibility(activeSteamAppID: String) -> Bool {
        if isTitanfall2Executable(path: url.path(percentEncoded: false).lowercased(), activeSteamAppID: activeSteamAppID) {
            return true
        }

        guard isSteamProgramPath else {
            return false
        }

        return steamContainsTitanfall2Install(inSteamRoot: url.deletingLastPathComponent())
    }

    func shouldApplySilentHillFCompatibility(activeSteamAppID: String) -> Bool {
        if isSilentHillFExecutable(path: url.path(percentEncoded: false).lowercased(), activeSteamAppID: activeSteamAppID) {
            return true
        }

        guard isSteamProgramPath else {
            return false
        }

        return steamContainsSilentHillFInstall(inSteamRoot: url.deletingLastPathComponent())
    }

    func shouldApplyForzaHorizon6Compatibility(activeSteamAppID: String) -> Bool {
        if isForzaHorizon6Executable(path: url.path(percentEncoded: false).lowercased(), activeSteamAppID: activeSteamAppID) {
            return true
        }

        guard isSteamProgramPath else {
            return false
        }

        return steamContainsForzaHorizon6Install(inSteamRoot: url.deletingLastPathComponent())
    }

    private func shouldApplyHighOnLife2SteamEnvironmentOverrides(activeSteamAppID: String) -> Bool {
        guard isSteamProgramPath else {
            return false
        }

        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchesHighOnLife2AppID = normalizedAppID == Self.highOnLife2SteamAppID
            || normalizedAppID == Self.highOnLife2LegacySteamAppID
        guard matchesHighOnLife2AppID else {
            return false
        }

        // Only apply game-specific env overrides when this Steam entry is set to
        // launch an app directly, not when opening the Steam client itself.
        return steamSettingsLaunchesApp()
    }

    private func shouldApplyParcelSimulatorSteamEnvironmentOverrides(activeSteamAppID: String) -> Bool {
        guard isSteamProgramPath else {
            return false
        }

        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedAppID == Self.parcelSimulatorSteamAppID else {
            return false
        }

        return steamSettingsLaunchesApp()
    }

    private func shouldApplyMinecraftDungeonsSteamEnvironmentOverrides(activeSteamAppID: String) -> Bool {
        guard isSteamProgramPath else {
            return false
        }

        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedAppID == Self.minecraftDungeonsSteamAppID else {
            return false
        }

        return steamSettingsLaunchesApp()
    }

    private func shouldApplyContentWarningSteamEnvironmentOverrides(activeSteamAppID: String) -> Bool {
        guard isSteamProgramPath else {
            return false
        }

        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedAppID == Self.contentWarningSteamAppID else {
            return false
        }

        return steamSettingsLaunchesApp()
    }

    private func shouldApplyTitanfall2SteamEnvironmentOverrides(activeSteamAppID: String) -> Bool {
        guard isSteamProgramPath else {
            return false
        }

        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedAppID == Self.titanfall2SteamAppID else {
            return false
        }

        return steamSettingsLaunchesApp()
    }

    private func shouldApplySilentHillFSteamEnvironmentOverrides(activeSteamAppID: String) -> Bool {
        guard isSteamProgramPath else {
            return false
        }

        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedAppID == Self.silentHillFSteamAppID else {
            return false
        }

        return steamSettingsLaunchesApp()
    }

    private func isHighOnLife2Executable(path: String, activeSteamAppID: String) -> Bool {
        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.contains(Self.highOnLife2ExecutableName)
            || path.contains("/highonlife2/")
            || normalizedAppID == Self.highOnLife2SteamAppID
            || normalizedAppID == Self.highOnLife2LegacySteamAppID
    }

    private func isParcelSimulatorExecutable(path: String, activeSteamAppID: String) -> Bool {
        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.contains(Self.parcelSimulatorExecutableName)
            || path.contains("/parcel simulator/")
            || path.hasSuffix("/\(Self.parcelSimulatorLauncherExecutableName)")
            || normalizedAppID == Self.parcelSimulatorSteamAppID
    }

    private func isMinecraftDungeonsExecutable(path: String, activeSteamAppID: String) -> Bool {
        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.contains(Self.minecraftDungeonsExecutableName)
            || Self.minecraftDungeonsLauncherExecutableNames.contains {
                path.hasSuffix("/\($0)")
            }
            || path.contains("/minecraft dungeons/")
            || path.contains("/minecraftdungeons/")
            || path.contains("/dungeons/")
            || normalizedAppID == Self.minecraftDungeonsSteamAppID
    }

    private func isContentWarningExecutable(path: String, activeSteamAppID: String) -> Bool {
        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.contains(Self.contentWarningExecutableName)
            || path.contains("/content warning/")
            || path.contains("/contentwarning/")
            || normalizedAppID == Self.contentWarningSteamAppID
    }

    private func isTitanfall2Executable(path: String, activeSteamAppID: String) -> Bool {
        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.contains(Self.titanfall2ExecutableName)
            || path.contains("/titanfall2/")
            || path.contains("/titanfall 2/")
            || normalizedAppID == Self.titanfall2SteamAppID
    }

    private func isOriginExecutable(path: String) -> Bool {
        let executableName = URL(fileURLWithPath: path).lastPathComponent.lowercased()
        return Self.originExecutableNames.contains(executableName)
            || path.contains("/origin/")
            || path.contains("/ea desktop/")
            || path.contains("/ea app/")
            || path.contains("/electronic arts/ea desktop/")
    }

    private func isSilentHillFExecutable(path: String, activeSteamAppID: String) -> Bool {
        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchesKnownLauncher = Self.silentHillFLauncherExecutableNames.contains { launcherName in
            path.hasSuffix("/\(launcherName)")
        }
        return path.contains(Self.silentHillFExecutableName)
            || path.contains("/silent hill f/")
            || path.contains("/silenthillf/")
            || matchesKnownLauncher
            || normalizedAppID == Self.silentHillFSteamAppID
    }

    private func isForzaHorizon6Executable(path: String, activeSteamAppID: String) -> Bool {
        let normalizedAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.contains(Self.forzaHorizon6ExecutableName)
            || path.contains("/forza horizon 6/")
            || path.contains("/forzahorizon6/")
            || normalizedAppID == Self.forzaHorizon6SteamAppID
    }

    private var shouldApplyOriginCompatibility: Bool {
        isOriginExecutable(path: url.path(percentEncoded: false).lowercased())
    }

    private var shouldApplyElectronWindowCompatibility: Bool {
        guard !isSteamProgramPath else {
            return false
        }
        return isLikelyElectronProgramPath
    }

    private var isLikelyElectronProgramPath: Bool {
        let normalizedPath = url.path(percentEncoded: false).lowercased()
        let executableName = url.lastPathComponent.lowercased()

        if Self.electronExecutableNames.contains(executableName) {
            return true
        }

        if normalizedPath.contains("/wemod/")
            || normalizedPath.contains("/wand/")
            || normalizedPath.contains("/wand-")
            || normalizedPath.contains("/squirreltemp/") {
            return true
        }

        return hasNearbyElectronResources()
    }

    private func hasNearbyElectronResources() -> Bool {
        let executableDirectory = url.deletingLastPathComponent()
        let resourcesDirectory = executableDirectory.appending(path: "resources")
        let candidates = [
            resourcesDirectory.appending(path: "app.asar"),
            resourcesDirectory.appending(path: "app.asar.unpacked"),
            resourcesDirectory.appending(path: "app"),
            executableDirectory.appending(path: "chrome_elf.dll"),
            executableDirectory.appending(path: "vk_swiftshader_icd.json")
        ]

        return candidates.contains {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    func steamSettingsLaunchesApp() -> Bool {
        var arguments = settings.arguments.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        normalizeSteamAppLaunchArguments(
            arguments: &arguments,
            fallbackAppID: bottle.settings.activeSteamAppID
        )
        return steamLaunchesSpecificApp(arguments: arguments)
    }

    private func steamContainsHighOnLife2Install(inSteamRoot steamRoot: URL) -> Bool {
        let commonRoot = steamRoot
            .appending(path: "steamapps")
            .appending(path: "common")
        let candidates = [
            commonRoot
                .appending(path: "HighOnLife2")
                .appending(path: "HighOnLife2")
                .appending(path: "Binaries")
                .appending(path: "Win64")
                .appending(path: "HighOnLife2-Win64-Shipping.exe"),
            commonRoot
                .appending(path: "HighOnLife2")
                .appending(path: "Binaries")
                .appending(path: "Win64")
                .appending(path: "HighOnLife2-Win64-Shipping.exe")
        ]

        return candidates.contains {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    private func steamContainsParcelSimulatorInstall(inSteamRoot steamRoot: URL) -> Bool {
        let commonRoot = steamRoot
            .appending(path: "steamapps")
            .appending(path: "common")
        let candidates = [
            commonRoot
                .appending(path: "Parcel Simulator")
                .appending(path: "parcel")
                .appending(path: "Binaries")
                .appending(path: "Win64")
                .appending(path: "parcel-Win64-Shipping.exe"),
            commonRoot
                .appending(path: "Parcel Simulator")
                .appending(path: "Binaries")
                .appending(path: "Win64")
                .appending(path: "parcel-Win64-Shipping.exe")
        ]

        return candidates.contains {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    private func steamContainsMinecraftDungeonsInstall(inSteamRoot steamRoot: URL) -> Bool {
        let commonRoot = steamRoot
            .appending(path: "steamapps")
            .appending(path: "common")
        let rootCandidates = [
            "Minecraft Dungeons",
            "MinecraftDungeons",
            "Dungeons"
        ]
        let executableCandidates = rootCandidates.flatMap { rootName in
            [
                commonRoot
                    .appending(path: rootName)
                    .appending(path: "Dungeons")
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: "Dungeons-Win64-Shipping.exe"),
                commonRoot
                    .appending(path: rootName)
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: "Dungeons-Win64-Shipping.exe"),
                commonRoot
                    .appending(path: rootName)
                    .appending(path: "Dungeons-Win64-Shipping.exe"),
                commonRoot
                    .appending(path: rootName)
                    .appending(path: "MinecraftDungeons.exe")
            ]
        }

        return executableCandidates.contains {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    private func steamContainsContentWarningInstall(inSteamRoot steamRoot: URL) -> Bool {
        let commonRoot = steamRoot
            .appending(path: "steamapps")
            .appending(path: "common")
        let candidates = [
            commonRoot
                .appending(path: "Content Warning")
                .appending(path: "Content Warning.exe"),
            commonRoot
                .appending(path: "Content Warning")
                .appending(path: "CONTENT WARNING.exe"),
            commonRoot
                .appending(path: "ContentWarning")
                .appending(path: "Content Warning.exe")
        ]

        return candidates.contains {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    private func steamContainsTitanfall2Install(inSteamRoot steamRoot: URL) -> Bool {
        let commonRoot = steamRoot
            .appending(path: "steamapps")
            .appending(path: "common")
        let candidates = [
            commonRoot
                .appending(path: "Titanfall2")
                .appending(path: "Titanfall2.exe"),
            commonRoot
                .appending(path: "Titanfall 2")
                .appending(path: "Titanfall2.exe"),
            commonRoot
                .appending(path: "Titanfall2")
                .appending(path: "bin")
                .appending(path: "x64_retail")
                .appending(path: "Titanfall2.exe")
        ]

        return candidates.contains {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    private func steamContainsSilentHillFInstall(inSteamRoot steamRoot: URL) -> Bool {
        let commonRoot = steamRoot
            .appending(path: "steamapps")
            .appending(path: "common")
        let rootCandidates = [
            "Silent Hill f",
            "SILENT HILL f",
            "SilentHillf",
            "SILENTHILLf"
        ]
        let executableCandidates = rootCandidates.flatMap { rootName in
            [
                commonRoot
                    .appending(path: rootName)
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: "SilentHillf-Win64-Shipping.exe"),
                commonRoot
                    .appending(path: rootName)
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: Self.silentHillFExecutableName),
                commonRoot
                    .appending(path: rootName)
                    .appending(path: "SilentHillf")
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: "SilentHillf-Win64-Shipping.exe"),
                commonRoot
                    .appending(path: rootName)
                    .appending(path: "SilentHillf")
                    .appending(path: "Binaries")
                    .appending(path: "Win64")
                    .appending(path: Self.silentHillFExecutableName)
            ]
        }

        return executableCandidates.contains {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    private func steamContainsForzaHorizon6Install(inSteamRoot steamRoot: URL) -> Bool {
        let commonRoot = steamRoot
            .appending(path: "steamapps")
            .appending(path: "common")
        let rootCandidates = [
            "Forza Horizon 6",
            "ForzaHorizon6"
        ]
        let executableCandidates = rootCandidates.map { rootName in
            commonRoot.appending(path: rootName).appending(path: Self.forzaHorizon6ExecutableName)
        }

        return executableCandidates.contains {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
    }

    private func appendDLLOverride(_ environment: inout [String: String], override: String) {
        let current = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if current.isEmpty {
            environment["WINEDLLOVERRIDES"] = override
            return
        }

        if current.localizedCaseInsensitiveContains(override) {
            return
        }

        environment["WINEDLLOVERRIDES"] = "\(current);\(override)"
    }

    private func applyHighOnLife2DLLOverrides(to environment: inout [String: String]) {
        let current = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitized = stripDLLOverrides(from: current, names: Self.highOnLife2DLLOverridesToStrip)
        if sanitized.isEmpty {
            environment["WINEDLLOVERRIDES"] = Self.highOnLife2BuiltinD3DOverrides
        } else {
            environment["WINEDLLOVERRIDES"] = "\(Self.highOnLife2BuiltinD3DOverrides);\(sanitized)"
        }

        appendDLLOverride(&environment, override: "nvapi,nvapi64=d")
        appendDLLOverride(&environment, override: Self.highOnLife2FSRNativeOverrides)
        appendDLLOverride(&environment, override: Self.highOnLife2NvidiaPluginDisableOverrides)
    }

    private func applyParcelSimulatorDLLOverrides(to environment: inout [String: String]) {
        let current = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitized = stripDLLOverrides(from: current, names: Self.parcelSimulatorDLLOverridesToStrip)
        if sanitized.isEmpty {
            environment["WINEDLLOVERRIDES"] = Self.parcelSimulatorBuiltinD3DOverrides
        } else {
            environment["WINEDLLOVERRIDES"] = "\(Self.parcelSimulatorBuiltinD3DOverrides);\(sanitized)"
        }

        appendDLLOverride(&environment, override: "nvapi,nvapi64=d")
    }

    private func applyMinecraftDungeonsDLLOverrides(to environment: inout [String: String]) {
        let current = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitized = stripDLLOverrides(from: current, names: Self.minecraftDungeonsDLLOverridesToStrip)
        if sanitized.isEmpty {
            environment["WINEDLLOVERRIDES"] = Self.minecraftDungeonsBuiltinD3DOverrides
        } else {
            environment["WINEDLLOVERRIDES"] = "\(Self.minecraftDungeonsBuiltinD3DOverrides);\(sanitized)"
        }

        appendDLLOverride(&environment, override: "nvapi,nvapi64=d")
    }

    private func applyContentWarningDLLOverrides(to environment: inout [String: String]) {
        let current = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitized = stripDLLOverrides(from: current, names: Self.contentWarningDLLOverridesToStrip)
        if sanitized.isEmpty {
            environment["WINEDLLOVERRIDES"] = Self.contentWarningDXVKD3DOverrides
        } else {
            environment["WINEDLLOVERRIDES"] = "\(Self.contentWarningDXVKD3DOverrides);\(sanitized)"
        }

        appendDLLOverride(&environment, override: "nvapi,nvapi64=d")
    }

    private func applyTitanfall2DLLOverrides(to environment: inout [String: String]) {
        let current = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitized = stripDLLOverrides(from: current, names: Self.titanfall2DLLOverridesToStrip)
        if sanitized.isEmpty {
            environment["WINEDLLOVERRIDES"] = Self.titanfall2DXVKD3DOverrides
        } else {
            environment["WINEDLLOVERRIDES"] = "\(Self.titanfall2DXVKD3DOverrides);\(sanitized)"
        }

        appendDLLOverride(&environment, override: "nvapi,nvapi64=d")
    }

    private func applyOriginDLLOverrides(to environment: inout [String: String]) {
        let current = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitized = stripDLLOverrides(from: current, names: Self.originDLLOverridesToStrip)
        if sanitized.isEmpty {
            environment["WINEDLLOVERRIDES"] = Self.originVersionOverride
        } else {
            environment["WINEDLLOVERRIDES"] = "\(Self.originVersionOverride);\(sanitized)"
        }

        appendDLLOverride(&environment, override: "nvapi,nvapi64=d")
    }

    private func stripDLLOverrides(from value: String, names: Set<String>) -> String {
        guard !value.isEmpty else {
            return value
        }

        let entries = value.split(separator: ";", omittingEmptySubsequences: true)
        var rebuilt: [String] = []

        for rawEntry in entries {
            let entry = rawEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !entry.isEmpty else {
                continue
            }

            let parts = entry.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                if names.contains(entry.lowercased()) {
                    continue
                }
                rebuilt.append(entry)
                continue
            }

            let moduleNames = parts[0]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            let filteredModules = moduleNames.filter { module in
                !names.contains(module.lowercased())
            }
            guard !filteredModules.isEmpty else {
                continue
            }

            let overrideValue = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            rebuilt.append("\(filteredModules.joined(separator: ","))=\(overrideValue)")
        }

        return rebuilt.joined(separator: ";")
    }

    private func applyProfileGraphicsBackendOverrides(
        _ profile: BottleGameProfile,
        to environment: inout [String: String]
    ) {
        // Respect explicit bottle backend choices; only apply profile-level backend
        // overrides while the bottle is in automatic backend mode.
        guard bottle.settings.graphicsBackendMode == .auto else {
            return
        }
        guard let backend = profile.graphicsBackendOverride else {
            return
        }

        environment[Self.effectiveBackendEnvironmentKey] = backend.rawValue
        if let fallback = profile.fallbackGraphicsBackend {
            environment[Self.effectiveFallbackBackendEnvironmentKey] = fallback.rawValue
        }

        switch backend {
        case .auto:
            break
        case .dxvk:
            environment.removeValue(forKey: "VECTOR_FORCE_DISABLE_DXVK")
            let existingOverrides = environment["WINEDLLOVERRIDES"]?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if existingOverrides.isEmpty {
                environment["WINEDLLOVERRIDES"] = "dxgi,d3d9,d3d10core,d3d11=n,b"
            }
        case .dxmt:
            environment["VECTOR_FORCE_DISABLE_DXVK"] = "1"
            environment[Self.dxmtNVExtensionsEnvironmentKey] = "1"
            let existingOverrides = environment["WINEDLLOVERRIDES"]?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if existingOverrides.isEmpty {
                environment["WINEDLLOVERRIDES"] = "dxgi,d3d10core,d3d11=b"
            }
        case .wined3d:
            environment["VECTOR_FORCE_DISABLE_DXVK"] = "1"
            environment.removeValue(forKey: Self.dxmtNVExtensionsEnvironmentKey)
            environment["WINEDLLOVERRIDES"] = "dxgi,d3d9,d3d10core,d3d11=b"
        case .d3dMetal:
            environment["VECTOR_FORCE_DISABLE_DXVK"] = "1"
            environment.removeValue(forKey: Self.dxmtNVExtensionsEnvironmentKey)
        }
    }

    func applySmartGraphicsBackendSelection(to environment: inout [String: String]) {
        guard !isSteamProgramPath else {
            return
        }

        let selection = resolveSmartGraphicsBackendSelection(using: environment)
        environment[Self.effectiveBackendEnvironmentKey] = selection.primary.rawValue
        if let fallback = selection.fallback {
            environment[Self.effectiveFallbackBackendEnvironmentKey] = fallback.rawValue
        } else {
            environment.removeValue(forKey: Self.effectiveFallbackBackendEnvironmentKey)
        }

        applyResolvedGraphicsBackendEnvironment(selection.primary, to: &environment)
    }

    private func resolveSmartGraphicsBackendSelection(
        using environment: [String: String]
    ) -> (primary: GraphicsBackendMode, fallback: GraphicsBackendMode?) {
        if let explicitBackend = backendMode(from: environment[Self.effectiveBackendEnvironmentKey]),
           explicitBackend != .auto {
            let fallback = backendMode(from: environment[Self.effectiveFallbackBackendEnvironmentKey])
            return (explicitBackend, fallback)
        }

        let configuredMode = bottle.settings.graphicsBackendMode
        if configuredMode != .auto {
            return (configuredMode, nil)
        }

        if let profile = resolvedGameProfile(),
           let backend = profile.graphicsBackendOverride,
           backend != .auto {
            return (backend, profile.fallbackGraphicsBackend)
        }

        if let inferredMode = bottle.settings.inferredGraphicsBackendMode,
           inferredMode != .auto {
            return (inferredMode, bottle.settings.inferredFallbackGraphicsBackendMode)
        }

        if bottle.settings.dlssRuntimeTranslationEnabled
            || isTruthyEnvironmentValue(environment[Self.dlssTranslationMarkerEnvironmentKey]) {
            return (.dxmt, .dxvk)
        }

        if shouldApplyInstallerCompatibilityMode || shouldApplyElectronWindowCompatibility {
            return (.wined3d, .dxvk)
        }

        let activeSteamAppID = bottle.settings.activeSteamAppID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if shouldApplyForzaHorizon6Compatibility(activeSteamAppID: activeSteamAppID) {
            return (.d3dMetal, .dxvk)
        }

        let knownD3D11Target = shouldApplyHighOnLife2Compatibility(activeSteamAppID: activeSteamAppID)
            || shouldApplyParcelSimulatorCompatibility(activeSteamAppID: activeSteamAppID)
            || shouldApplyMinecraftDungeonsCompatibility(activeSteamAppID: activeSteamAppID)
            || shouldApplyContentWarningCompatibility(activeSteamAppID: activeSteamAppID)
            || shouldApplyTitanfall2Compatibility(activeSteamAppID: activeSteamAppID)
            || shouldApplySilentHillFCompatibility(activeSteamAppID: activeSteamAppID)
            || shouldApplyOriginCompatibility
        if knownD3D11Target || bottle.settings.forceD3D11Compatibility {
            return (.dxvk, .wined3d)
        }

        if let inferred = inferBackendFromDLLOverrides(environment["WINEDLLOVERRIDES"]) {
            return inferred
        }

        return (.dxvk, .wined3d)
    }

    private func applyResolvedGraphicsBackendEnvironment(
        _ backend: GraphicsBackendMode,
        to environment: inout [String: String]
    ) {
        let canMutateDLLOverrides = bottle.settings.dllOverridesPolicy != .custom
            || bottle.settings.customDLLOverrides.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        switch backend {
        case .auto:
            break
        case .dxvk:
            environment.removeValue(forKey: "VECTOR_FORCE_DISABLE_DXVK")
            environment.removeValue(forKey: Self.dxmtNVExtensionsEnvironmentKey)
            if canMutateDLLOverrides {
                applyGraphicsBackendDLLOverrides(
                    "dxgi,d3d9,d3d10core,d3d11=n,b",
                    to: &environment
                )
            }
        case .dxmt:
            environment["VECTOR_FORCE_DISABLE_DXVK"] = "1"
            environment[Self.dxmtNVExtensionsEnvironmentKey] = "1"
            if canMutateDLLOverrides {
                applyGraphicsBackendDLLOverrides(
                    "dxgi,d3d10core,d3d11=b",
                    to: &environment
                )
            }
        case .wined3d:
            environment["VECTOR_FORCE_DISABLE_DXVK"] = "1"
            environment.removeValue(forKey: Self.dxmtNVExtensionsEnvironmentKey)
            if canMutateDLLOverrides {
                applyGraphicsBackendDLLOverrides(
                    "dxgi,d3d9,d3d10core,d3d11=b",
                    to: &environment
                )
            }
        case .d3dMetal:
            environment["VECTOR_FORCE_DISABLE_DXVK"] = "1"
            environment.removeValue(forKey: Self.dxmtNVExtensionsEnvironmentKey)
        }
    }

    private func applyGraphicsBackendDLLOverrides(_ overridePrefix: String, to environment: inout [String: String]) {
        let existingOverrides = environment["WINEDLLOVERRIDES"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitizedOverrides = stripDLLOverrides(
            from: existingOverrides,
            names: Self.graphicsBackendDLLOverrideModules
        )
        if sanitizedOverrides.isEmpty {
            environment["WINEDLLOVERRIDES"] = overridePrefix
        } else {
            environment["WINEDLLOVERRIDES"] = "\(overridePrefix);\(sanitizedOverrides)"
        }
    }

    private func inferBackendFromDLLOverrides(
        _ overridesRawValue: String?
    ) -> (primary: GraphicsBackendMode, fallback: GraphicsBackendMode?)? {
        guard let overridesRawValue,
              !overridesRawValue.isEmpty else {
            return nil
        }

        let normalized = overridesRawValue.lowercased()
        if normalized.contains("dxgi,d3d10core,d3d11=b")
            || (normalized.contains("dxgi")
                && normalized.contains("d3d10core")
                && normalized.contains("d3d11")
                && normalized.contains("=b")) {
            return (.dxmt, .dxvk)
        }

        if normalized.contains("dxgi,d3d9,d3d10core,d3d11=b")
            || normalized.contains("d3d11=b;")
            || normalized.hasSuffix("d3d11=b") {
            return (.wined3d, .dxvk)
        }

        if normalized.contains("d3d11=n,b")
            || normalized.contains("d3d10core=n,b")
            || normalized.contains("d3d9=n,b")
            || normalized.contains("dxgi=n,b") {
            return (.dxvk, .wined3d)
        }

        return nil
    }

    private func backendMode(from rawValue: String?) -> GraphicsBackendMode? {
        guard let rawValue else {
            return nil
        }
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else {
            return nil
        }
        return GraphicsBackendMode(rawValue: normalized)
    }

    private func isTruthyEnvironmentValue(_ value: String?) -> Bool {
        guard let value else {
            return false
        }
        return ["1", "true", "yes", "on"].contains(
            value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }

    private func profileRequestsDX12(_ profile: BottleGameProfile) -> Bool {
        let arguments = profile.arguments.lowercased()
        return arguments.contains("-dx12")
            || arguments.contains("-d3d12")
            || arguments.contains("-force-d3d12")
    }
    private func prepareSteamInstalledGameShims() {
        let steamRoot = url.deletingLastPathComponent()
        let commonRoot = steamRoot
            .appending(path: "steamapps")
            .appending(path: "common")
        let rootExecutable = commonRoot
            .appending(path: "HighOnLife2")
            .appending(path: "HighOnLife2.exe")

        if FileManager.default.fileExists(atPath: rootExecutable.path(percentEncoded: false)) {
            ensureHighOnLife2NGXShimIfNeeded(for: rootExecutable)
            ensureHighOnLife2FSRShimsIfNeeded(for: rootExecutable)
        }

        let candidates = [
            commonRoot
                .appending(path: "HighOnLife2")
                .appending(path: "HighOnLife2")
                .appending(path: "Binaries")
                .appending(path: "Win64")
                .appending(path: "HighOnLife2-Win64-Shipping.exe"),
            commonRoot
                .appending(path: "HighOnLife2")
                .appending(path: "Binaries")
                .appending(path: "Win64")
                .appending(path: "HighOnLife2-Win64-Shipping.exe")
        ]

        for executableURL in candidates {
            let executablePath = executableURL.path(percentEncoded: false)
            guard FileManager.default.fileExists(atPath: executablePath) else { continue }
            ensureHighOnLife2NGXShimIfNeeded(for: executableURL)
            ensureHighOnLife2FSRShimsIfNeeded(for: executableURL)
            ensureHighOnLife2EngineIniOverrides()
            ensureSteamLaunchOptions(
                inSteamRoot: steamRoot,
                appID: Self.highOnLife2SteamAppID,
                launchOptions: Self.highOnLife2SteamLaunchOptions
            )
            break
        }

        let parcelCandidates = [
            commonRoot
                .appending(path: "Parcel Simulator")
                .appending(path: "parcel")
                .appending(path: "Binaries")
                .appending(path: "Win64")
                .appending(path: "parcel-Win64-Shipping.exe"),
            commonRoot
                .appending(path: "Parcel Simulator")
                .appending(path: "Binaries")
                .appending(path: "Win64")
                .appending(path: "parcel-Win64-Shipping.exe")
        ]

        if parcelCandidates.contains(where: {
            FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }) {
            ensureSteamLaunchOptions(
                inSteamRoot: steamRoot,
                appID: Self.parcelSimulatorSteamAppID,
                launchOptions: Self.parcelSimulatorSteamLaunchOptions
            )
        }

        if !Self.minecraftDungeonsSteamLaunchOptions.isEmpty,
           steamContainsMinecraftDungeonsInstall(inSteamRoot: steamRoot) {
            ensureMinecraftDungeonsEngineIniOverrides()
            ensureSteamLaunchOptions(
                inSteamRoot: steamRoot,
                appID: Self.minecraftDungeonsSteamAppID,
                launchOptions: Self.minecraftDungeonsSteamLaunchOptions
            )
        }

        if !Self.contentWarningSteamLaunchOptions.isEmpty,
           steamContainsContentWarningInstall(inSteamRoot: steamRoot) {
            ensureSteamLaunchOptions(
                inSteamRoot: steamRoot,
                appID: Self.contentWarningSteamAppID,
                launchOptions: Self.contentWarningSteamLaunchOptions
            )
        }

        if steamContainsTitanfall2Install(inSteamRoot: steamRoot) {
            ensureOriginCompatibilityConfig()
        }

        if !Self.silentHillFSteamLaunchOptions.isEmpty,
           steamContainsSilentHillFInstall(inSteamRoot: steamRoot) {
            ensureSteamLaunchOptions(
                inSteamRoot: steamRoot,
                appID: Self.silentHillFSteamAppID,
                launchOptions: Self.silentHillFSteamLaunchOptions
            )
        }
    }

    private func ensureHighOnLife2EngineIniOverrides() {
        let usersRoot = bottle.url
            .appending(path: "drive_c")
            .appending(path: "users")
        guard let userDirectories = try? FileManager.default.contentsOfDirectory(
            at: usersRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for userDirectory in userDirectories {
            let windowsConfigDirectory = userDirectory
                .appending(path: "AppData")
                .appending(path: "Local")
                .appending(path: "HighOnLife2")
                .appending(path: "Saved")
                .appending(path: "Config")
                .appending(path: "Windows")
            let engineINIURL = windowsConfigDirectory.appending(path: "Engine.ini")
            let engineINIPath = engineINIURL.path(percentEncoded: false)

            do {
                try FileManager.default.createDirectory(
                    at: windowsConfigDirectory,
                    withIntermediateDirectories: true
                )

                var contents = (try? String(contentsOf: engineINIURL, encoding: .utf8)) ?? ""
                guard !contents.contains(Self.highOnLife2EngineIniMarker) else {
                    continue
                }

                if !contents.isEmpty, !contents.hasSuffix("\n") {
                    contents += "\n"
                }
                contents += "\n"
                contents += Self.highOnLife2EngineIniBlock
                contents += "\n"

                try contents.write(to: engineINIURL, atomically: true, encoding: .utf8)
                Logger.wineKit.info("Applied High On Life 2 Engine.ini overrides at \(engineINIPath, privacy: .public)")
            } catch {
                Logger.wineKit.warning("Failed to apply High On Life 2 Engine.ini overrides at \(engineINIPath, privacy: .public)")
                Logger.wineKit.warning(
                    "High On Life 2 Engine.ini override error: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func ensureMinecraftDungeonsEngineIniOverrides() {
        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplyMinecraftDungeonsCompatibility(activeSteamAppID: activeSteamAppID)
                || steamSettingsLaunchesApp()
                || isMinecraftDungeonsExecutable(
                    path: url.path(percentEncoded: false).lowercased(),
                    activeSteamAppID: activeSteamAppID
                ) else {
            return
        }

        let usersRoot = bottle.url
            .appending(path: "drive_c")
            .appending(path: "users")
        guard let userDirectories = try? FileManager.default.contentsOfDirectory(
            at: usersRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for userDirectory in userDirectories {
            let windowsConfigDirectory = userDirectory
                .appending(path: "AppData")
                .appending(path: "Local")
                .appending(path: "Dungeons")
                .appending(path: "Saved")
                .appending(path: "Config")
                .appending(path: "WindowsNoEditor")
            let engineINIURL = windowsConfigDirectory.appending(path: "Engine.ini")
            let engineINIPath = engineINIURL.path(percentEncoded: false)

            do {
                try FileManager.default.createDirectory(
                    at: windowsConfigDirectory,
                    withIntermediateDirectories: true
                )

                var contents = (try? String(contentsOf: engineINIURL, encoding: .utf8)) ?? ""
                guard !contents.contains(Self.minecraftDungeonsEngineIniMarker) else {
                    continue
                }

                if !contents.isEmpty, !contents.hasSuffix("\n") {
                    contents += "\n"
                }
                contents += "\n"
                contents += Self.minecraftDungeonsEngineIniBlock
                contents += "\n"

                try contents.write(to: engineINIURL, atomically: true, encoding: .utf8)
                Logger.wineKit.info(
                    "Applied Minecraft Dungeons Engine.ini overrides at \(engineINIPath, privacy: .public)"
                )
            } catch {
                Logger.wineKit.warning(
                    "Failed to apply Minecraft Dungeons Engine.ini overrides at \(engineINIPath, privacy: .public)"
                )
                Logger.wineKit.warning(
                    "Minecraft Dungeons Engine.ini override error: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func ensureOriginCompatibilityConfig() {
        let fileManager = FileManager.default
        let contents = """
[Bootstrap]
EnableUpdating=false
"""

        let configDirectories: [URL] = [
            bottle.url
                .appending(path: "drive_c")
                .appending(path: "ProgramData")
                .appending(path: "Origin")
        ]

        for directoryURL in configDirectories {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let configURL = directoryURL.appending(path: "EACore.ini")
            let current = try? String(contentsOf: configURL, encoding: .utf8)
            guard current != contents else {
                continue
            }
            try? contents.write(to: configURL, atomically: true, encoding: .utf8)
        }

        let usersRoot = bottle.url
            .appending(path: "drive_c")
            .appending(path: "users")
        guard let userDirectories = try? fileManager.contentsOfDirectory(
            at: usersRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for userDirectory in userDirectories {
            let candidateDirectories = [
                userDirectory
                    .appending(path: "AppData")
                    .appending(path: "Roaming")
                    .appending(path: "Origin"),
                userDirectory
                    .appending(path: "AppData")
                    .appending(path: "Local")
                    .appending(path: "Origin")
            ]

            for directoryURL in candidateDirectories {
                try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                let configURL = directoryURL.appending(path: "EACore.ini")
                let current = try? String(contentsOf: configURL, encoding: .utf8)
                guard current != contents else {
                    continue
                }
                try? contents.write(to: configURL, atomically: true, encoding: .utf8)
            }
        }
    }

    private func ensureSteamLaunchOptions(
        inSteamRoot steamRoot: URL,
        appID: String,
        launchOptions: String
    ) {
        let usersRoot = steamRoot.appending(path: Self.steamUsersDirectoryName)
        guard let userDirectories = try? FileManager.default.contentsOfDirectory(
            at: usersRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for userDirectory in userDirectories {
            let configURL = userDirectory.appending(path: Self.steamUserLocalConfigSuffix)
            let configPath = configURL.path(percentEncoded: false)
            guard FileManager.default.fileExists(atPath: configPath) else { continue }
            guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else { continue }
            guard let updated = upsertSteamLaunchOptions(
                in: contents,
                appID: appID,
                launchOptions: launchOptions
            ) else {
                continue
            }

            if updated != contents {
                do {
                    try updated.write(to: configURL, atomically: true, encoding: .utf8)
                    Logger.wineKit.info(
                        "Updated Steam launch options for app \(appID, privacy: .public) at \(configPath, privacy: .public)"
                    )
                } catch {
                    Logger.wineKit.warning(
                        "Failed to update Steam launch options at \(configPath, privacy: .public)"
                    )
                    Logger.wineKit.warning(
                        "Steam launch options patch error: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }

    private func upsertSteamLaunchOptions(
        in text: String,
        appID: String,
        launchOptions: String
    ) -> String? {
        guard let appBlockRange = rangeOfSteamAppBlock(in: text, appID: appID) else {
            return nil
        }

        let block = String(text[appBlockRange])
        let launchLinePattern = #"(?m)^([ \t]*)"LaunchOptions"[ \t]*"[^"]*"[ \t]*$"#
        guard let launchLineRegex = try? NSRegularExpression(pattern: launchLinePattern) else {
            return nil
        }

        if let launchLineMatch = launchLineRegex.firstMatch(
            in: block,
            range: NSRange(block.startIndex..<block.endIndex, in: block)
        ), let launchLineRange = Range(launchLineMatch.range, in: block),
           let indentRange = Range(launchLineMatch.range(at: 1), in: block) {
            let indent = String(block[indentRange])
            let replacementLine = "\(indent)\"LaunchOptions\"\t\t\"\(launchOptions)\""
            var updatedText = text
            updatedText.replaceSubrange(appBlockRange, with: block.replacingCharacters(in: launchLineRange, with: replacementLine))
            return updatedText
        }

        guard let closingBrace = block.lastIndex(of: "}") else {
            return nil
        }

        let appIndent = appBlockIndent(for: block)
        let launchIndent = appIndent + "\t\t"
        let launchLine = "\(launchIndent)\"LaunchOptions\"\t\t\"\(launchOptions)\"\n"
        let insertionIndex = block.index(before: closingBrace)
        var newBlock = block
        newBlock.insert(contentsOf: launchLine, at: insertionIndex)

        var updatedText = text
        updatedText.replaceSubrange(appBlockRange, with: newBlock)
        return updatedText
    }

    private func rangeOfSteamAppBlock(in text: String, appID: String) -> Range<String.Index>? {
        let pattern = #"(?m)^([ \t]*)"\#(appID)"[ \t]*\r?\n\1\{"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..<text.endIndex, in: text)
              ),
              let matchRange = Range(match.range, in: text) else {
            return nil
        }

        guard let openBraceIndex = text[matchRange].lastIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var cursor = openBraceIndex
        var closingBraceIndex: String.Index?
        while cursor < text.endIndex {
            let character = text[cursor]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    closingBraceIndex = cursor
                    break
                }
            }
            cursor = text.index(after: cursor)
        }

        guard let closingBraceIndex else {
            return nil
        }

        let start = matchRange.lowerBound
        let end = text.index(after: closingBraceIndex)
        return start..<end
    }

    private func appBlockIndent(for block: String) -> String {
        guard let firstLine = block.split(separator: "\n", maxSplits: 1).first else {
            return ""
        }

        let line = String(firstLine)
        let whitespacePrefix = line.prefix { $0 == " " || $0 == "\t" }
        return String(whitespacePrefix)
    }

    private func ensureHighOnLife2NGXShimIfNeeded(for executableURL: URL) {
        let lowercasedPath = executableURL.path(percentEncoded: false).lowercased()
        guard lowercasedPath.contains(Self.highOnLife2ExecutableName)
            || lowercasedPath.contains("/highonlife2/") else {
            return
        }

        guard let sourceDLL = locateHighOnLife2NGXSourceDLL(for: executableURL) else {
            Logger.wineKit.warning("High On Life 2 NGX shim source could not be found.")
            return
        }

        let executableDirectory = executableURL.deletingLastPathComponent()
        let fileManager = FileManager.default
        for targetName in ["nvngx.dll", "_nvngx.dll"] {
            let targetURL = executableDirectory.appending(path: targetName)
            let targetPath = targetURL.path(percentEncoded: false)
            if fileManager.fileExists(atPath: targetPath) {
                continue
            }

            do {
                try fileManager.copyItem(at: sourceDLL, to: targetURL)
                Logger.wineKit.info("Installed NGX shim at \(targetPath, privacy: .public)")
            } catch {
                Logger.wineKit.warning("Failed to install NGX shim at \(targetPath, privacy: .public)")
                Logger.wineKit.warning("NGX shim install error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func ensureHighOnLife2FSRShimsIfNeeded(for executableURL: URL) {
        let lowercasedPath = executableURL.path(percentEncoded: false).lowercased()
        guard lowercasedPath.contains(Self.highOnLife2ExecutableName)
            || lowercasedPath.contains("/highonlife2/") else {
            return
        }

        let executableDirectory = executableURL.deletingLastPathComponent()
        let fileManager = FileManager.default

        for dllName in Self.highOnLife2FSRDLLNames {
            let targetURL = executableDirectory.appending(path: dllName)
            let targetPath = targetURL.path(percentEncoded: false)
            if fileManager.fileExists(atPath: targetPath) {
                continue
            }

            guard let sourceDLL = locateHighOnLife2FSRSourceDLL(named: dllName, for: executableURL) else {
                Logger.wineKit.warning("High On Life 2 FSR source \(dllName, privacy: .public) could not be found.")
                continue
            }

            do {
                try fileManager.copyItem(at: sourceDLL, to: targetURL)
                Logger.wineKit.info("Installed FSR shim at \(targetPath, privacy: .public)")
            } catch {
                Logger.wineKit.warning("Failed to install FSR shim at \(targetPath, privacy: .public)")
                Logger.wineKit.warning("FSR shim install error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func locateHighOnLife2NGXSourceDLL(for executableURL: URL) -> URL? {
        var searchRoot = executableURL.deletingLastPathComponent()
        let fileManager = FileManager.default

        for _ in 0..<6 {
            let candidate = searchRoot
                .appending(path: "Engine")
                .appending(path: "Plugins")
                .appending(path: "Runtime")
                .appending(path: "Nvidia")
                .appending(path: "DLSS")
                .appending(path: "Binaries")
                .appending(path: "ThirdParty")
                .appending(path: "Win64")
                .appending(path: "nvngx_dlss.dll")
            let candidatePath = candidate.path(percentEncoded: false)
            if fileManager.fileExists(atPath: candidatePath) {
                return candidate
            }
            searchRoot.deleteLastPathComponent()
        }
        return nil
    }

    private func locateHighOnLife2FSRSourceDLL(named dllName: String, for executableURL: URL) -> URL? {
        var searchRoot = executableURL.deletingLastPathComponent()
        let fileManager = FileManager.default

        for _ in 0..<6 {
            let amdPluginRoot = searchRoot
                .appending(path: "Engine")
                .appending(path: "Plugins")
                .appending(path: "Runtime")
                .appending(path: "AMD")
            let amdPluginRootPath = amdPluginRoot.path(percentEncoded: false)
            if fileManager.fileExists(atPath: amdPluginRootPath),
               let enumerator = fileManager.enumerator(
                   at: amdPluginRoot,
                   includingPropertiesForKeys: [.isRegularFileKey],
                   options: [.skipsHiddenFiles]
               ) {
                for case let candidate as URL in enumerator {
                    if candidate.lastPathComponent.caseInsensitiveCompare(dllName) == .orderedSame {
                        return candidate
                    }
                }
            }

            searchRoot.deleteLastPathComponent()
        }

        return nil
    }

    private func detectedAntiCheatArtifacts(maxCount: Int) -> [String] {
        let markers = [
            "easyanticheat",
            "eos_anticheat",
            "start_protected_game",
            "embarkgameboot",
            "arcraiders",
            "arc raiders",
            "battleye",
            "beservice",
            "beclient",
            "vgk",
            "vgc",
            "xenuine",
            "equ8"
        ]

        var roots: [URL] = [url.deletingLastPathComponent()]
        roots.append(url.deletingLastPathComponent().appending(path: "EasyAntiCheat"))
        roots.append(url.deletingLastPathComponent().appending(path: "BattlEye"))

        var found: [String] = []
        var seen = Set<String>()

        for root in roots {
            let rootPath = root.path(percentEncoded: false)
            guard FileManager.default.fileExists(atPath: rootPath) else {
                continue
            }

            var scannedEntries = 0
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            while let entry = enumerator?.nextObject() as? URL {
                scannedEntries += 1
                if scannedEntries > 2_500 { break }

                let lowercasedPath = entry.path(percentEncoded: false).lowercased()
                guard markers.contains(where: { lowercasedPath.contains($0) }) else {
                    continue
                }

                let candidate = entry.lastPathComponent
                guard seen.insert(candidate.lowercased()).inserted else {
                    continue
                }

                found.append(candidate)
                if found.count >= maxCount {
                    return found
                }
            }
        }

        return found
    }
}
