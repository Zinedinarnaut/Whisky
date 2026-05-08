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
