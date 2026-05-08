//
//  VectorCompatibilityDatabase.swift
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

import VectorKit

// Static compatibility metadata is intentionally dense; keep UI code split from this data table.
// swiftlint:disable type_body_length

enum VectorCompatibilityDatabase {
    static let knownGames: [CompatibilityGame] = [
        CompatibilityGame(
            id: "high-on-life-2",
            title: "High On Life 2",
            store: "Steam",
            appID: "2069250",
            rating: .needsTweaks,
            recommendedArguments: "-dx12 -ngxdisable",
            recommendedPreset: "HighOnLife2 Builtin D3D12",
            notes: [
                "Use the bundled runtime profile when possible.",
                "Disable NVAPI and Steam overlay for best stability.",
                "Vector includes FSR/NGX compatibility shims for this title."
            ],
            confidence: 0.72,
            tags: ["UE5", "D3D12", "FSR", "NGX", "local-profile"],
            localProfileName: "Auto: High On Life 2",
            dependencyRepairs: [
                "FSR/NGX shim validation",
                "app-scoped D3D override repair"
            ]
        ),
        CompatibilityGame(
            id: "parcel-simulator",
            title: "Parcel Simulator",
            store: "Steam",
            appID: "2424010",
            rating: .playable,
            recommendedArguments: "-force-d3d11 -dx11 -d3d11",
            recommendedPreset: "Parcel Simulator Builtin D3D11",
            notes: [
                "Use D3D11 mode and DXVK overrides.",
                "Disable NVAPI and Steam overlay.",
                "Launch through Steam app command if direct EXE launch is unstable."
            ],
            confidence: 0.92,
            tags: ["D3D11", "DXVK", "Steam", "remote-rule", "local-profile"],
            localProfileName: "Auto: Parcel Simulator",
            remoteVecPatchRuleID: "fallback-parcel-simulator",
            dependencyRepairs: [
                "DXVK payload repair",
                "runtime DLL mirror validation"
            ]
        ),
        CompatibilityGame(
            id: "minecraft-dungeons",
            title: "Minecraft Dungeons",
            store: "Steam / Standalone",
            appID: "1672970",
            rating: .playable,
            recommendedArguments:
                "-force-d3d11 -dx11 -d3d11 -cef-disable-gpu -cef-disable-gpu-compositing "
                + "-cef-disable-accelerated-video-decode -cef-disable-low-latency-dxva "
                + "-cef-disable-zero-copy-dxgi-video -nosound",
            recommendedPreset: "Auto: Minecraft Dungeons",
            notes: [
                "Prefer Steam app launch for owned Steam copies; Vector routes pinned Steam installs through Steam.",
                "Use Proton-style media/auth profile markers for the Microsoft sign-in and intro video path.",
                "Keep DirectX 11 launch args for stable startup and renderer detection."
            ],
            confidence: 0.78,
            tags: ["D3D11", "Microsoft Auth", "Media", "remote-rule", "auth-repair"],
            localProfileName: "Auto: Minecraft Dungeons",
            remoteVecPatchRuleID: "proton-style-minecraft-dungeons-media-auth-v1",
            dependencyRepairs: [
                "WebView2 auth repair",
                "media playback compatibility",
                "Proton-style media/auth markers"
            ]
        ),
        CompatibilityGame(
            id: "content-warning",
            title: "Content Warning",
            store: "Steam",
            appID: "2881650",
            rating: .needsTweaks,
            recommendedArguments: "-force-d3d11",
            recommendedPreset: "Content Warning Builtin D3D11",
            notes: [
                "Force D3D11 mode for more consistent startup behavior.",
                "Disable NVAPI and Steam overlay to reduce renderer/overlay conflicts.",
                "Launch through Steam app command if direct EXE launch is unstable."
            ],
            confidence: 0.8,
            tags: ["D3D11", "DXVK", "Steam", "remote-rule", "local-profile"],
            localProfileName: "Auto: Content Warning",
            remoteVecPatchRuleID: "fallback-content-warning",
            dependencyRepairs: [
                "DXVK payload repair",
                "runtime DLL mirror validation"
            ]
        ),
        CompatibilityGame(
            id: "silent-hill-f",
            title: "Silent Hill f",
            store: "Steam",
            appID: "2947440",
            rating: .boots,
            recommendedArguments: "-force-d3d11 -dx11 -d3d11",
            recommendedPreset: "Silent Hill f Builtin Profile",
            notes: [
                "DX12 path is unstable on Apple Silicon right now.",
                "Prefer Steam app launch with forced DX11.",
                "Use app-scoped DXVK D3D11 overrides."
            ],
            confidence: 0.58,
            tags: ["D3D11", "DXVK", "Steam", "boots", "local-profile"],
            localProfileName: "Auto: Silent Hill f",
            dependencyRepairs: [
                "DXVK payload repair"
            ]
        ),
        CompatibilityGame(
            id: "wemod",
            title: "WeMod (Wand Runtime)",
            store: "Standalone",
            appID: nil,
            rating: .needsTweaks,
            recommendedArguments:
                "--disable-gpu --disable-gpu-compositing "
                + "--disable-features=RendererCodeIntegrity,CalculateNativeWinOcclusion "
                + "--no-sandbox",
            recommendedPreset: "Electron Window Compatibility",
            notes: [
                "Use a single Wine runtime for wine/wineserver to avoid version mismatch.",
                "Electron UI rendering can be black or hidden depending on GPU mode.",
                "Use compatibility runtime and disable GPU compositing when needed."
            ],
            confidence: 0.64,
            tags: ["Electron", "launcher", "runtime-pair", "local-profile"],
            localProfileName: "Auto: WeMod / Wand",
            dependencyRepairs: [
                "compatibility Wine/wineserver pair",
                "Electron GPU fallback"
            ]
        ),
        CompatibilityGame(
            id: "arc-raiders",
            title: "ARC Raiders",
            store: "Steam",
            appID: "1808500",
            rating: .unsupported,
            recommendedArguments: "",
            recommendedPreset: "Protected Multiplayer: blocked until official support",
            notes: [
                "Uses Easy Anti-Cheat / Embark Game Boot and requires official runtime approval.",
                "Vector blocks local launch instead of bypassing or weakening anti-cheat.",
                "Use Steam Remote Play, Steam Deck/SteamOS Proton, Moonlight/Sunshine, or Windows PC."
            ],
            confidence: 0.98,
            tags: ["EAC", "Protected", "Blocked"],
            trustClassification: .blockedAntiCheat,
            antiCheatProvider: "Easy Anti-Cheat / Embark Game Boot",
            officialSupportRequired: true,
            fallbackPlayOptions: VectorProtectedTitlePolicyEngine.arcRaiders.fallbackPlayOptions,
            supportContactStatus: VectorProtectedTitlePolicyEngine.arcRaiders.supportContactStatus,
            remoteVecPatchRuleID: "fallback-arc-raiders"
        ),
        CompatibilityGame(
            id: "rainbow-six-extraction",
            title: "Tom Clancy's Rainbow Six Extraction",
            store: "Ubisoft Connect",
            appID: nil,
            rating: .unsupported,
            recommendedArguments: "/belaunch -be",
            recommendedPreset: "None",
            notes: [
                "BattlEye anti-cheat is generally unsupported in Wine-based setups.",
                "Offline/anti-cheat-bypassed launch attempts may still fail unpredictably.",
                "Treat as unsupported for now in Vector defaults."
            ],
            tags: ["BattlEye", "Protected", "Blocked", "official-support-required"],
            trustClassification: .blockedAntiCheat,
            antiCheatProvider: "BattlEye",
            officialSupportRequired: true,
            fallbackPlayOptions: ["Windows PC", "Remote Play from a supported host"],
            supportContactStatus: "Official Vector support required"
        ),
        CompatibilityGame(
            id: "forza-horizon-6",
            title: "Forza Horizon 6",
            store: "Steam / Xbox",
            appID: "2483190",
            rating: .needsTweaks,
            recommendedArguments: "-dx12 -d3d12",
            recommendedPreset: "Auto: Forza Horizon 6",
            notes: [
                "Profile is prepared for the DX12 path through D3DMetal/GPTK-style translation.",
                "Requires Windows 10 22H2 semantics, 16 GB RAM, SSD storage, and DirectX 12 feature coverage.",
                "Launch support is release-build dependent; keep DXVK disabled unless testing fallback."
            ],
            confidence: 0.35,
            tags: ["DX12", "D3DMetal", "release-dependent", "local-profile"],
            localProfileName: "Auto: Forza Horizon 6"
        ),
        CompatibilityGame(
            id: "titanfall-2",
            title: "Titanfall 2",
            store: "Steam / EA App",
            appID: "1237970",
            rating: .needsTweaks,
            recommendedArguments: "",
            recommendedPreset: "Titanfall 2 + EA App Compatibility",
            notes: [
                "Requires the EA/Origin bootstrap layer before the game can reach launch.",
                "Keep NVAPI disabled and use the compatibility runtime pair if the launcher stalls.",
                "Steam-owned copies should still start through Steam so ownership and EA handoff work."
            ],
            confidence: 0.66,
            tags: ["D3D11", "EA App", "launcher", "local-profile", "dependency-repair"],
            localProfileName: "Auto: Titanfall 2",
            dependencyRepairs: [
                "EA App bootstrap repair",
                "compatibility Wine/wineserver pair"
            ]
        ),
        CompatibilityGame(
            id: "ea-app-origin",
            title: "EA App / Origin Bootstrap",
            store: "Launcher",
            appID: nil,
            rating: .needsTweaks,
            recommendedArguments: "",
            recommendedPreset: "EA App Launcher Compatibility",
            notes: [
                "Use the launcher dependency repair path if the EA installer window fails to render.",
                "Prefer one matched Wine/wineserver runtime pair to avoid version mismatch failures.",
                "This entry exists so games depending on EA App can surface the same repair guidance."
            ],
            confidence: 0.62,
            tags: ["EA App", "Origin", "launcher", "local-profile", "dependency-repair"],
            localProfileName: "Auto: EA App",
            dependencyRepairs: [
                "launcher dependency repair",
                "compatibility Wine/wineserver pair"
            ]
        ),
        CompatibilityGame(
            id: "lethal-company",
            title: "Lethal Company",
            store: "Steam",
            appID: "1966720",
            rating: .playable,
            recommendedArguments: "",
            recommendedPreset: "Gaming Bottle Default",
            notes: [
                "Reported working in current Vector compatibility setup.",
                "Use default DXVK + shader cache and keep Steam overlay disabled if instability appears."
            ],
            confidence: 0.9,
            tags: ["DXVK", "Steam", "Verified", "local-profile"],
            localProfileName: "Auto: Lethal Company"
        ),
        CompatibilityGame(
            id: "hydroneer",
            title: "Hydroneer",
            store: "Steam",
            appID: "1106840",
            rating: .playable,
            recommendedArguments: "",
            recommendedPreset: "Gaming Bottle Default",
            notes: [
                "Reported working in current Vector compatibility setup.",
                "If startup fails, retry with DirectX 11 compatibility args."
            ],
            confidence: 0.88,
            tags: ["DXVK", "Steam", "Verified", "local-profile"],
            localProfileName: "Auto: Hydroneer"
        ),
        CompatibilityGame(
            id: "satisfactory",
            title: "Satisfactory",
            store: "Steam",
            appID: "526870",
            rating: .playable,
            recommendedArguments: "",
            recommendedPreset: "Gaming Bottle Default",
            notes: [
                "Reported working in current Vector compatibility setup.",
                "Prefer native fullscreen to trigger macOS Game Mode for smoother frame pacing."
            ],
            confidence: 0.86,
            tags: ["Fullscreen", "Steam", "Verified", "D3D11", "local-profile"],
            localProfileName: "Auto: Satisfactory",
            dependencyRepairs: [
                "Unreal dependency preset"
            ]
        ),
        CompatibilityGame(
            id: "escape-the-backrooms",
            title: "Escape the Backrooms",
            store: "Steam",
            appID: "1943950",
            rating: .playable,
            recommendedArguments: "",
            recommendedPreset: "Gaming Bottle Default",
            notes: [
                "Reported working in current Vector compatibility setup.",
                "Use built-in Unreal dependencies preset if the first launch is unstable."
            ],
            confidence: 0.86,
            tags: ["Unreal", "Steam", "Verified", "D3D11", "local-profile"],
            localProfileName: "Auto: Escape the Backrooms",
            dependencyRepairs: [
                "Unreal dependency preset"
            ]
        )
    ]
}

// swiftlint:enable type_body_length
