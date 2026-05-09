//
//  VectorGraphicsBackendPolicy.swift
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

public enum VectorGraphicsAPIIntent: String, CaseIterable, Sendable {
    case d3d9
    case d3d10
    case d3d11
    case d3d12
}

public enum VectorBackendRecommendationSource: String, Sendable {
    case userExplicit
    case dispatchRule
    case failureRecovery
    case defaultPolicy
}

public struct VectorGraphicsBackendCapabilities: Equatable, Sendable {
    public var d3dMetalAvailable: Bool
    public var dxmtAvailable: Bool
    public var dxvkAvailable: Bool

    public init(
        d3dMetalAvailable: Bool,
        dxmtAvailable: Bool,
        dxvkAvailable: Bool
    ) {
        self.d3dMetalAvailable = d3dMetalAvailable
        self.dxmtAvailable = dxmtAvailable
        self.dxvkAvailable = dxvkAvailable
    }

    public static func current() -> VectorGraphicsBackendCapabilities {
        let host = VectorHostSecurityCapabilityProbe.current()
        return VectorGraphicsBackendCapabilities(
            d3dMetalAvailable: host.metalSupported && host.d3dMetalPayloadInstalled,
            dxmtAvailable: Wine.isDXMTPayloadReady(),
            dxvkAvailable: true
        )
    }
}

public struct VectorGraphicsBackendFailureSignals: Equatable, Sendable {
    public var failedBackends: Set<GraphicsBackendMode>
    public var launchFailureClasses: Set<VectorLaunchDoctorFailureClass>
    public var requestedAPIs: Set<VectorGraphicsAPIIntent>
    public var crashSignature: String

    public init(
        failedBackends: Set<GraphicsBackendMode> = [],
        launchFailureClasses: Set<VectorLaunchDoctorFailureClass> = [],
        requestedAPIs: Set<VectorGraphicsAPIIntent> = [],
        crashSignature: String = ""
    ) {
        self.failedBackends = failedBackends
        self.launchFailureClasses = launchFailureClasses
        self.requestedAPIs = requestedAPIs
        self.crashSignature = crashSignature.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var shouldRecommendOverExplicitChoice: Bool {
        !failedBackends.isEmpty
            || !launchFailureClasses.isEmpty
            || !crashSignature.isEmpty
    }
}

public struct VectorGraphicsBackendRecommendation: Equatable, Sendable {
    public var primary: GraphicsBackendMode
    public var fallback: GraphicsBackendMode?
    public var reason: String
    public var source: VectorBackendRecommendationSource
    public var sourceRuleID: String?
    public var shouldOverrideExplicitChoice: Bool
}

public struct VectorBackendRecommendationRequest: Sendable {
    public var configuredBackend: GraphicsBackendMode
    public var activeSteamAppID: String
    public var executableName: String
    public var dispatchRules: [DispatchPatchRule]
    public var capabilities: VectorGraphicsBackendCapabilities
    public var failureSignals: VectorGraphicsBackendFailureSignals
    public var protectedTitleBlocksMutations: Bool

    public init(
        configuredBackend: GraphicsBackendMode = .auto,
        activeSteamAppID: String = "",
        executableName: String = "",
        dispatchRules: [DispatchPatchRule] = [],
        capabilities: VectorGraphicsBackendCapabilities,
        failureSignals: VectorGraphicsBackendFailureSignals = VectorGraphicsBackendFailureSignals(),
        protectedTitleBlocksMutations: Bool = false
    ) {
        self.configuredBackend = configuredBackend
        self.activeSteamAppID = activeSteamAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.executableName = executableName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dispatchRules = dispatchRules
        self.capabilities = capabilities
        self.failureSignals = failureSignals
        self.protectedTitleBlocksMutations = protectedTitleBlocksMutations
    }
}

public enum VectorGraphicsBackendPolicy {
    public static func recommendation(
        for request: VectorBackendRecommendationRequest
    ) -> VectorGraphicsBackendRecommendation? {
        if blocksUnsafeProtectedMutation(request) {
            return nil
        }

        let requestedAPIs = requestedAPIs(for: request)
        let bestRule = rankedMatchingRules(for: request).first
        let failureDemandsOverride = request.failureSignals.shouldRecommendOverExplicitChoice

        if let explicit = explicitRecommendation(
            for: request,
            failureDemandsOverride: failureDemandsOverride
        ) {
            return explicit
        }

        if let d3d12Recommendation = d3d12Recommendation(
            for: request,
            requestedAPIs: requestedAPIs,
            bestRule: bestRule,
            failureDemandsOverride: failureDemandsOverride
        ) {
            return d3d12Recommendation
        }

        if let dispatchRecommendation = dispatchRecommendation(
            for: request,
            bestRule: bestRule,
            failureDemandsOverride: failureDemandsOverride
        ) {
            return dispatchRecommendation
        }

        if let d3d11Recommendation = d3d11Recommendation(
            for: request,
            requestedAPIs: requestedAPIs,
            failureDemandsOverride: failureDemandsOverride
        ) {
            return d3d11Recommendation
        }

        if request.configuredBackend != .auto && failureDemandsOverride {
            return fallbackRecommendation(avoiding: request.configuredBackend, request: request)
        }

        return defaultRecommendation(for: request)
    }

    public static func recommendation(
        for bottle: Bottle,
        rules: [DispatchPatchRule],
        capabilities: VectorGraphicsBackendCapabilities = .current()
    ) -> VectorGraphicsBackendRecommendation? {
        let protectedAssessment = VectorProtectedTitlePolicyEngine.scannedProtectedAssessment(for: bottle)
        let failureClasses = VectorLaunchDoctor.recentLogClassifications(for: bottle).compactMap(\.failureClass)
        let failureSignals = VectorGraphicsBackendFailureSignals(
            launchFailureClasses: Set(failureClasses)
        )
        let request = VectorBackendRecommendationRequest(
            configuredBackend: bottle.settings.graphicsBackendMode,
            activeSteamAppID: bottle.settings.activeSteamAppID,
            dispatchRules: rules.filter { VectorProtectedTitlePolicyEngine.ruleAllowed($0, in: bottle) },
            capabilities: capabilities,
            failureSignals: failureSignals,
            protectedTitleBlocksMutations: protectedAssessment?.shouldBlockLocalLaunch == true
        )
        return recommendation(for: request)
    }
}
