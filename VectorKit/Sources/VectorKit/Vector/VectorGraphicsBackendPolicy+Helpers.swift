//
//  VectorGraphicsBackendPolicy+Helpers.swift
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

struct VectorBackendRecommendationMetadata {
    var source: VectorBackendRecommendationSource
    var sourceRuleID: String?
    var overrideExplicit: Bool
}

extension VectorGraphicsBackendPolicy {
    static func blocksUnsafeProtectedMutation(_ request: VectorBackendRecommendationRequest) -> Bool {
        request.protectedTitleBlocksMutations
            && request.configuredBackend == .auto
            && request.dispatchRules.contains(where: hasGraphicsBackendMutation(_:))
            && !request.dispatchRules.contains(where: safeProtectedBackendMutation(_:))
    }

    static func requestedAPIs(
        for request: VectorBackendRecommendationRequest
    ) -> Set<VectorGraphicsAPIIntent> {
        request.failureSignals.requestedAPIs
            .union(apiIntents(from: contextualBackendRules(for: request)))
            .union(apiIntents(from: request.executableName))
    }

    static func explicitRecommendation(
        for request: VectorBackendRecommendationRequest,
        failureDemandsOverride: Bool
    ) -> VectorGraphicsBackendRecommendation? {
        guard request.configuredBackend != .auto && !failureDemandsOverride else {
            return nil
        }
        return VectorGraphicsBackendRecommendation(
            primary: request.configuredBackend,
            fallback: nil,
            reason: "Explicit bottle graphics backend selection.",
            source: .userExplicit,
            sourceRuleID: nil,
            shouldOverrideExplicitChoice: false
        )
    }

    static func d3d12Recommendation(
        for request: VectorBackendRecommendationRequest,
        requestedAPIs: Set<VectorGraphicsAPIIntent>,
        bestRule: DispatchPatchRule?,
        failureDemandsOverride: Bool
    ) -> VectorGraphicsBackendRecommendation? {
        guard requestedAPIs.contains(.d3d12),
              request.capabilities.d3dMetalAvailable,
              !request.failureSignals.failedBackends.contains(.d3dMetal) else {
            return nil
        }
        return makeRecommendation(
            primary: .d3dMetal,
            fallback: fallbackForD3DMetal(bestRule: bestRule, request: request),
            reason: "D3D12 launch intent prefers D3DMetal when the payload is available.",
            metadata: VectorBackendRecommendationMetadata(
                source: failureDemandsOverride ? .failureRecovery : .dispatchRule,
                sourceRuleID: bestRule?.id,
                overrideExplicit: failureDemandsOverride
            )
        )
    }

    static func dispatchRecommendation(
        for request: VectorBackendRecommendationRequest,
        bestRule: DispatchPatchRule?,
        failureDemandsOverride: Bool
    ) -> VectorGraphicsBackendRecommendation? {
        guard let ruleRecommendation = recommendation(from: bestRule, request: request) else {
            return nil
        }
        if request.configuredBackend != .auto,
           ruleRecommendation.primary == request.configuredBackend,
           failureDemandsOverride {
            return fallbackRecommendation(avoiding: request.configuredBackend, request: request)
        }
        return VectorGraphicsBackendRecommendation(
            primary: ruleRecommendation.primary,
            fallback: ruleRecommendation.fallback,
            reason: ruleRecommendation.reason,
            source: failureDemandsOverride ? .failureRecovery : .dispatchRule,
            sourceRuleID: ruleRecommendation.sourceRuleID,
            shouldOverrideExplicitChoice: failureDemandsOverride
        )
    }

    static func d3d11Recommendation(
        for request: VectorBackendRecommendationRequest,
        requestedAPIs: Set<VectorGraphicsAPIIntent>,
        failureDemandsOverride: Bool
    ) -> VectorGraphicsBackendRecommendation? {
        guard requestedAPIs.contains(.d3d11) || requestedAPIs.contains(.d3d10) else {
            return nil
        }
        let primary = request.capabilities.dxvkAvailable ? GraphicsBackendMode.dxvk : .wined3d
        return makeRecommendation(
            primary: primary,
            fallback: primary == .dxvk ? .wined3d : nil,
            reason: "D3D10/D3D11 launch intent defaults to DXVK with WineD3D fallback.",
            metadata: VectorBackendRecommendationMetadata(
                source: failureDemandsOverride ? .failureRecovery : .defaultPolicy,
                sourceRuleID: nil,
                overrideExplicit: failureDemandsOverride
            )
        )
    }

    static func defaultRecommendation(
        for request: VectorBackendRecommendationRequest
    ) -> VectorGraphicsBackendRecommendation {
        makeRecommendation(
            primary: request.capabilities.dxvkAvailable ? .dxvk : .wined3d,
            fallback: request.capabilities.dxvkAvailable ? .wined3d : nil,
            reason: "Default automatic graphics backend selection.",
            metadata: VectorBackendRecommendationMetadata(
                source: .defaultPolicy,
                sourceRuleID: nil,
                overrideExplicit: false
            )
        )
    }

    static func makeRecommendation(
        primary: GraphicsBackendMode,
        fallback: GraphicsBackendMode?,
        reason: String,
        metadata: VectorBackendRecommendationMetadata
    ) -> VectorGraphicsBackendRecommendation {
        VectorGraphicsBackendRecommendation(
            primary: primary,
            fallback: fallback == primary ? nil : fallback,
            reason: reason,
            source: metadata.source,
            sourceRuleID: metadata.sourceRuleID,
            shouldOverrideExplicitChoice: metadata.overrideExplicit
        )
    }

    static func recommendation(
        from rule: DispatchPatchRule?,
        request: VectorBackendRecommendationRequest
    ) -> VectorGraphicsBackendRecommendation? {
        guard let rule, let primary = availableBackend(rule.graphicsBackend, request: request) else {
            return nil
        }

        let fallback = availableBackend(rule.fallbackGraphicsBackend, request: request)
            ?? defaultFallback(for: primary, request: request)
        return makeRecommendation(
            primary: primary,
            fallback: fallback,
            reason: "Dispatch rule \(rule.name) selected \(primary.rawValue).",
            metadata: VectorBackendRecommendationMetadata(
                source: .dispatchRule,
                sourceRuleID: rule.id,
                overrideExplicit: false
            )
        )
    }

    static func fallbackRecommendation(
        avoiding backend: GraphicsBackendMode,
        request: VectorBackendRecommendationRequest
    ) -> VectorGraphicsBackendRecommendation? {
        let orderedCandidates: [GraphicsBackendMode]
        if request.failureSignals.launchFailureClasses.contains(.dx12Unsupported) {
            orderedCandidates = [.d3dMetal, .dxvk, .dxmt, .wined3d]
        } else if request.failureSignals.launchFailureClasses.contains(.dxFeatureLevel) {
            orderedCandidates = [.dxvk, .dxmt, .d3dMetal, .wined3d]
        } else {
            orderedCandidates = [.dxvk, .dxmt, .d3dMetal, .wined3d]
        }

        guard let primary = orderedCandidates.first(where: {
            $0 != backend && isAvailable($0, request: request)
        }) else {
            return nil
        }

        return makeRecommendation(
            primary: primary,
            fallback: defaultFallback(for: primary, request: request),
            reason: "Recent launch failure signals recommend avoiding \(backend.rawValue).",
            metadata: VectorBackendRecommendationMetadata(
                source: .failureRecovery,
                sourceRuleID: nil,
                overrideExplicit: true
            )
        )
    }

    static func rankedMatchingRules(
        for request: VectorBackendRecommendationRequest
    ) -> [DispatchPatchRule] {
        contextualBackendRules(for: request).sorted(by: shouldPreferRule(_:over:))
    }

    static func contextualBackendRules(
        for request: VectorBackendRecommendationRequest
    ) -> [DispatchPatchRule] {
        let backendRules = request.dispatchRules.filter {
            $0.enabled && $0.graphicsBackend != nil && ruleAllowedForProtectedState($0, request: request)
        }
        let appID = request.activeSteamAppID
        let executable = request.executableName.lowercased()

        guard !appID.isEmpty || !executable.isEmpty else {
            return backendRules.count == 1 ? backendRules : []
        }

        return backendRules.filter { rule in
            if !appID.isEmpty,
               !rule.steamAppID.isEmpty,
               rule.steamAppID == appID {
                return true
            }
            let ruleExecutable = rule.executableMatch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !executable.isEmpty
                && !ruleExecutable.isEmpty
                && (executable == ruleExecutable || executable.contains(ruleExecutable))
        }
    }

    static func shouldPreferRule(_ lhs: DispatchPatchRule, over rhs: DispatchPatchRule) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }
        if lhs.ruleVersion != rhs.ruleVersion {
            return lhs.ruleVersion > rhs.ruleVersion
        }
        if sourcePrecedence(lhs.source) != sourcePrecedence(rhs.source) {
            return sourcePrecedence(lhs.source) < sourcePrecedence(rhs.source)
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    static func sourcePrecedence(_ source: DispatchPatchRuleSource) -> Int {
        switch source {
        case .local:
            return 0
        case .remote:
            return 1
        case .crossover, .proton, .wineGE:
            return 2
        }
    }

    static func ruleAllowedForProtectedState(
        _ rule: DispatchPatchRule,
        request: VectorBackendRecommendationRequest
    ) -> Bool {
        guard request.protectedTitleBlocksMutations else {
            return true
        }
        return safeProtectedBackendMutation(rule)
    }

    static func safeProtectedBackendMutation(_ rule: DispatchPatchRule) -> Bool {
        guard hasGraphicsBackendMutation(rule),
              rule.riskLevel == .low,
              rule.studioApproved,
              let policy = rule.protectedTitlePolicy,
              policy.allowCustomLaunchMutations,
              !policy.allowUnsignedRules,
              policy.localLaunchDisposition == .allow || policy.localLaunchDisposition == .warn else {
            return false
        }
        return DispatchPatchSignatureVerifier.isRuleSignatureValid(rule)
    }

    static func hasGraphicsBackendMutation(_ rule: DispatchPatchRule) -> Bool {
        rule.graphicsBackend != nil || rule.fallbackGraphicsBackend != nil
    }

    static func fallbackForD3DMetal(
        bestRule: DispatchPatchRule?,
        request: VectorBackendRecommendationRequest
    ) -> GraphicsBackendMode? {
        if let fallback = availableBackend(bestRule?.fallbackGraphicsBackend, request: request),
           fallback != .d3dMetal {
            return fallback
        }
        if let primary = availableBackend(bestRule?.graphicsBackend, request: request),
           primary != .d3dMetal {
            return primary
        }
        return request.capabilities.dxvkAvailable ? .dxvk : .wined3d
    }

    static func defaultFallback(
        for backend: GraphicsBackendMode,
        request: VectorBackendRecommendationRequest
    ) -> GraphicsBackendMode? {
        func usable(_ candidate: GraphicsBackendMode) -> GraphicsBackendMode? {
            availableBackend(candidate, request: request)
        }

        switch backend {
        case .auto:
            return nil
        case .d3dMetal:
            return usable(.dxvk) ?? usable(.wined3d)
        case .dxmt:
            return usable(.dxvk) ?? usable(.wined3d)
        case .dxvk:
            return usable(.wined3d)
        case .wined3d:
            return nil
        }
    }

    static func availableBackend(
        _ backend: GraphicsBackendMode?,
        request: VectorBackendRecommendationRequest
    ) -> GraphicsBackendMode? {
        guard let backend,
              backend != .auto,
              !request.failureSignals.failedBackends.contains(backend),
              isAvailable(backend, request: request) else {
            return nil
        }
        return backend
    }

    static func isAvailable(
        _ backend: GraphicsBackendMode,
        request: VectorBackendRecommendationRequest
    ) -> Bool {
        switch backend {
        case .auto:
            return false
        case .d3dMetal:
            return request.capabilities.d3dMetalAvailable
        case .dxmt:
            return request.capabilities.dxmtAvailable
        case .dxvk:
            return request.capabilities.dxvkAvailable
        case .wined3d:
            return true
        }
    }

}
