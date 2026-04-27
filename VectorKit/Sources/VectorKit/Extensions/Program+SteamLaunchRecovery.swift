//
//  Program+SteamLaunchRecovery.swift
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

// swiftlint:disable file_length
extension Program {
    private static let steamDisabledNativeDLLOverrides = "nvapi,nvapi64=d"
    private static let steamDXVKDLLNames: Set<String> = ["dxgi", "d3d9", "d3d10core", "d3d11"]
    private static let globalMediaDLLOverridesKey = #"HKCU\Software\Wine\DllOverrides"#
    private static let globalMediaPlaybackDLLs = [
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
    private static let globalMediaPlaybackOverrideValue = "native,builtin"
    private static let globalMediaPlaybackMarkerFilename = ".vector-global-media-playback-v1"
    private static let steamWebHelperDLLOverridesRegistryKey =
        #"HKCU\Software\Wine\AppDefaults\steamwebhelper.exe\DllOverrides"#
    private static let steamWebHelperBuiltinDLLs = [
        "dxgi", "d3d11", "d3d10core", "d3d9", "vulkan-1", "libegl", "libglesv2"
    ]
    private static let steamWebHelperBuiltinsMarkerFilename = ".vector-steamwebhelper-builtins-v1"
    private static let steamWebHelperCleanupMarkerFilename = ".vector-steamwebhelper-builtins-cleared-v1"
    private static let highOnLife2ExecutableNames = [
        "HighOnLife2-Win64-Shipping.exe",
        "HighOnLife2.exe"
    ]
    private static let highOnLife2DXVKDLLs = ["dxgi", "d3d11", "d3d10core", "d3d9", "d3d12", "d3d12core"]
    private static let highOnLife2DXVKOverrideValue = "builtin"
    private static let highOnLife2DisabledDLLs = ["nvapi", "nvapi64"]
    private static let highOnLife2DisabledOverrideValue = "disabled"
    private static let highOnLife2NvidiaPluginDLLs = [
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
    private static let highOnLife2NativeAMDModules = [
        "amd_fidelityfx_upscaler_dx12",
        "amd_fidelityfx_framegeneration_dx12"
    ]
    private static let highOnLife2NativeAMDOverrideValue = "native,builtin"
    private static let highOnLife2GlobalDLLOverridesRegistryKey = #"HKCU\Software\Wine\DllOverrides"#
    private static let highOnLife2ConflictingGlobalDLLs = [
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
    private static let highOnLife2Direct3DSettingsToClear = ["VideoPciVendorID", "VideoPciDeviceID"]
    private static let highOnLife2Direct3DRendererSetting = "renderer"
    private static let highOnLife2Direct3DRendererValue = "vulkan"
    private static let highOnLife2AppDefaultsMarkerFilename = ".vector-hol2-appdefaults-v2"
    private static let parcelSimulatorExecutableNames = [
        "parcel-Win64-Shipping.exe",
        "parcel.exe"
    ]
    private static let parcelSimulatorDXVKDLLs = ["dxgi", "d3d11", "d3d10core", "d3d9"]
    private static let parcelSimulatorDXVKOverrideValue = "builtin"
    private static let parcelSimulatorDisabledDLLs = ["nvapi", "nvapi64"]
    private static let parcelSimulatorDisabledOverrideValue = "disabled"
    private static let parcelSimulatorGlobalDLLOverridesKey = #"HKCU\Software\Wine\DllOverrides"#
    private static let parcelSimulatorConflictingGlobalDLLs = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9",
        "nvapi",
        "nvapi64"
    ]
    private static let parcelSimulatorDirect3DSettingsToClear = ["VideoPciVendorID", "VideoPciDeviceID"]
    private static let parcelSimulatorDirect3DRendererSetting = "renderer"
    private static let parcelSimulatorDirect3DRendererValue = "vulkan"
    private static let parcelSimulatorAppDefaultsMarkerFilename = ".vector-parcel-appdefaults-v1"
    private static let minecraftDungeonsExecutableNames = [
        "Dungeons-Win64-Shipping.exe",
        "MinecraftDungeons.exe",
        "Dungeons.exe",
        "dungeons-win64-shipping.exe",
        "minecraftdungeons.exe",
        "dungeons.exe"
    ]
    private static let minecraftDungeonsCEFExecutableNames = [
        "UnrealCEFSubProcess.exe"
    ]
    private static let minecraftDungeonsBuiltinD3D11DLLs = ["dxgi", "d3d11", "d3d10core", "d3d9"]
    private static let minecraftDungeonsBuiltinOverrideValue = "native,builtin"
    private static let minecraftDungeonsLegacyDisabledD3D12DLLs = ["d3d12", "d3d12core"]
    private static let minecraftDungeonsDisabledDLLs = ["nvapi", "nvapi64"]
    private static let minecraftDungeonsDisabledOverrideValue = "disabled"
    private static let minecraftDungeonsCEFBuiltinDLLs = ["dxgi", "d3d11", "d3d10core", "d3d9"]
    private static let minecraftDungeonsCEFBuiltinValue = "builtin"
    private static let minecraftDungeonsCEFDisabledDLLs = ["nvapi", "nvapi64"]
    private static let minecraftDungeonsCEFDisabledValue = "disabled"
    private static let minecraftDungeonsMediaBuiltinDLLs = globalMediaPlaybackDLLs
    private static let minecraftDungeonsMediaBuiltinValue = "builtin"
    private static let minecraftDungeonsGlobalDLLOverridesKey = #"HKCU\Software\Wine\DllOverrides"#
    private static let minecraftDungeonsConflictingGlobalDLLs = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9",
        "d3d12",
        "d3d12core",
        "nvapi",
        "nvapi64"
    ]
    private static let minecraftDungeonsDirect3DSettingsToClear = ["VideoPciVendorID", "VideoPciDeviceID"]
    private static let minecraftDungeonsDirect3DRendererSetting = "renderer"
    private static let minecraftDungeonsDirect3DRendererValue = "vulkan"
    private static let minecraftDungeonsCEFRendererKey = "renderer"
    private static let minecraftDungeonsCEFRendererValue = "gl"
    private static let minecraftDungeonsAppDefaultsMarkerFile = ".vector-minecraftdungeons-appdefaults-v9"
    private static let minecraftDungeonsAuthMarkerFile = ".vector-minecraftdungeons-auth-protocols-v6"
    private static let minecraftDungeonsSteamProtocolSchemes = [
        "xbox",
        "xal",
        "xbl",
        "msxbl",
        "ms-xal",
        "ms-xbl",
        "ms-appx",
        "ms-appx-web",
        "ms-xbl-multiplayer",
        "ms-xbl-3d8b930f",
        "ms-xal-3d8b930f"
    ]
    private static let minecraftDungeonsEdgeProtocolSchemes = [
        "microsoft-edge",
        "microsoft-edge-userdata"
    ]
    private static let contentWarningExecutableNames = [
        "Content Warning.exe",
        "CONTENT WARNING.exe",
        "content warning.exe"
    ]
    private static let contentWarningDXVKDLLs = ["dxgi", "d3d11", "d3d10core", "d3d9"]
    private static let contentWarningDXVKOverrideValue = "native,builtin"
    private static let contentWarningDisabledDLLs = ["nvapi", "nvapi64"]
    private static let contentWarningDisabledOverrideValue = "disabled"
    private static let contentWarningGlobalDLLOverridesKey = #"HKCU\Software\Wine\DllOverrides"#
    private static let contentWarningConflictingGlobalDLLs = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9",
        "nvapi",
        "nvapi64"
    ]
    private static let contentWarningDirect3DSettingsToClear = ["VideoPciVendorID", "VideoPciDeviceID"]
    private static let contentWarningDirect3DRendererSetting = "renderer"
    private static let contentWarningDirect3DRendererValue = "gl"
    private static let contentWarningAppDefaultsMarkerFilename = ".vector-contentwarning-appdefaults-v3"
    private static let originExecutableNames = [
        "Origin.exe",
        "origin.exe",
        "EADesktop.exe",
        "eadesktop.exe",
        "EAappInstaller.exe",
        "eaappinstaller.exe",
        "EADesktopInstaller.exe",
        "eadesktopinstaller.exe",
        "EALauncher.exe",
        "ealauncher.exe"
    ]
    private static let originNativeDLLs = ["version"]
    private static let originNativeOverrideValue = "native,builtin"
    private static let originWindowsVersionValue = "win10"
    private static let originGlobalDLLOverridesKey = #"HKCU\Software\Wine\DllOverrides"#
    private static let originConflictingGlobalDLLs = ["version"]
    private static let originAppDefaultsMarkerFilename = ".vector-origin-appdefaults-v2"
    private static let titanfall2ExecutableNames = [
        "Titanfall2.exe",
        "titanfall2.exe"
    ]
    private static let titanfall2DXVKDLLs = ["dxgi", "d3d11", "d3d10core", "d3d9"]
    private static let titanfall2DXVKOverrideValue = "native,builtin"
    private static let titanfall2DisabledDLLs = ["nvapi", "nvapi64"]
    private static let titanfall2DisabledOverrideValue = "disabled"
    private static let titanfall2GlobalDLLOverridesKey = #"HKCU\Software\Wine\DllOverrides"#
    private static let titanfall2ConflictingGlobalDLLs = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9",
        "nvapi",
        "nvapi64"
    ]
    private static let titanfall2Direct3DSettingsToClear = ["VideoPciVendorID", "VideoPciDeviceID"]
    private static let titanfall2Direct3DRendererSetting = "renderer"
    private static let titanfall2Direct3DRendererValue = "vulkan"
    private static let titanfall2AppDefaultsMarkerFilename = ".vector-titanfall2-appdefaults-v2"
    private static let silentHillFExecutableNames = [
        "SilentHillf-Win64-Shipping.exe",
        "Silent Hill f-Win64-Shipping.exe",
        "SilentHillf.exe",
        "Silent Hill f.exe",
        "silenthillf-win64-shipping.exe",
        "silenthillf.exe",
        "silent hill f-win64-shipping.exe",
        "silent hill f.exe"
    ]
    private static let silentHillFDXVKDLLs = ["dxgi", "d3d11", "d3d10core", "d3d9"]
    private static let silentHillFDXVKOverrideValue = "native,builtin"
    private static let silentHillFDisabledDLLs = ["nvapi", "nvapi64"]
    private static let silentHillFDisabledOverrideValue = "disabled"
    private static let silentHillFGlobalDLLOverridesKey = #"HKCU\Software\Wine\DllOverrides"#
    private static let silentHillFConflictingGlobalDLLs = [
        "dxgi",
        "d3d11",
        "d3d10core",
        "d3d9",
        "nvapi",
        "nvapi64"
    ]
    private static let silentHillFDirect3DSettingsToClear = ["VideoPciVendorID", "VideoPciDeviceID"]
    private static let silentHillFDirect3DRendererSetting = "renderer"
    private static let silentHillFDirect3DRendererValue = "vulkan"
    private static let silentHillFAppDefaultsMarkerFilename = ".vector-silenthillf-appdefaults-v2"

    func steamRecoveryArguments(from arguments: [String]) -> [String] {
        var recoveredArguments: [String] = []
        var skipNext = false

        for argument in arguments {
            if skipNext {
                skipNext = false
                continue
            }

            if argument.caseInsensitiveCompare("-overridepackageurl") == .orderedSame {
                skipNext = true
                continue
            }

            if argument.caseInsensitiveCompare("-noverifyfiles") == .orderedSame
                || argument.caseInsensitiveCompare("-nobootstrapupdate") == .orderedSame
                || argument.caseInsensitiveCompare("-skipinitialbootstrap") == .orderedSame
                || argument.caseInsensitiveCompare("-norepairfiles") == .orderedSame
                || argument.caseInsensitiveCompare("-no-cef-sandbox") == .orderedSame
                || argument.caseInsensitiveCompare("-forcesteamupdate") == .orderedSame
                || argument.caseInsensitiveCompare("-forcepackagedownload") == .orderedSame
                || argument.caseInsensitiveCompare("-exitsteam") == .orderedSame
                || argument.caseInsensitiveCompare("-cef-disable-gpu-compositing") == .orderedSame
                || argument.caseInsensitiveCompare("-cef-disable-d3d11") == .orderedSame
                || argument.caseInsensitiveCompare("-ngxdisable") == .orderedSame
                || argument.caseInsensitiveCompare("-cef-disable-breakpad") == .orderedSame
                || argument.caseInsensitiveCompare("-cef-force-32bit") == .orderedSame
                || argument.caseInsensitiveCompare("-nocrashmonitor") == .orderedSame
                || argument.caseInsensitiveCompare("-noshaders") == .orderedSame
                || argument.caseInsensitiveCompare("-no-browser") == .orderedSame {
                continue
            }

            recoveredArguments.append(argument)
        }

        return recoveredArguments
    }

    func isSameArguments(lhs: [String], rhs: [String]) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }

        for (left, right) in zip(lhs, rhs)
        where left.caseInsensitiveCompare(right) != .orderedSame {
            return false
        }

        return true
    }

    func resetSteamWineserver(environment: [String: String]) async throws {
        // Always terminate the default wineserver for this prefix first to avoid
        // cross-version server reuse when switching runtimes.
        for await _ in try Wine.runWineserverProcess(
            name: "steam-prelaunch-wineserver-kill-default",
            args: ["-k"],
            bottle: bottle
        ) { }

        guard let compatibilityWineserver = VectorWineInstaller.steamCompatibilityWineserverBinary() else { return }

        // Then terminate the compatibility runtime wineserver if present.
        var compatibilityEnvironment = environment
        compatibilityEnvironment["VECTOR_WINESERVER_BIN_OVERRIDE"] =
            compatibilityWineserver.path(percentEncoded: false)
        for await _ in try Wine.runWineserverProcess(
            name: "steam-prelaunch-wineserver-kill-compat",
            args: ["-k"],
            bottle: bottle,
            environment: compatibilityEnvironment
        ) { }
    }

    func applySteamCompatibilityDLLOverrides(_ environment: inout [String: String]) {
        guard VectorWineInstaller.steamCompatibilityWineBinary() != nil else {
            return
        }

        let current = environment["WINEDLLOVERRIDES"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sanitized = sanitizeSteamClientDLLOverrides(current)
        let withNVAPIDisabled = appendNVAPIDisableOverride(to: sanitized)
        if withNVAPIDisabled.isEmpty {
            environment["WINEDLLOVERRIDES"] = Self.steamDisabledNativeDLLOverrides
        } else {
            environment["WINEDLLOVERRIDES"] = withNVAPIDisabled
        }
    }

    func ensureSteamWebHelperBuiltins(environment: [String: String]) async {
        // Compatibility runtimes no longer need forced SteamWebHelper DLL builtins.
        // Keep this function as a cleanup pass for older marker states.
        await clearSteamWebHelperBuiltinsIfNeeded(environment: environment)
    }

    func clearSteamWebHelperBuiltinsIfNeeded(environment: [String: String]) async {
        _ = try? await Wine.runWine(
            [
                "reg",
                "delete",
                Self.steamWebHelperDLLOverridesRegistryKey,
                "/f"
            ],
            bottle: bottle,
            environment: environment,
            collectOutput: false
        )

        removeSteamWebHelperBuiltinsMarker()
        removeSteamWebHelperCleanupMarker()
        writeSteamWebHelperCleanupMarker()
    }

    func ensureSteamClientBuiltinsForGameD3DOverrides(environment: [String: String]) async {
        for executableName in ["steam.exe", "steamwebhelper.exe"] {
            let dllOverridesKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\DllOverrides"
            await applyAppDefaultDLLOverrides(
                registryKey: dllOverridesKey,
                dlls: Self.steamWebHelperBuiltinDLLs,
                value: "builtin",
                environment: environment
            )
        }
    }

    func ensureMinecraftDungeonsSteamChildLaunchBridge(environment: [String: String]) async {
        await ensureSteamClientBuiltinsForGameD3DOverrides(environment: environment)
        await applyAppDefaultDLLOverrides(
            registryKey: Self.minecraftDungeonsGlobalDLLOverridesKey,
            dlls: Self.minecraftDungeonsBuiltinD3D11DLLs,
            value: Self.minecraftDungeonsBuiltinOverrideValue,
            environment: environment
        )
        await applyAppDefaultDLLOverrides(
            registryKey: Self.minecraftDungeonsGlobalDLLOverridesKey,
            dlls: Self.minecraftDungeonsDisabledDLLs,
            value: Self.minecraftDungeonsDisabledOverrideValue,
            environment: environment
        )
    }

    func ensureGlobalMediaPlaybackDefaults(environment: [String: String]) async {
        // Keep media fixes process-scoped. Persistent global media overrides
        // destabilize launchers such as Steam because Wine reads this key for
        // every child process in the prefix.
        await removeAppDefaultDLLOverrides(
            registryKey: Self.globalMediaDLLOverridesKey,
            dlls: Self.globalMediaPlaybackDLLs,
            environment: environment
        )
        removeGlobalMediaPlaybackMarker()
    }

    func ensureHighOnLife2AppDefaults(environment: [String: String]) async {
        guard steamSettingsLaunchesApp() else {
            return
        }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplyHighOnLife2Compatibility(activeSteamAppID: activeSteamAppID) else {
            return
        }
        guard !hasHighOnLife2AppDefaultsMarker() else {
            return
        }

        await clearHighOnLife2GlobalDLLOverrides(environment: environment)

        for executableName in Self.highOnLife2ExecutableNames {
            await applyHighOnLife2AppDefaults(for: executableName, environment: environment)
        }

        writeHighOnLife2AppDefaultsMarker()
    }

    func ensureParcelSimulatorAppDefaults(environment: [String: String]) async {
        guard steamSettingsLaunchesApp() else {
            return
        }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplyParcelSimulatorCompatibility(activeSteamAppID: activeSteamAppID) else {
            return
        }
        guard !hasParcelSimulatorAppDefaultsMarker() else {
            return
        }

        await clearParcelSimulatorGlobalDLLOverrides(environment: environment)

        for executableName in Self.parcelSimulatorExecutableNames {
            await applyParcelSimulatorAppDefaults(for: executableName, environment: environment)
        }

        writeParcelSimulatorAppDefaultsMarker()
    }

    func ensureMinecraftDungeonsAppDefaults(
        environment: [String: String],
        preserveGlobalD3DOverrides: Bool = false
    ) async {
        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplyMinecraftDungeonsCompatibility(activeSteamAppID: activeSteamAppID) else {
            return
        }
        await ensureMinecraftDungeonsProtocolBridge(environment: environment)
        if hasMinecraftDungeonsAppDefaultsMarker(), minecraftDungeonsAppDefaultsLookCurrent() {
            if !preserveGlobalD3DOverrides {
                await clearMinecraftDungeonsGlobalDLLOverrides(environment: environment)
            }
            return
        }

        if !preserveGlobalD3DOverrides {
            await clearMinecraftDungeonsGlobalDLLOverrides(environment: environment)
        }

        for executableName in Self.minecraftDungeonsExecutableNames {
            await applyMinecraftDungeonsAppDefaults(for: executableName, environment: environment)
        }
        for executableName in Self.minecraftDungeonsCEFExecutableNames {
            await applyMinecraftDungeonsCEFAppDefaults(for: executableName, environment: environment)
        }

        writeMinecraftDungeonsAppDefaultsMarker()
    }

    func ensureContentWarningAppDefaults(environment: [String: String]) async {
        guard steamSettingsLaunchesApp() else {
            return
        }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplyContentWarningCompatibility(activeSteamAppID: activeSteamAppID) else {
            return
        }
        guard !hasContentWarningAppDefaultsMarker() else {
            return
        }

        await clearContentWarningGlobalDLLOverrides(environment: environment)

        for executableName in Self.contentWarningExecutableNames {
            await applyContentWarningAppDefaults(for: executableName, environment: environment)
        }

        writeContentWarningAppDefaultsMarker()
    }

    func ensureOriginAppDefaults(environment: [String: String]) async {
        guard !hasOriginAppDefaultsMarker() else {
            return
        }

        await clearOriginGlobalDLLOverrides(environment: environment)

        for executableName in Self.originExecutableNames {
            await applyOriginAppDefaults(for: executableName, environment: environment)
        }

        writeOriginAppDefaultsMarker()
    }

    func ensureTitanfall2AppDefaults(environment: [String: String]) async {
        guard steamSettingsLaunchesApp() else {
            return
        }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplyTitanfall2Compatibility(activeSteamAppID: activeSteamAppID) else {
            return
        }
        guard !hasTitanfall2AppDefaultsMarker() else {
            return
        }

        await clearTitanfall2GlobalDLLOverrides(environment: environment)

        for executableName in Self.titanfall2ExecutableNames {
            await applyTitanfall2AppDefaults(for: executableName, environment: environment)
        }

        writeTitanfall2AppDefaultsMarker()
    }

    func ensureSilentHillFAppDefaults(environment: [String: String]) async {
        guard steamSettingsLaunchesApp() else {
            return
        }

        let activeSteamAppID = bottle.settings.activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard shouldApplySilentHillFCompatibility(activeSteamAppID: activeSteamAppID) else {
            return
        }
        guard !hasSilentHillFAppDefaultsMarker() else {
            return
        }

        await clearSilentHillFGlobalDLLOverrides(environment: environment)

        for executableName in Self.silentHillFExecutableNames {
            await applySilentHillFAppDefaults(for: executableName, environment: environment)
        }

        writeSilentHillFAppDefaultsMarker()
    }

    private func applyHighOnLife2AppDefaults(
        for executableName: String,
        environment: [String: String]
    ) async {
        let dllOverridesKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\DllOverrides"
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.highOnLife2DXVKDLLs,
            value: Self.highOnLife2DXVKOverrideValue,
            environment: environment
        )
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.highOnLife2DisabledDLLs,
            value: Self.highOnLife2DisabledOverrideValue,
            environment: environment
        )
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.highOnLife2NvidiaPluginDLLs,
            value: Self.highOnLife2DisabledOverrideValue,
            environment: environment
        )
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.highOnLife2NativeAMDModules,
            value: Self.highOnLife2NativeAMDOverrideValue,
            environment: environment
        )

        let direct3DKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\Direct3D"
        await removeAppDefaultDirect3DOverrides(registryKey: direct3DKey, environment: environment)
        await writeAppDefaultDirect3DSetting(
            registryKey: direct3DKey,
            setting: Self.highOnLife2Direct3DRendererSetting,
            value: Self.highOnLife2Direct3DRendererValue,
            environment: environment
        )
    }

    private func applyParcelSimulatorAppDefaults(
        for executableName: String,
        environment: [String: String]
    ) async {
        let dllOverridesKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\DllOverrides"
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.parcelSimulatorDXVKDLLs,
            value: Self.parcelSimulatorDXVKOverrideValue,
            environment: environment
        )
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.parcelSimulatorDisabledDLLs,
            value: Self.parcelSimulatorDisabledOverrideValue,
            environment: environment
        )

        let direct3DKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\Direct3D"
        await removeParcelSimulatorDirect3DOverrides(registryKey: direct3DKey, environment: environment)
        await writeAppDefaultDirect3DSetting(
            registryKey: direct3DKey,
            setting: Self.parcelSimulatorDirect3DRendererSetting,
            value: Self.parcelSimulatorDirect3DRendererValue,
            environment: environment
        )
    }

    private func applyMinecraftDungeonsAppDefaults(
        for executableName: String,
        environment: [String: String]
    ) async {
        let dllOverridesKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\DllOverrides"
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.minecraftDungeonsBuiltinD3D11DLLs,
            value: Self.minecraftDungeonsBuiltinOverrideValue,
            environment: environment
        )
        for dll in Self.minecraftDungeonsLegacyDisabledD3D12DLLs {
            await deleteAppDefaultDLLOverride(
                registryKey: dllOverridesKey,
                dll: dll,
                environment: environment
            )
        }
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.minecraftDungeonsDisabledDLLs,
            value: Self.minecraftDungeonsDisabledOverrideValue,
            environment: environment
        )
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.minecraftDungeonsMediaBuiltinDLLs,
            value: Self.minecraftDungeonsMediaBuiltinValue,
            environment: environment
        )
        await deleteAppDefaultDLLOverride(
            registryKey: dllOverridesKey,
            dll: "mmdevapi",
            environment: environment
        )

        let direct3DKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\Direct3D"
        await removeMinecraftDungeonsDirect3DOverrides(registryKey: direct3DKey, environment: environment)
        await writeAppDefaultDirect3DSetting(
            registryKey: direct3DKey,
            setting: Self.minecraftDungeonsDirect3DRendererSetting,
            value: Self.minecraftDungeonsDirect3DRendererValue,
            environment: environment
        )
    }

    private func applyMinecraftDungeonsCEFAppDefaults(
        for executableName: String,
        environment: [String: String]
    ) async {
        let dllOverridesKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\DllOverrides"
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.minecraftDungeonsCEFBuiltinDLLs,
            value: Self.minecraftDungeonsCEFBuiltinValue,
            environment: environment
        )
        for dll in Self.minecraftDungeonsLegacyDisabledD3D12DLLs {
            await deleteAppDefaultDLLOverride(
                registryKey: dllOverridesKey,
                dll: dll,
                environment: environment
            )
        }
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.minecraftDungeonsCEFDisabledDLLs,
            value: Self.minecraftDungeonsCEFDisabledValue,
            environment: environment
        )
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.minecraftDungeonsMediaBuiltinDLLs,
            value: Self.minecraftDungeonsMediaBuiltinValue,
            environment: environment
        )

        let direct3DKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\Direct3D"
        await removeMinecraftDungeonsDirect3DOverrides(registryKey: direct3DKey, environment: environment)
        await writeAppDefaultDirect3DSetting(
            registryKey: direct3DKey,
            setting: Self.minecraftDungeonsCEFRendererKey,
            value: Self.minecraftDungeonsCEFRendererValue,
            environment: environment
        )
    }

    private func ensureMinecraftDungeonsProtocolBridge(environment: [String: String]) async {
        if hasMinecraftDungeonsProtocolBridgeMarker(), minecraftDungeonsProtocolBridgeLooksCurrent() {
            return
        }

        let callbackCommand = resolveMinecraftDungeonsCallbackProtocolCommand()
            ?? #""C:\Program Files (x86)\Steam\steam.exe" -applaunch 1672970 "%1""#
        await registerMinecraftDungeonsProtocolSchemes(
            Self.minecraftDungeonsSteamProtocolSchemes,
            command: callbackCommand,
            environment: environment
        )

        if let edgeCommand = resolveMinecraftDungeonsEdgeProtocolCommand() {
            await registerMinecraftDungeonsProtocolSchemes(
                Self.minecraftDungeonsEdgeProtocolSchemes,
                command: edgeCommand,
                environment: environment
            )
        } else {
            Logger.wineKit.warning(
                "Minecraft Dungeons protocol bridge could not locate msedge.exe in the bottle."
            )
        }

        writeMinecraftDungeonsProtocolBridgeMarker()
    }

    private func registerMinecraftDungeonsProtocolSchemes(
        _ schemes: [String],
        command: String,
        environment: [String: String]
    ) async {
        for scheme in schemes {
            let baseKey = "HKCU\\Software\\Classes\\\(scheme)"
            await writeProtocolBridgeValue(
                registryKey: baseKey,
                name: nil,
                value: "URL:\(scheme) protocol",
                environment: environment
            )
            await writeProtocolBridgeValue(
                registryKey: baseKey,
                name: "URL Protocol",
                value: "",
                environment: environment
            )
            await writeProtocolBridgeValue(
                registryKey: "\(baseKey)\\Shell\\Open\\Command",
                name: nil,
                value: command,
                environment: environment
            )
        }
    }

    private func resolveMinecraftDungeonsCallbackProtocolCommand() -> String? {
        let candidates: [(path: String, command: String)] = [
            (
                "drive_c/Program Files (x86)/Steam/steamapps/common/MinecraftDungeons/Dungeons.exe",
                #""C:\Program Files (x86)\Steam\steamapps\common\MinecraftDungeons\Dungeons.exe" "%1""#
            ),
            (
                "drive_c/Program Files/Steam/steamapps/common/MinecraftDungeons/Dungeons.exe",
                #""C:\Program Files\Steam\steamapps\common\MinecraftDungeons\Dungeons.exe" "%1""#
            )
        ]

        return candidates.first { candidate in
            let path = bottle.url
                .appending(path: candidate.path)
                .path(percentEncoded: false)
            return FileManager.default.fileExists(atPath: path)
        }?.command
    }

    private func resolveMinecraftDungeonsEdgeProtocolCommand() -> String? {
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
            guard let version = resolveLatestVersionDirectoryName(in: hostRoot) else {
                continue
            }

            let hostExecutable = hostRoot.appending(path: version).appending(path: "msedge.exe")
            let hostPath = hostExecutable.path(percentEncoded: false)
            guard FileManager.default.fileExists(atPath: hostPath) else {
                continue
            }

            let edgeCommand =
                #""\#(windowsRoot)\\\#(version)\msedge.exe" --disable-gpu --disable-gpu-compositing "#
                + #"--disable-accelerated-video-decode --disable-low-latency-dxva "#
                + #"--disable-zero-copy-dxgi-video --single-argument "%1""#
            return edgeCommand
        }

        return nil
    }

    private func resolveLatestVersionDirectoryName(in root: URL) -> String? {
        let fileManager = FileManager.default
        guard let versions = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let versionNames = versions.compactMap { url -> String? in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  values.isDirectory == true else {
                return nil
            }
            let version = url.lastPathComponent
            guard isVersionDirectoryName(version) else {
                return nil
            }

            let executableURL = url.appending(path: "msedge.exe")
            let executablePath = executableURL.path(percentEncoded: false)
            guard fileManager.fileExists(atPath: executablePath) else {
                return nil
            }

            return version
        }

        return versionNames.sorted {
            $0.localizedStandardCompare($1) == .orderedDescending
        }.first
    }

    private func isVersionDirectoryName(_ name: String) -> Bool {
        guard name.first?.isNumber == true, name.contains(".") else {
            return false
        }

        return name.allSatisfy { character in
            character.isNumber || character == "."
        }
    }

    private func applyContentWarningAppDefaults(
        for executableName: String,
        environment: [String: String]
    ) async {
        let dllOverridesKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\DllOverrides"
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.contentWarningDXVKDLLs,
            value: Self.contentWarningDXVKOverrideValue,
            environment: environment
        )
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.contentWarningDisabledDLLs,
            value: Self.contentWarningDisabledOverrideValue,
            environment: environment
        )

        let direct3DKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\Direct3D"
        await removeContentWarningDirect3DOverrides(registryKey: direct3DKey, environment: environment)
        await writeAppDefaultDirect3DSetting(
            registryKey: direct3DKey,
            setting: Self.contentWarningDirect3DRendererSetting,
            value: Self.contentWarningDirect3DRendererValue,
            environment: environment
        )
    }

    private func applyOriginAppDefaults(
        for executableName: String,
        environment: [String: String]
    ) async {
        let dllOverridesKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\DllOverrides"
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.originNativeDLLs,
            value: Self.originNativeOverrideValue,
            environment: environment
        )

        let versionKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\Version"
        await writeAppDefaultWindowsVersion(
            registryKey: versionKey,
            value: Self.originWindowsVersionValue,
            environment: environment
        )
    }

    private func applyTitanfall2AppDefaults(
        for executableName: String,
        environment: [String: String]
    ) async {
        let dllOverridesKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\DllOverrides"
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.titanfall2DXVKDLLs,
            value: Self.titanfall2DXVKOverrideValue,
            environment: environment
        )
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.titanfall2DisabledDLLs,
            value: Self.titanfall2DisabledOverrideValue,
            environment: environment
        )

        let direct3DKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\Direct3D"
        await removeTitanfall2Direct3DOverrides(registryKey: direct3DKey, environment: environment)
        await writeAppDefaultDirect3DSetting(
            registryKey: direct3DKey,
            setting: Self.titanfall2Direct3DRendererSetting,
            value: Self.titanfall2Direct3DRendererValue,
            environment: environment
        )

        let versionKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\Version"
        await writeAppDefaultWindowsVersion(
            registryKey: versionKey,
            value: Self.originWindowsVersionValue,
            environment: environment
        )
    }

    private func applySilentHillFAppDefaults(
        for executableName: String,
        environment: [String: String]
    ) async {
        let dllOverridesKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\DllOverrides"
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.silentHillFDXVKDLLs,
            value: Self.silentHillFDXVKOverrideValue,
            environment: environment
        )
        await applyAppDefaultDLLOverrides(
            registryKey: dllOverridesKey,
            dlls: Self.silentHillFDisabledDLLs,
            value: Self.silentHillFDisabledOverrideValue,
            environment: environment
        )

        let direct3DKey = "HKCU\\Software\\Wine\\AppDefaults\\\(executableName)\\Direct3D"
        await removeSilentHillFDirect3DOverrides(registryKey: direct3DKey, environment: environment)
        await writeAppDefaultDirect3DSetting(
            registryKey: direct3DKey,
            setting: Self.silentHillFDirect3DRendererSetting,
            value: Self.silentHillFDirect3DRendererValue,
            environment: environment
        )
    }

    private func applyAppDefaultDLLOverrides(
        registryKey: String,
        dlls: [String],
        value: String,
        environment: [String: String]
    ) async {
        for dll in dlls {
            await writeAppDefaultDLLOverride(
                registryKey: registryKey,
                dll: dll,
                value: value,
                environment: environment
            )
        }
    }

    private func removeAppDefaultDLLOverrides(
        registryKey: String,
        dlls: [String],
        environment: [String: String]
    ) async {
        for dll in dlls {
            await deleteAppDefaultDLLOverride(
                registryKey: registryKey,
                dll: dll,
                environment: environment
            )
        }
    }

    private func clearHighOnLife2GlobalDLLOverrides(environment: [String: String]) async {
        for dll in Self.highOnLife2ConflictingGlobalDLLs {
            await deleteGlobalDLLOverride(dll: dll, environment: environment)
        }
    }

    private func clearParcelSimulatorGlobalDLLOverrides(environment: [String: String]) async {
        for dll in Self.parcelSimulatorConflictingGlobalDLLs {
            await deleteGlobalDLLOverride(
                dll: dll,
                registryKey: Self.parcelSimulatorGlobalDLLOverridesKey,
                environment: environment
            )
        }
    }

    private func clearMinecraftDungeonsGlobalDLLOverrides(environment: [String: String]) async {
        for dll in Self.minecraftDungeonsConflictingGlobalDLLs {
            await deleteGlobalDLLOverride(
                dll: dll,
                registryKey: Self.minecraftDungeonsGlobalDLLOverridesKey,
                environment: environment
            )
        }
    }

    private func clearContentWarningGlobalDLLOverrides(environment: [String: String]) async {
        for dll in Self.contentWarningConflictingGlobalDLLs {
            await deleteGlobalDLLOverride(
                dll: dll,
                registryKey: Self.contentWarningGlobalDLLOverridesKey,
                environment: environment
            )
        }
    }

    private func clearOriginGlobalDLLOverrides(environment: [String: String]) async {
        for dll in Self.originConflictingGlobalDLLs {
            await deleteGlobalDLLOverride(
                dll: dll,
                registryKey: Self.originGlobalDLLOverridesKey,
                environment: environment
            )
        }
    }

    private func clearTitanfall2GlobalDLLOverrides(environment: [String: String]) async {
        for dll in Self.titanfall2ConflictingGlobalDLLs {
            await deleteGlobalDLLOverride(
                dll: dll,
                registryKey: Self.titanfall2GlobalDLLOverridesKey,
                environment: environment
            )
        }
    }

    private func clearSilentHillFGlobalDLLOverrides(environment: [String: String]) async {
        for dll in Self.silentHillFConflictingGlobalDLLs {
            await deleteGlobalDLLOverride(
                dll: dll,
                registryKey: Self.silentHillFGlobalDLLOverridesKey,
                environment: environment
            )
        }
    }

    private func hasHighOnLife2AppDefaultsMarker() -> Bool {
        let markerPath = highOnLife2AppDefaultsMarkerURL().path(percentEncoded: false)
        return FileManager.default.fileExists(atPath: markerPath)
    }

    private func hasParcelSimulatorAppDefaultsMarker() -> Bool {
        let markerPath = parcelSimulatorAppDefaultsMarkerURL().path(percentEncoded: false)
        return FileManager.default.fileExists(atPath: markerPath)
    }

    private func hasMinecraftDungeonsAppDefaultsMarker() -> Bool {
        let markerPath = minecraftDungeonsAppDefaultsMarkerURL().path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: markerPath) else {
            return false
        }

        return minecraftDungeonsAppDefaultsLookCurrent()
    }

    private func hasMinecraftDungeonsProtocolBridgeMarker() -> Bool {
        let markerPath = minecraftDungeonsProtocolBridgeMarkerURL().path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: markerPath) else {
            return false
        }

        return minecraftDungeonsProtocolBridgeLooksCurrent()
    }

    private func hasContentWarningAppDefaultsMarker() -> Bool {
        let markerPath = contentWarningAppDefaultsMarkerURL().path(percentEncoded: false)
        return FileManager.default.fileExists(atPath: markerPath)
    }

    private func hasOriginAppDefaultsMarker() -> Bool {
        let markerPath = originAppDefaultsMarkerURL().path(percentEncoded: false)
        return FileManager.default.fileExists(atPath: markerPath)
    }

    private func hasTitanfall2AppDefaultsMarker() -> Bool {
        let markerPath = titanfall2AppDefaultsMarkerURL().path(percentEncoded: false)
        return FileManager.default.fileExists(atPath: markerPath)
    }

    private func hasSilentHillFAppDefaultsMarker() -> Bool {
        let markerPath = silentHillFAppDefaultsMarkerURL().path(percentEncoded: false)
        return FileManager.default.fileExists(atPath: markerPath)
    }

    private func writeHighOnLife2AppDefaultsMarker() {
        let markerPath = highOnLife2AppDefaultsMarkerURL().path(percentEncoded: false)
        guard !FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning(
                "Failed to create HighOnLife2 AppDefaults marker at \(markerPath, privacy: .public)"
            )
        }
    }

    private func writeParcelSimulatorAppDefaultsMarker() {
        let markerPath = parcelSimulatorAppDefaultsMarkerURL().path(percentEncoded: false)
        guard !FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning(
                "Failed to create Parcel Simulator AppDefaults marker at \(markerPath, privacy: .public)"
            )
        }
    }

    private func writeMinecraftDungeonsAppDefaultsMarker() {
        let markerPath = minecraftDungeonsAppDefaultsMarkerURL().path(percentEncoded: false)
        guard !FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning(
                "Failed to create Minecraft Dungeons AppDefaults marker at \(markerPath, privacy: .public)"
            )
        }
    }

    private func writeMinecraftDungeonsProtocolBridgeMarker() {
        let markerPath = minecraftDungeonsProtocolBridgeMarkerURL().path(percentEncoded: false)
        guard !FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning(
                "Failed to create Minecraft Dungeons protocol marker at \(markerPath, privacy: .public)"
            )
        }
    }

    private func writeContentWarningAppDefaultsMarker() {
        let markerPath = contentWarningAppDefaultsMarkerURL().path(percentEncoded: false)
        guard !FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning(
                "Failed to create Content Warning AppDefaults marker at \(markerPath, privacy: .public)"
            )
        }
    }

    private func writeOriginAppDefaultsMarker() {
        let markerPath = originAppDefaultsMarkerURL().path(percentEncoded: false)
        guard !FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning(
                "Failed to create Origin AppDefaults marker at \(markerPath, privacy: .public)"
            )
        }
    }

    private func writeTitanfall2AppDefaultsMarker() {
        let markerPath = titanfall2AppDefaultsMarkerURL().path(percentEncoded: false)
        guard !FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning(
                "Failed to create Titanfall 2 AppDefaults marker at \(markerPath, privacy: .public)"
            )
        }
    }

    private func writeSilentHillFAppDefaultsMarker() {
        let markerPath = silentHillFAppDefaultsMarkerURL().path(percentEncoded: false)
        guard !FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning(
                "Failed to create Silent Hill f AppDefaults marker at \(markerPath, privacy: .public)"
            )
        }
    }

    private func highOnLife2AppDefaultsMarkerURL() -> URL {
        bottle.url.appending(path: Self.highOnLife2AppDefaultsMarkerFilename)
    }

    private func parcelSimulatorAppDefaultsMarkerURL() -> URL {
        bottle.url.appending(path: Self.parcelSimulatorAppDefaultsMarkerFilename)
    }

    private func minecraftDungeonsAppDefaultsMarkerURL() -> URL {
        bottle.url.appending(path: Self.minecraftDungeonsAppDefaultsMarkerFile)
    }

    private func minecraftDungeonsProtocolBridgeMarkerURL() -> URL {
        bottle.url.appending(path: Self.minecraftDungeonsAuthMarkerFile)
    }

    private func minecraftDungeonsAppDefaultsLookCurrent() -> Bool {
        guard let userRegistry = try? String(
            contentsOf: bottle.url.appending(path: "user.reg"),
            encoding: .utf8
        ) else {
            return false
        }

        let mainDllOverrides = #"Software\\Wine\\AppDefaults\\Dungeons-Win64-Shipping.exe\\DllOverrides"#
        let mainRenderer = #"Software\\Wine\\AppDefaults\\Dungeons-Win64-Shipping.exe\\Direct3D"#
        let cefDllOverrides = #"Software\\Wine\\AppDefaults\\UnrealCEFSubProcess.exe\\DllOverrides"#
        let cefRenderer = #"Software\\Wine\\AppDefaults\\UnrealCEFSubProcess.exe\\Direct3D"#

        return userRegistry.contains(mainDllOverrides)
            && userRegistry.contains(mainRenderer)
            && userRegistry.contains(#""dxgi"="native,builtin""#)
            && !userRegistry.contains(#""mmdevapi"="disabled""#)
            && userRegistry.contains(cefDllOverrides)
            && userRegistry.contains(cefRenderer)
            && userRegistry.contains(#""dxgi"="builtin""#)
            && userRegistry.contains(#""mf"="builtin""#)
            && userRegistry.contains(#""renderer"="gl""#)
    }

    private func minecraftDungeonsProtocolBridgeLooksCurrent() -> Bool {
        guard let userRegistry = try? String(
            contentsOf: bottle.url.appending(path: "user.reg"),
            encoding: .utf8
        ) else {
            return false
        }

        let edgeCommandKey = #"Software\\Classes\\microsoft-edge\\Shell\\Open\\Command"#
        let xboxCommandKey = #"Software\\Classes\\xbox\\Shell\\Open\\Command"#
        let appxWebCommandKey = #"Software\\Classes\\ms-appx-web\\Shell\\Open\\Command"#
        let callbackCommandTarget = #"MinecraftDungeons\\Dungeons.exe"#

        return userRegistry.contains(edgeCommandKey)
            && userRegistry.contains(xboxCommandKey)
            && userRegistry.contains(appxWebCommandKey)
            && userRegistry.contains(callbackCommandTarget)
            && userRegistry.contains("--disable-gpu --disable-gpu-compositing")
            && userRegistry.contains("--disable-accelerated-video-decode")
            && userRegistry.contains("--disable-low-latency-dxva")
            && userRegistry.contains("--disable-zero-copy-dxgi-video --single-argument \"%1\"")
    }

    private func contentWarningAppDefaultsMarkerURL() -> URL {
        bottle.url.appending(path: Self.contentWarningAppDefaultsMarkerFilename)
    }

    private func originAppDefaultsMarkerURL() -> URL {
        bottle.url.appending(path: Self.originAppDefaultsMarkerFilename)
    }

    private func titanfall2AppDefaultsMarkerURL() -> URL {
        bottle.url.appending(path: Self.titanfall2AppDefaultsMarkerFilename)
    }

    private func silentHillFAppDefaultsMarkerURL() -> URL {
        bottle.url.appending(path: Self.silentHillFAppDefaultsMarkerFilename)
    }

    private func deleteGlobalDLLOverride(
        dll: String,
        environment: [String: String]
    ) async {
        await deleteGlobalDLLOverride(
            dll: dll,
            registryKey: Self.highOnLife2GlobalDLLOverridesRegistryKey,
            environment: environment
        )
    }

    private func deleteGlobalDLLOverride(
        dll: String,
        registryKey: String,
        environment: [String: String]
    ) async {
        do {
            _ = try await Wine.runWine(
                [
                    "reg",
                    "delete",
                    registryKey,
                    "/v",
                    dll,
                    "/f"
                ],
                bottle: bottle,
                environment: environment,
                collectOutput: false
            )
        } catch {
            // Missing keys are expected; this cleanup is intentionally best-effort.
        }
    }

    private func removeAppDefaultDirect3DOverrides(
        registryKey: String,
        environment: [String: String]
    ) async {
        for setting in Self.highOnLife2Direct3DSettingsToClear {
            await deleteAppDefaultDirect3DSetting(
                registryKey: registryKey,
                setting: setting,
                environment: environment
            )
        }
    }

    private func removeParcelSimulatorDirect3DOverrides(
        registryKey: String,
        environment: [String: String]
    ) async {
        for setting in Self.parcelSimulatorDirect3DSettingsToClear {
            await deleteAppDefaultDirect3DSetting(
                registryKey: registryKey,
                setting: setting,
                environment: environment
            )
        }
    }

    private func removeMinecraftDungeonsDirect3DOverrides(
        registryKey: String,
        environment: [String: String]
    ) async {
        for setting in Self.minecraftDungeonsDirect3DSettingsToClear {
            await deleteAppDefaultDirect3DSetting(
                registryKey: registryKey,
                setting: setting,
                environment: environment
            )
        }
    }

    private func removeContentWarningDirect3DOverrides(
        registryKey: String,
        environment: [String: String]
    ) async {
        for setting in Self.contentWarningDirect3DSettingsToClear {
            await deleteAppDefaultDirect3DSetting(
                registryKey: registryKey,
                setting: setting,
                environment: environment
            )
        }
    }

    private func removeTitanfall2Direct3DOverrides(
        registryKey: String,
        environment: [String: String]
    ) async {
        for setting in Self.titanfall2Direct3DSettingsToClear {
            await deleteAppDefaultDirect3DSetting(
                registryKey: registryKey,
                setting: setting,
                environment: environment
            )
        }
    }

    private func removeSilentHillFDirect3DOverrides(
        registryKey: String,
        environment: [String: String]
    ) async {
        for setting in Self.silentHillFDirect3DSettingsToClear {
            await deleteAppDefaultDirect3DSetting(
                registryKey: registryKey,
                setting: setting,
                environment: environment
            )
        }
    }

    private func writeAppDefaultDLLOverride(
        registryKey: String,
        dll: String,
        value: String,
        environment: [String: String]
    ) async {
        do {
            _ = try await Wine.runWine(
                [
                    "reg",
                    "add",
                    registryKey,
                    "/v",
                    dll,
                    "/t",
                    "REG_SZ",
                    "/d",
                    value,
                    "/f"
                ],
                bottle: bottle,
                environment: environment,
                collectOutput: false
            )
        } catch {
            Logger.wineKit.warning(
                """
                Failed to set AppDefaults for \(dll, privacy: .public) at \
                \(registryKey, privacy: .public): \(error.localizedDescription, privacy: .public)
                """
            )
        }
    }

    private func writeAppDefaultWindowsVersion(
        registryKey: String,
        value: String,
        environment: [String: String]
    ) async {
        do {
            _ = try await Wine.runWine(
                [
                    "reg",
                    "add",
                    registryKey,
                    "/ve",
                    "/t",
                    "REG_SZ",
                    "/d",
                    value,
                    "/f"
                ],
                bottle: bottle,
                environment: environment,
                collectOutput: false
            )
        } catch {
            Logger.wineKit.warning(
                """
                Failed to set AppDefaults Windows version at \
                \(registryKey, privacy: .public): \(error.localizedDescription, privacy: .public)
                """
            )
        }
    }

    private func writeProtocolBridgeValue(
        registryKey: String,
        name: String?,
        value: String,
        environment: [String: String]
    ) async {
        var arguments = ["reg", "add", registryKey]
        if let name, !name.isEmpty {
            arguments.append(contentsOf: ["/v", name])
        } else {
            arguments.append("/ve")
        }
        arguments.append(contentsOf: ["/t", "REG_SZ", "/d", value, "/f"])

        do {
            _ = try await Wine.runWine(
                arguments,
                bottle: bottle,
                environment: environment,
                collectOutput: false
            )
        } catch {
            Logger.wineKit.warning(
                """
                Failed to write Minecraft Dungeons protocol bridge at \
                \(registryKey, privacy: .public): \(error.localizedDescription, privacy: .public)
                """
            )
        }
    }

    private func deleteAppDefaultDLLOverride(
        registryKey: String,
        dll: String,
        environment: [String: String]
    ) async {
        do {
            _ = try await Wine.runWine(
                [
                    "reg",
                    "delete",
                    registryKey,
                    "/v",
                    dll,
                    "/f"
                ],
                bottle: bottle,
                environment: environment,
                collectOutput: false
            )
        } catch {
            Logger.wineKit.warning(
                """
                Failed to remove stale AppDefaults override for \(dll, privacy: .public) at \
                \(registryKey, privacy: .public): \(error.localizedDescription, privacy: .public)
                """
            )
        }
    }

    private func deleteAppDefaultDirect3DSetting(
        registryKey: String,
        setting: String,
        environment: [String: String]
    ) async {
        do {
            _ = try await Wine.runWine(
                [
                    "reg",
                    "delete",
                    registryKey,
                    "/v",
                    setting,
                    "/f"
                ],
                bottle: bottle,
                environment: environment,
                collectOutput: false
            )
        } catch {
            Logger.wineKit.warning(
                """
                Failed to clear Direct3D AppDefaults \(setting, privacy: .public) at \
                \(registryKey, privacy: .public): \(error.localizedDescription, privacy: .public)
                """
            )
        }
    }

    private func writeAppDefaultDirect3DSetting(
        registryKey: String,
        setting: String,
        value: String,
        environment: [String: String]
    ) async {
        do {
            _ = try await Wine.runWine(
                [
                    "reg",
                    "add",
                    registryKey,
                    "/v",
                    setting,
                    "/t",
                    "REG_SZ",
                    "/d",
                    value,
                    "/f"
                ],
                bottle: bottle,
                environment: environment,
                collectOutput: false
            )
        } catch {
            Logger.wineKit.warning(
                """
                Failed to set Direct3D AppDefaults \(setting, privacy: .public) at \
                \(registryKey, privacy: .public): \(error.localizedDescription, privacy: .public)
                """
            )
        }
    }

    private func sanitizeSteamClientDLLOverrides(_ value: String) -> String {
        guard !value.isEmpty else { return value }

        let entries = value.split(separator: ";", omittingEmptySubsequences: true)
        var rebuilt: [String] = []

        for rawEntry in entries {
            let entry = rawEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !entry.isEmpty else { continue }

            let parts = entry.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                rebuilt.append(entry)
                continue
            }

            let moduleNames = parts[0].split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let filteredModules = moduleNames.filter { module in
                !Self.steamDXVKDLLNames.contains(module.lowercased())
            }
            guard !filteredModules.isEmpty else { continue }

            let overrideValue = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            rebuilt.append("\(filteredModules.joined(separator: ","))=\(overrideValue)")
        }

        return rebuilt.joined(separator: ";")
    }

    private func appendNVAPIDisableOverride(to value: String) -> String {
        if value.localizedCaseInsensitiveContains("nvapi64")
            || value.localizedCaseInsensitiveContains("nvapi") {
            return value
        }

        if value.isEmpty {
            return Self.steamDisabledNativeDLLOverrides
        }

        return "\(value);\(Self.steamDisabledNativeDLLOverrides)"
    }

    private func hasSteamWebHelperBuiltinsMarker() -> Bool {
        let markerPath = steamWebHelperBuiltinsMarkerURL().path(percentEncoded: false)
        return FileManager.default.fileExists(atPath: markerPath)
    }

    private func hasGlobalMediaPlaybackMarker() -> Bool {
        let markerPath = globalMediaPlaybackMarkerURL().path(percentEncoded: false)
        return FileManager.default.fileExists(atPath: markerPath)
    }

    private func writeSteamWebHelperBuiltinsMarker() {
        let markerPath = steamWebHelperBuiltinsMarkerURL().path(percentEncoded: false)
        guard !FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning(
                "Failed to create SteamWebHelper builtins marker at \(markerPath, privacy: .public)"
            )
        }
    }

    private func writeGlobalMediaPlaybackMarker() {
        let markerPath = globalMediaPlaybackMarkerURL().path(percentEncoded: false)
        guard !FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning(
                "Failed to create global media playback marker at \(markerPath, privacy: .public)"
            )
        }
    }

    private func steamWebHelperBuiltinsMarkerURL() -> URL {
        bottle.url.appending(path: Self.steamWebHelperBuiltinsMarkerFilename)
    }

    private func globalMediaPlaybackMarkerURL() -> URL {
        bottle.url.appending(path: Self.globalMediaPlaybackMarkerFilename)
    }

    private func hasSteamWebHelperCleanupMarker() -> Bool {
        let markerPath = steamWebHelperCleanupMarkerURL().path(percentEncoded: false)
        return FileManager.default.fileExists(atPath: markerPath)
    }

    private func writeSteamWebHelperCleanupMarker() {
        let markerPath = steamWebHelperCleanupMarkerURL().path(percentEncoded: false)
        guard !FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        let created = FileManager.default.createFile(atPath: markerPath, contents: Data())
        if !created {
            Logger.wineKit.warning(
                "Failed to create SteamWebHelper cleanup marker at \(markerPath, privacy: .public)"
            )
        }
    }

    private func removeSteamWebHelperBuiltinsMarker() {
        let markerPath = steamWebHelperBuiltinsMarkerURL().path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        do {
            try FileManager.default.removeItem(atPath: markerPath)
        } catch {
            Logger.wineKit.warning(
                """
                Failed to remove SteamWebHelper builtins marker at \(markerPath, privacy: .public):
                \(error.localizedDescription, privacy: .public)
                """
            )
        }
    }

    private func removeGlobalMediaPlaybackMarker() {
        let markerPath = globalMediaPlaybackMarkerURL().path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        do {
            try FileManager.default.removeItem(atPath: markerPath)
        } catch {
            Logger.wineKit.warning(
                """
                Failed to remove global media playback marker at \(markerPath, privacy: .public):
                \(error.localizedDescription, privacy: .public)
                """
            )
        }
    }

    private func removeSteamWebHelperCleanupMarker() {
        let markerPath = steamWebHelperCleanupMarkerURL().path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: markerPath) else {
            return
        }

        do {
            try FileManager.default.removeItem(atPath: markerPath)
        } catch {
            Logger.wineKit.warning(
                """
                Failed to remove SteamWebHelper cleanup marker at \(markerPath, privacy: .public):
                \(error.localizedDescription, privacy: .public)
                """
            )
        }
    }

    private func steamWebHelperCleanupMarkerURL() -> URL {
        bottle.url.appending(path: Self.steamWebHelperCleanupMarkerFilename)
    }

    private func isUsingSteamCompatibilityRuntimeEnvironment(_ environment: [String: String]) -> Bool {
        guard let compatibilityWineBinary = VectorWineInstaller.steamCompatibilityWineBinary() else {
            return false
        }

        guard let selectedWineBinary = environment["VECTOR_WINE_BIN_OVERRIDE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !selectedWineBinary.isEmpty else {
            return false
        }

        return URL(filePath: selectedWineBinary).standardizedFileURL == compatibilityWineBinary.standardizedFileURL
    }
}
// swiftlint:enable file_length
