//
//  VectorDoctorDependencyRepairTests.swift
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

final class VectorDoctorDependencyRepairTests: XCTestCase {
    func testMicrosoftAuthLoopFlagsRepairableAndManualXboxSignals() throws {
        let bottle = try makeBottle()
        let signals = VectorDoctor.repairSignals(
            for: bottle,
            runtime: healthyRuntime(),
            dispatch: cleanDispatch(),
            logs: [
                log(
                    """
                    WebView2 navigation reached login.live.com and sisu.xboxlive.com.
                    Microsoft will never ask you to copy or share this URL.
                    """
                )
            ]
        )

        XCTAssertTrue(signals.needsWebViewAuthRepair)
        XCTAssertTrue(signals.needsLauncherDependencyRepair)
        XCTAssertTrue(signals.needsXboxManualFallback)
        XCTAssertTrue(signals.launcherDetails.contains("manual fallback"))
    }

    func testSteamCEFSignalDoesNotPretendLauncherDependenciesCanFixIt() throws {
        let bottle = try makeBottle()
        let signals = VectorDoctor.repairSignals(
            for: bottle,
            runtime: healthyRuntime(),
            dispatch: cleanDispatch(),
            logs: [
                log("steamwebhelper.exe crashed while loading CEF htmlcache")
            ]
        )
        let fixes = VectorDoctor.recommendedFixes(from: signals, protectedAssessment: nil)

        XCTAssertTrue(signals.needsSteamWebHelperFallback)
        XCTAssertFalse(signals.needsLauncherDependencyRepair)
        XCTAssertFalse(fixes.contains { $0.id == .repairLauncherDependencies })
    }

    func testDXVKExpectedPayloadCreatesGraphicsPayloadSignal() throws {
        let bottle = try makeBottle()
        bottle.settings.graphicsBackendMode = .dxvk

        let signals = VectorDoctor.repairSignals(
            for: bottle,
            runtime: healthyRuntime(),
            dispatch: cleanDispatch(),
            logs: []
        )

        XCTAssertTrue(signals.needsGraphicsPayloadRepair)
        XCTAssertTrue(signals.graphicsDetails.contains("DXVK"))
    }

    func testRuntimeDependencyLogFlagsLauncherRepair() throws {
        let bottle = try makeBottle()
        let signals = VectorDoctor.repairSignals(
            for: bottle,
            runtime: healthyRuntime(),
            dispatch: cleanDispatch(),
            logs: [
                log("err:module:import_dll Library vcruntime140_1.dll not found")
            ]
        )

        XCTAssertTrue(signals.needsRuntimeDependencyRepair)
        XCTAssertTrue(signals.needsLauncherDependencyRepair)
        XCTAssertTrue(signals.launcherDetails.contains("Visual C++"))
    }

    private func makeBottle() throws -> Bottle {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "VectorDoctorDependencyRepairTests-")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(
            at: url.appending(path: "drive_c").appending(path: "windows").appending(path: "system32"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: url.appending(path: "drive_c").appending(path: "windows").appending(path: "syswow64"),
            withIntermediateDirectories: true
        )
        let bottle = Bottle(bottleUrl: url, inFlight: true, isAvailable: true)
        bottle.settings.name = "Vector Doctor Dependency Repair Test"
        return bottle
    }

    private func healthyRuntime() -> VectorDoctorRuntimeSnapshot {
        VectorDoctorRuntimeSnapshot(
            vectorRuntimeInstalled: true,
            installedVectorWineVersion: "test",
            installedWineVersion: "test",
            bundledWinePath: "/tmp/wine64",
            bundledWinePresent: true,
            bundledWineserverPath: "/tmp/wineserver",
            bundledWineserverPresent: true,
            compatibilityWinePath: "",
            compatibilityWinePresent: false,
            compatibilityWineserverPath: "",
            compatibilityWineserverPresent: false,
            installHealth: [:]
        )
    }

    private func cleanDispatch() -> VectorDoctorDispatchSnapshot {
        VectorDoctorDispatchSnapshot(
            enabled: true,
            endpointURL: "https://example.invalid/vector.json",
            channel: "stable",
            requireSignedRules: true,
            remoteVersion: 1,
            remoteRuleCount: 0,
            effectiveRuleCount: 0,
            updateAvailable: false,
            effectiveRulesDigest: "",
            recommendedBackend: "",
            fallbackBackend: "",
            message: "Patch dispatch is current."
        )
    }

    private func log(_ tail: String) -> VectorDoctorLogSnippet {
        VectorDoctorLogSnippet(
            name: "test.log",
            path: UUID().uuidString,
            createdAt: "2026-05-08T00:00:00Z",
            tail: tail
        )
    }
}
