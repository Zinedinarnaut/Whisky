//
//  BottleGamingModeTests.swift
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

// The patch/profile matrix is intentionally broad because it guards idempotence across many games.
// swiftlint:disable:next type_body_length
final class BottleGamingModeTests: XCTestCase {
    private struct ExpectedProfile {
        let name: String
        let executable: String
        let appID: String
        let backend: GraphicsBackendMode
    }

    private static let expectedSprintProfiles = [
        ExpectedProfile(
            name: "Auto: Minecraft Dungeons",
            executable: "dungeons-win64-shipping.exe",
            appID: "1672970",
            backend: .dxvk
        ),
        ExpectedProfile(
            name: "Auto: Content Warning",
            executable: "content warning.exe",
            appID: "2881650",
            backend: .dxvk
        ),
        ExpectedProfile(
            name: "Auto: Parcel Simulator",
            executable: "parcel-win64-shipping.exe",
            appID: "2424010",
            backend: .dxvk
        ),
        ExpectedProfile(
            name: "Auto: High On Life 2",
            executable: "highonlife2-win64-shipping.exe",
            appID: "2069250",
            backend: .dxvk
        ),
        ExpectedProfile(
            name: "Auto: Silent Hill f",
            executable: "silenthillf-win64-shipping.exe",
            appID: "2947440",
            backend: .dxvk
        ),
        ExpectedProfile(
            name: "Auto: Titanfall 2",
            executable: "titanfall2.exe",
            appID: "1237970",
            backend: .dxvk
        ),
        ExpectedProfile(
            name: "Auto: Lethal Company",
            executable: "lethal company.exe",
            appID: "1966720",
            backend: .dxvk
        ),
        ExpectedProfile(
            name: "Auto: Hydroneer",
            executable: "hydroneer-win64-shipping.exe",
            appID: "1106840",
            backend: .dxvk
        ),
        ExpectedProfile(
            name: "Auto: Satisfactory",
            executable: "factorygamesteam.exe",
            appID: "526870",
            backend: .dxvk
        ),
        ExpectedProfile(
            name: "Auto: Escape the Backrooms",
            executable: "escapethebackrooms.exe",
            appID: "1943950",
            backend: .dxvk
        ),
        ExpectedProfile(
            name: "Auto: Forza Horizon 6",
            executable: "forzahorizon6.exe",
            appID: "2483190",
            backend: .d3dMetal
        )
    ]

    func testKnownGameProfilesCoverSprintTitlesAndAreIdempotent() throws {
        let bottle = try makeBottle()

        BottleGamingModeManager.ensureKnownGameProfiles(in: bottle)
        let firstProfiles = bottle.settings.gameProfiles
        let firstIDsByName = Dictionary(uniqueKeysWithValues: firstProfiles.map { ($0.name, $0.id) })

        for expected in Self.expectedSprintProfiles {
            let profile = try XCTUnwrap(
                firstProfiles.first { $0.name == expected.name },
                "Missing managed profile \(expected.name)"
            )
            XCTAssertEqual(profile.executableMatch, expected.executable)
            XCTAssertEqual(profile.steamAppID, expected.appID)
            XCTAssertEqual(profile.graphicsBackendOverride, expected.backend)
            XCTAssertEqual(profile.environment["DXVK_ENABLE_NVAPI"], "0")
            XCTAssertFalse(profile.environment["WINEDLLOVERRIDES", default: ""].isEmpty)
        }

        BottleGamingModeManager.ensureKnownGameProfiles(in: bottle)
        XCTAssertEqual(bottle.settings.gameProfiles.count, firstProfiles.count)

        for expected in Self.expectedSprintProfiles {
            let profile = try XCTUnwrap(bottle.settings.gameProfiles.first { $0.name == expected.name })
            XCTAssertEqual(profile.id, firstIDsByName[expected.name])
        }
    }

    func testKnownGameProfilesSkipProtectedAntiCheatBottle() throws {
        let bottle = try makeBottle()
        let antiCheatDirectory = bottle.url
            .appending(path: "drive_c")
            .appending(path: "Games")
            .appending(path: "Protected")
            .appending(path: "EasyAntiCheat")
        try FileManager.default.createDirectory(at: antiCheatDirectory, withIntermediateDirectories: true)
        XCTAssertTrue(FileManager.default.createFile(
            atPath: antiCheatDirectory.appending(path: "start_protected_game.exe").path(percentEncoded: false),
            contents: Data()
        ))

        BottleGamingModeManager.ensureKnownGameProfiles(in: bottle)

        XCTAssertTrue(bottle.settings.gameProfiles.isEmpty)
    }

    func testKnownGameProfilesDoNotOverwriteUserProfilesAndCollapseManagedDuplicates() throws {
        let bottle = try makeBottle()
        let userProfile = BottleGameProfile(
            name: "My Minecraft Dungeons",
            executableMatch: "dungeons-win64-shipping.exe",
            steamAppID: "1672970",
            arguments: "-user-choice",
            environment: ["USER_PROFILE": "1"]
        )
        let staleManagedProfile = BottleGameProfile(
            name: "Auto: Minecraft Dungeons",
            executableMatch: "dungeons-win64-shipping.exe",
            steamAppID: "1672970",
            arguments: "-old",
            environment: ["OLD_PROFILE": "1"]
        )
        let duplicateManagedProfile = BottleGameProfile(
            name: "Auto: Minecraft Dungeons",
            executableMatch: "dungeons-win64-shipping.exe",
            steamAppID: "1672970",
            arguments: "-older",
            environment: ["OLDER_PROFILE": "1"]
        )
        bottle.settings.gameProfiles = [userProfile, staleManagedProfile, duplicateManagedProfile]

        BottleGamingModeManager.ensureKnownGameProfiles(in: bottle)

        let userProfiles = bottle.settings.gameProfiles.filter { $0.name == userProfile.name }
        XCTAssertEqual(userProfiles.count, 1)
        XCTAssertEqual(userProfiles.first?.id, userProfile.id)
        XCTAssertEqual(userProfiles.first?.arguments, "-user-choice")
        XCTAssertEqual(userProfiles.first?.environment["USER_PROFILE"], "1")

        let managedProfiles = bottle.settings.gameProfiles.filter { $0.name == "Auto: Minecraft Dungeons" }
        XCTAssertEqual(managedProfiles.count, 1)
        XCTAssertEqual(managedProfiles.first?.id, staleManagedProfile.id)
        XCTAssertEqual(managedProfiles.first?.environment["DXVK_ENABLE_NVAPI"], "0")
        XCTAssertNil(managedProfiles.first?.environment["OLD_PROFILE"])
        XCTAssertNil(managedProfiles.first?.environment["OLDER_PROFILE"])
    }

    func testDispatchRulesDoNotReapplyWhenDigestIsAlreadyApplied() {
        let rule = DispatchPatchRule(
            name: "Dispatch Rule",
            executableMatch: "game.exe",
            arguments: "-safe"
        )

        XCTAssertFalse(BottleGamingModeManager.shouldApplyDispatchRules(
            [rule],
            currentDispatchProfileCount: 1,
            effectiveRulesDigest: " abc123 \n",
            appliedRulesDigest: "abc123"
        ))
        XCTAssertTrue(BottleGamingModeManager.shouldApplyDispatchRules(
            [rule],
            currentDispatchProfileCount: 1,
            effectiveRulesDigest: "def456",
            appliedRulesDigest: "abc123"
        ))
        XCTAssertTrue(BottleGamingModeManager.shouldApplyDispatchRules(
            [],
            currentDispatchProfileCount: 1,
            effectiveRulesDigest: "",
            appliedRulesDigest: "abc123"
        ))
    }

    func testDispatchMergeIsIdempotentByRuleIDAndRespectsExplicitBackend() throws {
        let bottle = try makeBottle()
        bottle.settings.graphicsBackendMode = .wined3d
        let oldDispatchProfile = BottleGameProfile(
            name: "Dispatch: Old Rule Name",
            executableMatch: "game.exe",
            steamAppID: "42",
            arguments: "-old",
            environment: [:],
            graphicsBackendOverride: .dxvk,
            fallbackGraphicsBackend: .wined3d,
            dispatchRuleID: "rule-1"
        )
        bottle.settings.gameProfiles = [oldDispatchProfile]

        let rules = [
            DispatchPatchRule(
                id: "rule-1",
                name: "New Rule Name",
                executableMatch: "game.exe",
                steamAppID: "42",
                arguments: "-new",
                environment: ["PATCHED": "1"],
                priority: 10,
                graphicsBackend: .dxvk,
                fallbackGraphicsBackend: .wined3d
            ),
            DispatchPatchRule(
                id: "rule-1",
                name: "Duplicate Rule Name",
                executableMatch: "duplicate.exe",
                steamAppID: "43",
                arguments: "-duplicate",
                priority: 20,
                graphicsBackend: .d3dMetal,
                fallbackGraphicsBackend: .dxvk
            )
        ]

        BottleGamingModeManager.mergeDispatchRules(rules, into: bottle)
        BottleGamingModeManager.mergeDispatchRules(rules, into: bottle)

        let dispatchProfiles = bottle.settings.gameProfiles.filter {
            $0.name.hasPrefix(BottleGamingModeManager.dispatchProfileNamePrefix)
        }
        XCTAssertEqual(dispatchProfiles.count, 1)

        let profile = try XCTUnwrap(dispatchProfiles.first)
        XCTAssertEqual(profile.id, oldDispatchProfile.id)
        XCTAssertEqual(profile.name, "Dispatch: New Rule Name")
        XCTAssertEqual(profile.arguments, "-new")
        XCTAssertEqual(profile.environment["PATCHED"], "1")
        XCTAssertNil(profile.graphicsBackendOverride)
        XCTAssertNil(profile.fallbackGraphicsBackend)
        XCTAssertEqual(bottle.settings.graphicsBackendMode, .wined3d)
    }

    func testExplicitGraphicsBackendOverridesProfileEnvironmentAndExposesReason() throws {
        let bottle = try makeBottle()
        bottle.settings.graphicsBackendMode = .wined3d
        let program = Program(
            url: bottle.url
                .appending(path: "drive_c")
                .appending(path: "Games")
                .appending(path: "Game")
                .appending(path: "game.exe"),
            bottle: bottle
        )
        var environment = [
            "VECTOR_EFFECTIVE_GRAPHICS_BACKEND": "d3dMetal",
            "VECTOR_EFFECTIVE_GRAPHICS_BACKEND_FALLBACK": "dxvk",
            "VECTOR_EFFECTIVE_GRAPHICS_BACKEND_REASON": "Profile requested D3DMetal.",
            "VECTOR_EFFECTIVE_GRAPHICS_BACKEND_FALLBACK_REASON": "Profile fallback."
        ]

        program.applySmartGraphicsBackendSelection(to: &environment)

        XCTAssertEqual(environment["VECTOR_EFFECTIVE_GRAPHICS_BACKEND"], "wined3d")
        XCTAssertEqual(
            environment["VECTOR_EFFECTIVE_GRAPHICS_BACKEND_REASON"],
            "Explicit bottle graphics backend selection."
        )
        XCTAssertNil(environment["VECTOR_EFFECTIVE_GRAPHICS_BACKEND_FALLBACK"])
        XCTAssertNil(environment["VECTOR_EFFECTIVE_GRAPHICS_BACKEND_FALLBACK_REASON"])
        XCTAssertEqual(environment["VECTOR_FORCE_DISABLE_DXVK"], "1")
        XCTAssertEqual(environment["WINEDLLOVERRIDES"], "dxgi,d3d9,d3d10core,d3d11=b")
    }

    func testAutomaticBackendSelectionPreservesD3DMetalHintAndFallbackReason() throws {
        let bottle = try makeBottle()
        bottle.settings.graphicsBackendMode = .auto
        let program = Program(
            url: bottle.url
                .appending(path: "drive_c")
                .appending(path: "Games")
                .appending(path: "Game")
                .appending(path: "game.exe"),
            bottle: bottle
        )
        var environment = [
            "VECTOR_EFFECTIVE_GRAPHICS_BACKEND": "d3dMetal",
            "VECTOR_EFFECTIVE_GRAPHICS_BACKEND_FALLBACK": "dxvk",
            "VECTOR_EFFECTIVE_GRAPHICS_BACKEND_REASON": "Profile requested D3DMetal.",
            "VECTOR_EFFECTIVE_GRAPHICS_BACKEND_FALLBACK_REASON": "Profile fallback."
        ]

        program.applySmartGraphicsBackendSelection(to: &environment)

        XCTAssertEqual(environment["VECTOR_EFFECTIVE_GRAPHICS_BACKEND"], "d3dMetal")
        XCTAssertEqual(environment["VECTOR_EFFECTIVE_GRAPHICS_BACKEND_FALLBACK"], "dxvk")
        XCTAssertEqual(
            environment["VECTOR_EFFECTIVE_GRAPHICS_BACKEND_REASON"],
            "Profile requested D3DMetal."
        )
        XCTAssertEqual(
            environment["VECTOR_EFFECTIVE_GRAPHICS_BACKEND_FALLBACK_REASON"],
            "Profile fallback."
        )
        XCTAssertEqual(environment["VECTOR_FORCE_DISABLE_DXVK"], "1")
    }

    private func makeBottle() throws -> Bottle {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "VectorGamingModeTests-")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let bottle = Bottle(bottleUrl: url, inFlight: true, isAvailable: true)
        bottle.settings.name = "Gaming Mode Test"
        return bottle
    }
}
