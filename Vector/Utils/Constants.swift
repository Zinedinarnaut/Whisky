//
//  Constants.swift
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

import Foundation
import VectorKit

enum ViewWidth {
    static let small: Double = 400
    static let medium: Double = 500
    static let large: Double = 600
}

enum CompatibilityRating: String, CaseIterable, Identifiable {
    case playable
    case needsTweaks
    case boots
    case broken
    case unsupported

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playable:
            return "Playable"
        case .needsTweaks:
            return "Needs Tweaks"
        case .boots:
            return "Boots"
        case .broken:
            return "Broken"
        case .unsupported:
            return "Unsupported"
        }
    }

    var sortIndex: Int {
        switch self {
        case .playable:
            return 0
        case .needsTweaks:
            return 1
        case .boots:
            return 2
        case .broken:
            return 3
        case .unsupported:
            return 4
        }
    }
}

struct CompatibilityGame: Identifiable, Hashable {
    let id: String
    let title: String
    let store: String
    let appID: String?
    let rating: CompatibilityRating
    let recommendedArguments: String
    let recommendedPreset: String
    let notes: [String]
    let confidence: Double
    let tags: [String]
    let lastVerifiedOn: String
    let trustClassification: GameTrustClassification
    let antiCheatProvider: String?
    let officialSupportRequired: Bool
    let fallbackPlayOptions: [String]
    let supportContactStatus: String

    init(
        id: String,
        title: String,
        store: String,
        appID: String?,
        rating: CompatibilityRating,
        recommendedArguments: String,
        recommendedPreset: String,
        notes: [String],
        confidence: Double = 0.7,
        tags: [String] = [],
        lastVerifiedOn: String = "2026-04-28",
        trustClassification: GameTrustClassification = .singlePlayer,
        antiCheatProvider: String? = nil,
        officialSupportRequired: Bool = false,
        fallbackPlayOptions: [String] = [],
        supportContactStatus: String = ""
    ) {
        self.id = id
        self.title = title
        self.store = store
        self.appID = appID
        self.rating = rating
        self.recommendedArguments = recommendedArguments
        self.recommendedPreset = recommendedPreset
        self.notes = notes
        self.confidence = min(1, max(0, confidence))
        self.tags = tags
        self.lastVerifiedOn = lastVerifiedOn
        self.trustClassification = trustClassification
        self.antiCheatProvider = antiCheatProvider
        self.officialSupportRequired = officialSupportRequired
        self.fallbackPlayOptions = fallbackPlayOptions
        self.supportContactStatus = supportContactStatus
    }
}

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
            tags: ["UE5", "D3D12", "FSR"]
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
            tags: ["D3D11", "DXVK", "Steam"]
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
            tags: ["D3D11", "Microsoft Auth", "Media"]
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
            tags: ["D3D11", "Media", "Steam"]
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
            supportContactStatus: VectorProtectedTitlePolicyEngine.arcRaiders.supportContactStatus
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
            tags: ["DX12", "D3DMetal", "Unreleased"]
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
            tags: ["DXVK", "Steam", "Verified"]
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
            tags: ["DXVK", "Steam", "Verified"]
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
            tags: ["Fullscreen", "Steam", "Verified"]
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
            tags: ["Unreal", "Steam", "Verified"]
        )
    ]
}
