//
//  VectorGraphicsBackendPolicyTests.swift
//  VectorKitTests
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

import XCTest
@testable import VectorKit

final class VectorGraphicsBackendPolicyTests: XCTestCase {
    private let allBackendsAvailable = VectorGraphicsBackendCapabilities(
        d3dMetalAvailable: true,
        dxmtAvailable: true,
        dxvkAvailable: true
    )

    func testD3D12DispatchPrefersD3DMetalWhenAvailable() throws {
        let rule = DispatchPatchRule(
            id: "dx12-rule",
            name: "D3D12 Game",
            steamAppID: "2483190",
            arguments: "-dx12",
            priority: 10,
            graphicsBackend: .dxvk,
            fallbackGraphicsBackend: .wined3d
        )

        let recommendation = try XCTUnwrap(VectorGraphicsBackendPolicy.recommendation(
            for: VectorBackendRecommendationRequest(
                configuredBackend: .auto,
                activeSteamAppID: "2483190",
                dispatchRules: [rule],
                capabilities: allBackendsAvailable
            )
        ))

        XCTAssertEqual(recommendation.primary, .d3dMetal)
        XCTAssertEqual(recommendation.fallback, .wined3d)
        XCTAssertEqual(recommendation.sourceRuleID, "dx12-rule")
    }

    func testUnityD3D11DispatchUsesBackendRulePriority() throws {
        let dxmtRule = DispatchPatchRule(
            id: "unity-dxmt",
            name: "Unity DXMT",
            executableMatch: "unitygame.exe",
            steamAppID: "123",
            arguments: "-force-d3d11",
            priority: 5,
            graphicsBackend: .dxmt,
            fallbackGraphicsBackend: .dxvk
        )
        let dxvkRule = DispatchPatchRule(
            id: "unity-dxvk",
            name: "Unity DXVK",
            executableMatch: "unitygame.exe",
            steamAppID: "123",
            arguments: "-force-d3d11",
            priority: 20,
            graphicsBackend: .dxvk,
            fallbackGraphicsBackend: .wined3d
        )

        let recommendation = try XCTUnwrap(VectorGraphicsBackendPolicy.recommendation(
            for: VectorBackendRecommendationRequest(
                configuredBackend: .auto,
                activeSteamAppID: "123",
                executableName: "UnityGame.exe",
                dispatchRules: [dxvkRule, dxmtRule],
                capabilities: allBackendsAvailable
            )
        ))

        XCTAssertEqual(recommendation.primary, .dxmt)
        XCTAssertEqual(recommendation.fallback, .dxvk)
        XCTAssertEqual(recommendation.sourceRuleID, "unity-dxmt")
    }

    func testUnityD3D11DispatchCanPreferDXVKByRulePriority() throws {
        let dxvkRule = DispatchPatchRule(
            id: "unity-dxvk",
            name: "Unity DXVK",
            steamAppID: "123",
            arguments: "-force-d3d11",
            priority: 1,
            graphicsBackend: .dxvk,
            fallbackGraphicsBackend: .wined3d
        )
        let dxmtRule = DispatchPatchRule(
            id: "unity-dxmt",
            name: "Unity DXMT",
            steamAppID: "123",
            arguments: "-force-d3d11",
            priority: 5,
            graphicsBackend: .dxmt,
            fallbackGraphicsBackend: .dxvk
        )

        let recommendation = try XCTUnwrap(VectorGraphicsBackendPolicy.recommendation(
            for: VectorBackendRecommendationRequest(
                configuredBackend: .auto,
                activeSteamAppID: "123",
                dispatchRules: [dxmtRule, dxvkRule],
                capabilities: allBackendsAvailable
            )
        ))

        XCTAssertEqual(recommendation.primary, .dxvk)
        XCTAssertEqual(recommendation.fallback, .wined3d)
        XCTAssertEqual(recommendation.sourceRuleID, "unity-dxvk")
    }

    func testExplicitUserBackendIsPreservedWithoutFailureSignals() throws {
        let rule = DispatchPatchRule(
            id: "profile-rule",
            name: "Profile Rule",
            steamAppID: "42",
            priority: 1,
            graphicsBackend: .dxvk,
            fallbackGraphicsBackend: .wined3d
        )

        let recommendation = try XCTUnwrap(VectorGraphicsBackendPolicy.recommendation(
            for: VectorBackendRecommendationRequest(
                configuredBackend: .wined3d,
                activeSteamAppID: "42",
                dispatchRules: [rule],
                capabilities: allBackendsAvailable
            )
        ))

        XCTAssertEqual(recommendation.primary, .wined3d)
        XCTAssertNil(recommendation.fallback)
        XCTAssertEqual(recommendation.source, .userExplicit)
        XCTAssertFalse(recommendation.shouldOverrideExplicitChoice)
    }

    func testExplicitUserBackendCanBeOverriddenByFailureSignals() throws {
        let recommendation = try XCTUnwrap(VectorGraphicsBackendPolicy.recommendation(
            for: VectorBackendRecommendationRequest(
                configuredBackend: .wined3d,
                capabilities: allBackendsAvailable,
                failureSignals: VectorGraphicsBackendFailureSignals(
                    failedBackends: [.wined3d],
                    launchFailureClasses: [.dxFeatureLevel]
                )
            )
        ))

        XCTAssertEqual(recommendation.primary, .dxvk)
        XCTAssertNil(recommendation.fallback)
        XCTAssertEqual(recommendation.source, .failureRecovery)
        XCTAssertTrue(recommendation.shouldOverrideExplicitChoice)
    }

    func testMultipleDispatchRulesDoNotApplyWithoutLaunchContext() throws {
        let d3d12Rule = DispatchPatchRule(
            id: "unmatched-d3d12",
            name: "Unmatched D3D12 Game",
            steamAppID: "2483190",
            arguments: "-dx12",
            priority: 1,
            graphicsBackend: .d3dMetal,
            fallbackGraphicsBackend: .dxvk
        )
        let launcherRule = DispatchPatchRule(
            id: "unmatched-launcher",
            name: "Unmatched Launcher",
            executableMatch: "launcher.exe",
            priority: 2,
            graphicsBackend: .wined3d,
            fallbackGraphicsBackend: .dxvk
        )

        let recommendation = try XCTUnwrap(VectorGraphicsBackendPolicy.recommendation(
            for: VectorBackendRecommendationRequest(
                configuredBackend: .auto,
                dispatchRules: [d3d12Rule, launcherRule],
                capabilities: allBackendsAvailable
            )
        ))

        XCTAssertEqual(recommendation.primary, .dxvk)
        XCTAssertEqual(recommendation.fallback, .wined3d)
        XCTAssertEqual(recommendation.source, .defaultPolicy)
        XCTAssertNil(recommendation.sourceRuleID)
    }

    func testProtectedTitleBlocksRiskyBackendMutationRecommendation() {
        let riskyRule = DispatchPatchRule(
            id: "protected-risky-rule",
            name: "Protected Risky Rule",
            steamAppID: "1808500",
            priority: 1,
            graphicsBackend: .dxvk,
            fallbackGraphicsBackend: .wined3d,
            trustClass: .blockedAntiCheat,
            riskLevel: .high
        )

        let recommendation = VectorGraphicsBackendPolicy.recommendation(
            for: VectorBackendRecommendationRequest(
                configuredBackend: .auto,
                activeSteamAppID: "1808500",
                dispatchRules: [riskyRule],
                capabilities: allBackendsAvailable,
                protectedTitleBlocksMutations: true
            )
        )

        XCTAssertNil(recommendation)
    }

    func testProtectedTitleRejectsUnsignedStudioBackendMutation() {
        let protectedPolicy = ProtectedTitlePolicy(
            allowMemoryAccess: false,
            allowTrainerLaunch: false,
            allowLocalOverrides: false,
            allowUnsignedRules: true,
            allowDebugTooling: false,
            allowCustomLaunchMutations: true,
            allowedDLLOverrides: [],
            allowedLaunchArguments: ["-safe-mode"],
            localLaunchDisposition: .allow
        )
        let unsignedStudioRule = DispatchPatchRule(
            id: "protected-unsigned-studio-rule",
            name: "Protected Unsigned Studio Rule",
            steamAppID: "1808500",
            priority: 1,
            graphicsBackend: .dxvk,
            fallbackGraphicsBackend: .wined3d,
            trustClass: .protectedMultiplayer,
            riskLevel: .low,
            protectedTitlePolicy: protectedPolicy,
            studioApproved: true
        )

        let recommendation = VectorGraphicsBackendPolicy.recommendation(
            for: VectorBackendRecommendationRequest(
                configuredBackend: .auto,
                activeSteamAppID: "1808500",
                dispatchRules: [unsignedStudioRule],
                capabilities: allBackendsAvailable,
                protectedTitleBlocksMutations: true
            )
        )

        XCTAssertNil(recommendation)
    }
}
