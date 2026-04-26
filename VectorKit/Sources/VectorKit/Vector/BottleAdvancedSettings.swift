//
//  BottleAdvancedSettings.swift
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

public enum WineRuntimeSelection: String, CaseIterable, Codable, Sendable {
    case auto
    case bundled
    case compatibility
    case crossover
    case custom
}

public enum GraphicsBackendMode: String, CaseIterable, Codable, Sendable {
    case auto
    case dxvk
    case dxmt
    case wined3d
    case d3dMetal
}

public enum DLLOverridesPolicy: String, CaseIterable, Codable, Sendable {
    case auto
    case disableNvapi
    case custom
}

public enum AntiCheatPreflightMode: String, CaseIterable, Codable, Sendable {
    case off
    case warn
    case block
}

public enum BottleLogProfile: String, CaseIterable, Codable, Sendable {
    case quiet
    case debug
    case deepDebug
}

public enum RuntimeDLLSyncMode: String, CaseIterable, Codable, Sendable {
    case missingOnly
    case verifyOnly
    case verifyAndRepair
}

public enum DispatchPatchChannel: String, CaseIterable, Codable, Sendable {
    case stable
    case beta
    case experimental
}

public struct BottleRuntimeConfig: Codable, Equatable, Sendable {
    public var selection: WineRuntimeSelection = .auto
    public var customWineBinaryPath: String = ""
    public var customWineserverBinaryPath: String = ""

    public init() {}
}

public struct BottleSteamConfig: Codable, Equatable, Sendable {
    public static let defaultArchiveURL = "http://web.archive.org/web/20250306194830if_/media.steampowered.com/client"

    public var useSafeLaunchFlags: Bool = true
    public var useLegacyExtraFlags: Bool = false
    public var forceNoBrowser: Bool = false
    public var useLegacyBootstrap: Bool = true
    public var packageArchiveURL: String = defaultArchiveURL
    public var resetHTMLCacheOnLaunch: Bool = true
    public var disableOverlay: Bool = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.useSafeLaunchFlags = try container.decodeIfPresent(Bool.self, forKey: .useSafeLaunchFlags) ?? true
        self.useLegacyExtraFlags = try container.decodeIfPresent(Bool.self, forKey: .useLegacyExtraFlags) ?? false
        self.forceNoBrowser = try container.decodeIfPresent(Bool.self, forKey: .forceNoBrowser) ?? false
        self.useLegacyBootstrap = try container.decodeIfPresent(Bool.self, forKey: .useLegacyBootstrap) ?? true
        self.packageArchiveURL = try container.decodeIfPresent(String.self, forKey: .packageArchiveURL)
            ?? Self.defaultArchiveURL
        self.resetHTMLCacheOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .resetHTMLCacheOnLaunch) ?? true
        self.disableOverlay = try container.decodeIfPresent(Bool.self, forKey: .disableOverlay) ?? false
    }
}

public struct BottleCompatibilityConfig: Codable, Equatable, Sendable {
    public var graphicsBackend: GraphicsBackendMode = .auto
    public var inferredGraphicsBackend: GraphicsBackendMode?
    public var inferredFallbackGraphicsBackend: GraphicsBackendMode?
    public var dllOverridesPolicy: DLLOverridesPolicy = .auto
    public var customDLLOverrides: String = ""
    public var forceD3D11Compatibility: Bool = false
    public var mediaPlaybackCompatibilityMode: Bool = true
    public var runtimeDLLSyncMode: RuntimeDLLSyncMode = .verifyOnly
    public var installerCompatibilityMode: Bool = false
    public var dlssRuntimeTranslationEnabled: Bool = false
    public var dlssFrameGenerationFallbackEnabled: Bool = false
    public var trainerSupportMode: Bool = false
    public var nativeGameModeLaunches: Bool = false
    public var antiCheatPreflightMode: AntiCheatPreflightMode = .warn
    public var allowUnsupportedAntiCheatLaunches: Bool = false
    public var safeMultiplayerMode: Bool = false
    public var activeSteamAppID: String = ""

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // swiftlint:disable:next line_length
        func decodeValue<T: Decodable>(_ type: T.Type, key: CodingKeys, default defaultValue: T) throws -> T { try container.decodeIfPresent(type, forKey: key) ?? defaultValue }

        self.graphicsBackend = try decodeValue(GraphicsBackendMode.self, key: .graphicsBackend, default: .auto)
        self.inferredGraphicsBackend = try container.decodeIfPresent(
            GraphicsBackendMode.self,
            forKey: .inferredGraphicsBackend
        )
        self.inferredFallbackGraphicsBackend = try container.decodeIfPresent(
            GraphicsBackendMode.self,
            forKey: .inferredFallbackGraphicsBackend
        )
        self.dllOverridesPolicy = try decodeValue(DLLOverridesPolicy.self, key: .dllOverridesPolicy, default: .auto)
        self.customDLLOverrides = try decodeValue(String.self, key: .customDLLOverrides, default: "")
        self.forceD3D11Compatibility = try decodeValue(Bool.self, key: .forceD3D11Compatibility, default: false)
        self.mediaPlaybackCompatibilityMode = try decodeValue(
            Bool.self,
            key: .mediaPlaybackCompatibilityMode,
            default: true
        )
        self.runtimeDLLSyncMode = try decodeValue(
            RuntimeDLLSyncMode.self,
            key: .runtimeDLLSyncMode,
            default: .verifyOnly
        )
        self.installerCompatibilityMode = try decodeValue(Bool.self, key: .installerCompatibilityMode, default: false)
        self.dlssRuntimeTranslationEnabled = try decodeValue(
            Bool.self,
            key: .dlssRuntimeTranslationEnabled,
            default: false
        )
        self.dlssFrameGenerationFallbackEnabled = try decodeValue(
            Bool.self,
            key: .dlssFrameGenerationFallbackEnabled,
            default: false
        )
        self.trainerSupportMode = try decodeValue(Bool.self, key: .trainerSupportMode, default: false)
        self.nativeGameModeLaunches = try decodeValue(Bool.self, key: .nativeGameModeLaunches, default: false)
        self.antiCheatPreflightMode = try decodeValue(
            AntiCheatPreflightMode.self,
            key: .antiCheatPreflightMode,
            default: .warn
        )
        self.allowUnsupportedAntiCheatLaunches = try decodeValue(
            Bool.self,
            key: .allowUnsupportedAntiCheatLaunches,
            default: false
        )
        self.safeMultiplayerMode = try decodeValue(Bool.self, key: .safeMultiplayerMode, default: false)
        self.activeSteamAppID = try decodeValue(String.self, key: .activeSteamAppID, default: "")
    }
}

public struct BottlePerformanceConfig: Codable, Equatable, Sendable {
    public var shaderCacheEnabled: Bool = true
    public var shaderCachePath: String = ""
    public var frameRateLimit: Int = 0
    public var vsyncEnabled: Bool = false
    public var fsrEnabled: Bool = false
    public var fsrSharpness: Double = 2.0

    public init() {}
}

public struct BottleGamingConfig: Codable, Equatable, Sendable {
    public var enabled: Bool = false
    public var autoInstallLaunchers: Bool = false
    public var autoPinLaunchers: Bool = true
    public var autoApplyKnownGamePatches: Bool = true
    public var autoSnapshotBeforeRiskyChanges: Bool = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        self.autoInstallLaunchers = try container.decodeIfPresent(Bool.self, forKey: .autoInstallLaunchers) ?? false
        self.autoPinLaunchers = try container.decodeIfPresent(Bool.self, forKey: .autoPinLaunchers) ?? true
        self.autoApplyKnownGamePatches = try container.decodeIfPresent(Bool.self, forKey: .autoApplyKnownGamePatches)
            ?? true
        self.autoSnapshotBeforeRiskyChanges = try container.decodeIfPresent(
            Bool.self,
            forKey: .autoSnapshotBeforeRiskyChanges
        ) ?? true
    }
}

public struct BottleDispatchConfig: Codable, Equatable, Sendable {
    public static let defaultEndpointURL = "https://vector.nanite.com.au/api/v1/patches"
    public static let legacyLocalEndpointURL = "http://127.0.0.1:8787/api/v1/patches"
    public static let legacyPlaceholderEndpointURL = "https://dispatch.vector.app/api/v1/patches"

    public var enabled: Bool = false
    public var endpointURL: String = defaultEndpointURL
    public var refreshIntervalMinutes: Int = 30
    public var allowUntrustedTLS: Bool = false
    public var channel: DispatchPatchChannel = .stable
    public var requireSignedRules: Bool = true
    public var lastAppliedVersion: Int = 0
    public var lastAppliedGeneratedAt: String = ""
    public var lastAppliedRulesDigest: String = ""
    public var lastAppliedAt: Date?

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false

        let decodedEndpoint = try container.decodeIfPresent(String.self, forKey: .endpointURL)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if decodedEndpoint.isEmpty
            || decodedEndpoint == Self.legacyLocalEndpointURL
            || decodedEndpoint == Self.legacyPlaceholderEndpointURL {
            self.endpointURL = Self.defaultEndpointURL
        } else {
            self.endpointURL = decodedEndpoint
        }

        self.refreshIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .refreshIntervalMinutes) ?? 30
        self.allowUntrustedTLS = try container.decodeIfPresent(Bool.self, forKey: .allowUntrustedTLS) ?? false
        self.channel = try container.decodeIfPresent(DispatchPatchChannel.self, forKey: .channel) ?? .stable
        self.requireSignedRules = try container.decodeIfPresent(Bool.self, forKey: .requireSignedRules) ?? true
        self.lastAppliedVersion = try container.decodeIfPresent(Int.self, forKey: .lastAppliedVersion) ?? 0
        self.lastAppliedGeneratedAt = try container.decodeIfPresent(String.self, forKey: .lastAppliedGeneratedAt) ?? ""
        self.lastAppliedRulesDigest = try container.decodeIfPresent(String.self, forKey: .lastAppliedRulesDigest) ?? ""
        self.lastAppliedAt = try container.decodeIfPresent(Date.self, forKey: .lastAppliedAt)
    }
}

public struct BottleGameProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var executableMatch: String
    public var steamAppID: String
    public var arguments: String
    public var environment: [String: String]
    public var graphicsBackendOverride: GraphicsBackendMode?
    public var fallbackGraphicsBackend: GraphicsBackendMode?
    public var dispatchPriority: Int?
    public var dispatchRuleVersion: Int?
    public var dispatchRuleID: String?
    public var dispatchChannel: DispatchPatchChannel?
    public var dispatchSource: String?

    public init(
        id: UUID = UUID(),
        name: String = "",
        executableMatch: String = "",
        steamAppID: String = "",
        arguments: String = "",
        environment: [String: String] = [:],
        graphicsBackendOverride: GraphicsBackendMode? = nil,
        fallbackGraphicsBackend: GraphicsBackendMode? = nil,
        dispatchPriority: Int? = nil,
        dispatchRuleVersion: Int? = nil,
        dispatchRuleID: String? = nil,
        dispatchChannel: DispatchPatchChannel? = nil,
        dispatchSource: String? = nil
    ) {
        self.id = id
        self.name = name
        self.executableMatch = executableMatch
        self.steamAppID = steamAppID
        self.arguments = arguments
        self.environment = environment
        self.graphicsBackendOverride = graphicsBackendOverride
        self.fallbackGraphicsBackend = fallbackGraphicsBackend
        self.dispatchPriority = dispatchPriority
        self.dispatchRuleVersion = dispatchRuleVersion
        self.dispatchRuleID = dispatchRuleID
        self.dispatchChannel = dispatchChannel
        self.dispatchSource = dispatchSource
    }
}

public extension BottleSettings {
    var runtimeSelection: WineRuntimeSelection {
        get { runtimeConfig.selection }
        set { runtimeConfig.selection = newValue }
    }

    var customWineBinaryPath: String {
        get { runtimeConfig.customWineBinaryPath }
        set { runtimeConfig.customWineBinaryPath = newValue }
    }

    var customWineserverBinaryPath: String {
        get { runtimeConfig.customWineserverBinaryPath }
        set { runtimeConfig.customWineserverBinaryPath = newValue }
    }

    var steamUseSafeLaunchFlags: Bool {
        get { steamConfig.useSafeLaunchFlags }
        set { steamConfig.useSafeLaunchFlags = newValue }
    }

    var steamUseLegacyExtraFlags: Bool {
        get { steamConfig.useLegacyExtraFlags }
        set { steamConfig.useLegacyExtraFlags = newValue }
    }

    var steamForceNoBrowser: Bool {
        get { steamConfig.forceNoBrowser }
        set { steamConfig.forceNoBrowser = newValue }
    }

    var steamUseLegacyBootstrap: Bool {
        get { steamConfig.useLegacyBootstrap }
        set { steamConfig.useLegacyBootstrap = newValue }
    }

    var steamPackageArchiveURL: String {
        get { steamConfig.packageArchiveURL }
        set { steamConfig.packageArchiveURL = newValue }
    }

    var steamResetHTMLCacheOnLaunch: Bool {
        get { steamConfig.resetHTMLCacheOnLaunch }
        set { steamConfig.resetHTMLCacheOnLaunch = newValue }
    }

    var steamDisableOverlay: Bool {
        get { steamConfig.disableOverlay }
        set { steamConfig.disableOverlay = newValue }
    }

    var graphicsBackendMode: GraphicsBackendMode {
        get { compatibilityConfig.graphicsBackend }
        set { compatibilityConfig.graphicsBackend = newValue }
    }

    var inferredGraphicsBackendMode: GraphicsBackendMode? {
        get { compatibilityConfig.inferredGraphicsBackend }
        set { compatibilityConfig.inferredGraphicsBackend = newValue }
    }

    var inferredFallbackGraphicsBackendMode: GraphicsBackendMode? {
        get { compatibilityConfig.inferredFallbackGraphicsBackend }
        set { compatibilityConfig.inferredFallbackGraphicsBackend = newValue }
    }

    var dllOverridesPolicy: DLLOverridesPolicy {
        get { compatibilityConfig.dllOverridesPolicy }
        set { compatibilityConfig.dllOverridesPolicy = newValue }
    }

    var customDLLOverrides: String {
        get { compatibilityConfig.customDLLOverrides }
        set { compatibilityConfig.customDLLOverrides = newValue }
    }

    var antiCheatPreflightMode: AntiCheatPreflightMode {
        get { compatibilityConfig.antiCheatPreflightMode }
        set { compatibilityConfig.antiCheatPreflightMode = newValue }
    }

    var forceD3D11Compatibility: Bool {
        get { compatibilityConfig.forceD3D11Compatibility }
        set { compatibilityConfig.forceD3D11Compatibility = newValue }
    }

    var mediaPlaybackCompatibilityMode: Bool {
        get { compatibilityConfig.mediaPlaybackCompatibilityMode }
        set { compatibilityConfig.mediaPlaybackCompatibilityMode = newValue }
    }

    var runtimeDLLSyncMode: RuntimeDLLSyncMode {
        get { compatibilityConfig.runtimeDLLSyncMode }
        set { compatibilityConfig.runtimeDLLSyncMode = newValue }
    }

    var installerCompatibilityMode: Bool {
        get { compatibilityConfig.installerCompatibilityMode }
        set { compatibilityConfig.installerCompatibilityMode = newValue }
    }

    var dlssRuntimeTranslationEnabled: Bool {
        get { compatibilityConfig.dlssRuntimeTranslationEnabled }
        set { compatibilityConfig.dlssRuntimeTranslationEnabled = newValue }
    }

    var dlssFrameGenerationFallbackEnabled: Bool {
        get { compatibilityConfig.dlssFrameGenerationFallbackEnabled }
        set { compatibilityConfig.dlssFrameGenerationFallbackEnabled = newValue }
    }

    var trainerSupportMode: Bool {
        get { compatibilityConfig.trainerSupportMode }
        set { compatibilityConfig.trainerSupportMode = newValue }
    }

    var nativeGameModeLaunchesEnabled: Bool {
        get { compatibilityConfig.nativeGameModeLaunches }
        set { compatibilityConfig.nativeGameModeLaunches = newValue }
    }

    var allowUnsupportedAntiCheatLaunches: Bool {
        get { compatibilityConfig.allowUnsupportedAntiCheatLaunches }
        set { compatibilityConfig.allowUnsupportedAntiCheatLaunches = newValue }
    }

    var safeMultiplayerMode: Bool {
        get { compatibilityConfig.safeMultiplayerMode }
        set { compatibilityConfig.safeMultiplayerMode = newValue }
    }

    var activeSteamAppID: String {
        get { compatibilityConfig.activeSteamAppID }
        set { compatibilityConfig.activeSteamAppID = newValue }
    }

    var logProfile: BottleLogProfile {
        get { diagnosticsConfig }
        set { diagnosticsConfig = newValue }
    }

    var shaderCacheEnabled: Bool {
        get { performanceConfig.shaderCacheEnabled }
        set { performanceConfig.shaderCacheEnabled = newValue }
    }

    var shaderCachePath: String {
        get { performanceConfig.shaderCachePath }
        set { performanceConfig.shaderCachePath = newValue }
    }

    var frameRateLimit: Int {
        get { performanceConfig.frameRateLimit }
        set { performanceConfig.frameRateLimit = max(0, newValue) }
    }

    var vsyncEnabled: Bool {
        get { performanceConfig.vsyncEnabled }
        set { performanceConfig.vsyncEnabled = newValue }
    }

    var fsrEnabled: Bool {
        get { performanceConfig.fsrEnabled }
        set { performanceConfig.fsrEnabled = newValue }
    }

    var fsrSharpness: Double {
        get { performanceConfig.fsrSharpness }
        set { performanceConfig.fsrSharpness = max(0, min(5, newValue)) }
    }

    var gameProfiles: [BottleGameProfile] {
        get { profiles }
        set { profiles = newValue }
    }

    var gamingModeEnabled: Bool {
        get { gamingConfig.enabled }
        set { gamingConfig.enabled = newValue }
    }

    var gamingAutoInstallLaunchers: Bool {
        get { gamingConfig.autoInstallLaunchers }
        set { gamingConfig.autoInstallLaunchers = newValue }
    }

    var gamingAutoPinLaunchers: Bool {
        get { gamingConfig.autoPinLaunchers }
        set { gamingConfig.autoPinLaunchers = newValue }
    }

    var gamingAutoApplyKnownGamePatches: Bool {
        get { gamingConfig.autoApplyKnownGamePatches }
        set { gamingConfig.autoApplyKnownGamePatches = newValue }
    }

    var autoSnapshotBeforeRiskyChanges: Bool {
        get { gamingConfig.autoSnapshotBeforeRiskyChanges }
        set { gamingConfig.autoSnapshotBeforeRiskyChanges = newValue }
    }

    var patchDispatchEnabled: Bool {
        get { dispatchConfig.enabled }
        set { dispatchConfig.enabled = newValue }
    }

    var patchDispatchEndpointURL: String {
        get { dispatchConfig.endpointURL }
        set { dispatchConfig.endpointURL = newValue }
    }

    var patchDispatchRefreshIntervalMinutes: Int {
        get { dispatchConfig.refreshIntervalMinutes }
        set { dispatchConfig.refreshIntervalMinutes = max(1, min(180, newValue)) }
    }

    var patchDispatchAllowUntrustedTLS: Bool {
        get { dispatchConfig.allowUntrustedTLS }
        set { dispatchConfig.allowUntrustedTLS = newValue }
    }

    var patchDispatchChannel: DispatchPatchChannel {
        get { dispatchConfig.channel }
        set { dispatchConfig.channel = newValue }
    }

    var patchDispatchRequireSignedRules: Bool {
        get { dispatchConfig.requireSignedRules }
        set { dispatchConfig.requireSignedRules = newValue }
    }

    var patchDispatchLastAppliedVersion: Int {
        get { dispatchConfig.lastAppliedVersion }
        set { dispatchConfig.lastAppliedVersion = max(0, newValue) }
    }

    var patchDispatchLastAppliedGeneratedAt: String {
        get { dispatchConfig.lastAppliedGeneratedAt }
        set { dispatchConfig.lastAppliedGeneratedAt = newValue }
    }

    var patchDispatchLastAppliedRulesDigest: String {
        get { dispatchConfig.lastAppliedRulesDigest }
        set { dispatchConfig.lastAppliedRulesDigest = newValue }
    }

    var patchDispatchLastAppliedAt: Date? {
        get { dispatchConfig.lastAppliedAt }
        set { dispatchConfig.lastAppliedAt = newValue }
    }

    func profile(forProgramPath programPath: String, steamAppID: String = "") -> BottleGameProfile? {
        let normalizedPath = programPath.lowercased()
        let normalizedAppID = steamAppID.trimmingCharacters(in: .whitespacesAndNewlines)

        return profiles.first { profile in
            let profileAppID = profile.steamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedAppID.isEmpty, !profileAppID.isEmpty, profileAppID == normalizedAppID {
                return true
            }

            let executableMatch = profile.executableMatch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if executableMatch.isEmpty {
                return false
            }
            return normalizedPath.contains(executableMatch)
        }
    }
}
