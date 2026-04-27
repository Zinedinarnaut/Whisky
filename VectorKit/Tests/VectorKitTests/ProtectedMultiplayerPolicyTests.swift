//
//  ProtectedMultiplayerPolicyTests.swift
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
import CryptoKit
@testable import VectorKit

final class ProtectedMultiplayerPolicyTests: XCTestCase {
    func testArcRaidersSteamAppIDResolvesToHardLockdown() throws {
        let bottle = try makeBottle()
        bottle.settings.activeSteamAppID = VectorProtectedTitlePolicyEngine.arcRaiders.steamAppID

        let assessment = try XCTUnwrap(VectorProtectedTitlePolicyEngine.protectedAssessment(for: bottle))
        let title = try XCTUnwrap(assessment.matchedTitle)

        XCTAssertEqual(title.id, "arc-raiders")
        XCTAssertEqual(assessment.trustClassification, .blockedAntiCheat)
        XCTAssertEqual(assessment.localLaunchDisposition, .block)
        XCTAssertTrue(assessment.shouldBlockLocalLaunch)
        XCTAssertFalse(title.policy.allowMemoryAccess)
        XCTAssertFalse(title.policy.allowTrainerLaunch)
        XCTAssertFalse(title.policy.allowLocalOverrides)
        XCTAssertFalse(title.policy.allowUnsignedRules)
        XCTAssertFalse(title.policy.allowCustomLaunchMutations)
    }

    func testEasyAntiCheatArtifactBlocksLocalLaunch() throws {
        let bottle = try makeBottle()
        let assessment = VectorProtectedTitlePolicyEngine.assessLaunch(
            programURL: URL(fileURLWithPath: "/Games/Example/game.exe"),
            bottle: bottle,
            activeSteamAppID: "",
            detectedArtifacts: ["/Games/Example/EasyAntiCheat/start_protected_game.exe"]
        )

        XCTAssertEqual(assessment.trustClassification, .blockedAntiCheat)
        XCTAssertEqual(assessment.matchedTitle?.id, "generic-protected-anticheat")
        XCTAssertTrue(assessment.shouldBlockLocalLaunch)
        XCTAssertEqual(assessment.detectedArtifacts.count, 1)
    }

    func testProtectedTitlesRejectLocalOverridesAndMutatingRules() throws {
        let bottle = try makeBottle()
        bottle.settings.activeSteamAppID = VectorProtectedTitlePolicyEngine.arcRaiders.steamAppID

        let localOverride = DispatchPatchRule(
            name: "ARC local override",
            executableMatch: "start_protected_game.exe",
            source: .local,
            trustClass: .blockedAntiCheat,
            riskLevel: .blocked,
            protectedTitlePolicy: .hardLockdown,
            officialSupportRequired: true,
            studioApproved: true
        )
        XCTAssertFalse(VectorProtectedTitlePolicyEngine.ruleAllowed(localOverride, in: bottle))

        let mutatingRemoteRule = DispatchPatchRule(
            name: "ARC unsafe remote mutation",
            executableMatch: "start_protected_game.exe",
            arguments: "-unsafe",
            source: .remote,
            trustClass: .blockedAntiCheat,
            riskLevel: .blocked,
            protectedTitlePolicy: .hardLockdown,
            officialSupportRequired: true,
            studioApproved: true
        )
        XCTAssertFalse(VectorProtectedTitlePolicyEngine.ruleAllowed(mutatingRemoteRule, in: bottle))

        let unsignedBlockRule = DispatchPatchRule(
            name: "ARC unsigned block metadata",
            executableMatch: "start_protected_game.exe",
            source: .remote,
            trustClass: .blockedAntiCheat,
            riskLevel: .blocked,
            protectedTitlePolicy: .hardLockdown,
            officialSupportRequired: true,
            studioApproved: true
        )
        XCTAssertFalse(VectorProtectedTitlePolicyEngine.ruleAllowed(unsignedBlockRule, in: bottle))
    }

    func testBattleEyeArtifactBlocksLocalLaunch() throws {
        let bottle = try makeBottle()
        let assessment = VectorProtectedTitlePolicyEngine.assessLaunch(
            programURL: URL(fileURLWithPath: "/Games/Example/game.exe"),
            bottle: bottle,
            activeSteamAppID: "",
            detectedArtifacts: ["/Games/Example/BattlEye/BEService.exe"]
        )

        XCTAssertEqual(assessment.trustClassification, .blockedAntiCheat)
        XCTAssertEqual(assessment.matchedTitle?.id, "generic-protected-anticheat")
        XCTAssertTrue(assessment.shouldBlockLocalLaunch)
    }

    func testProtectedSignedMetadataRuleIsAllowedWhenSignatureIsValid() throws {
        let bottle = try makeBottle()
        bottle.settings.activeSteamAppID = VectorProtectedTitlePolicyEngine.arcRaiders.steamAppID
        let privateKey = Curve25519.Signing.PrivateKey()
        UserDefaults.standard.set(
            privateKey.publicKey.rawRepresentation.base64EncodedString(),
            forKey: "VecPatchPublicKeyBase64"
        )
        defer {
            UserDefaults.standard.removeObject(forKey: "VecPatchPublicKeyBase64")
        }

        var rule = DispatchPatchRule(
            name: "ARC signed block metadata",
            executableMatch: "start_protected_game.exe",
            source: .remote,
            trustClass: .blockedAntiCheat,
            riskLevel: .blocked,
            protectedTitlePolicy: .hardLockdown,
            officialSupportRequired: true,
            studioApproved: true
        )
        let payload = try XCTUnwrap(DispatchPatchSignatureVerifier.canonicalPayloadData(for: rule))
        rule.signature = "ed25519:\(try privateKey.signature(for: payload).base64EncodedString())"

        XCTAssertTrue(DispatchPatchSignatureVerifier.isRuleSignatureValid(rule))
        XCTAssertTrue(VectorProtectedTitlePolicyEngine.ruleAllowed(rule, in: bottle))
    }

    func testDispatchPayloadDecodesSnakeCaseAcronymFields() throws {
        let data = Data("""
        {
          "version": 1,
          "generated_at": "2026-04-27T00:00:00Z",
          "rules": [
            {
              "name": "ARC blocked metadata",
              "steam_app_id": "2767030",
              "protected_title_policy": {
                "allow_memory_access": false,
                "allowed_dll_overrides": [],
                "local_launch_disposition": "block"
              },
              "trust_class": "blockedAntiCheat",
              "risk_level": "blocked"
            }
          ]
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let envelope = try decoder.decode(DispatchPatchEnvelope.self, from: data)
        let rule = try XCTUnwrap(envelope.rules.first)

        XCTAssertEqual(rule.steamAppID, "2767030")
        XCTAssertEqual(rule.protectedTitlePolicy?.localLaunchDisposition, .block)
        XCTAssertEqual(rule.trustClass, .blockedAntiCheat)
        XCTAssertEqual(rule.riskLevel, .blocked)

        let signalData = Data("""
        {
          "version": 1,
          "generated_at": "2026-04-27T00:00:00Z",
          "signals": [
            {
              "id": "minecraft-dungeons-auth",
              "steam_app_id": "1672970",
              "fix_ids": ["repairLauncherDependencies", "reapplyVecPatch"]
            }
          ]
        }
        """.utf8)
        let signalEnvelope = try decoder.decode(DispatchDoctorSignalsEnvelope.self, from: signalData)
        let signal = try XCTUnwrap(signalEnvelope.signals.first)

        XCTAssertEqual(signal.steamAppID, "1672970")
        XCTAssertEqual(signal.fixIDs, ["repairLauncherDependencies", "reapplyVecPatch"])
    }

    private func makeBottle() throws -> Bottle {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "VectorProtectedPolicyTests-")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let bottle = Bottle(bottleUrl: url, inFlight: true, isAvailable: true)
        bottle.settings.name = "Protected Policy Test"
        return bottle
    }
}
