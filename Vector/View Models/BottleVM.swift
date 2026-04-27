//
//  BottleVM.swift
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
import SemanticVersion
import VectorKit

struct BottleCreationOptions {
    var gamingModeEnabled: Bool
    var windowsFidelityModeEnabled: Bool
    var autoInstallLaunchers: Bool
    var autoPinLaunchers: Bool
    var autoApplyKnownGamePatches: Bool
    var enablePatchDispatch: Bool
    var patchDispatchEndpointURL: String
    var installerCompatibilityMode: Bool
    var preferredRuntimeDLLSyncMode: RuntimeDLLSyncMode
    var preferCompatibilityRuntime: Bool

    static let standard = BottleCreationOptions(
        gamingModeEnabled: false,
        windowsFidelityModeEnabled: false,
        autoInstallLaunchers: false,
        autoPinLaunchers: false,
        autoApplyKnownGamePatches: false,
        enablePatchDispatch: false,
        patchDispatchEndpointURL: BottleDispatchConfig.defaultEndpointURL,
        installerCompatibilityMode: false,
        preferredRuntimeDLLSyncMode: .verifyOnly,
        preferCompatibilityRuntime: false
    )

    static let gaming = BottleCreationOptions(
        gamingModeEnabled: true,
        windowsFidelityModeEnabled: false,
        autoInstallLaunchers: true,
        autoPinLaunchers: true,
        autoApplyKnownGamePatches: true,
        enablePatchDispatch: true,
        patchDispatchEndpointURL: BottleDispatchConfig.defaultEndpointURL,
        installerCompatibilityMode: false,
        preferredRuntimeDLLSyncMode: .verifyOnly,
        preferCompatibilityRuntime: false
    )

    static let windowsFidelity = BottleCreationOptions(
        gamingModeEnabled: false,
        windowsFidelityModeEnabled: true,
        autoInstallLaunchers: false,
        autoPinLaunchers: false,
        autoApplyKnownGamePatches: false,
        enablePatchDispatch: false,
        patchDispatchEndpointURL: BottleDispatchConfig.defaultEndpointURL,
        installerCompatibilityMode: true,
        preferredRuntimeDLLSyncMode: .verifyAndRepair,
        preferCompatibilityRuntime: true
    )
}

// swiftlint:disable:next todo
// TODO: Don't use unchecked!
final class BottleVM: ObservableObject, @unchecked Sendable {
    @MainActor static let shared = BottleVM()

    var bottlesList = BottleData()
    @Published var bottles: [Bottle] = []
    @MainActor private var isLoadingBottles = false
    @MainActor private var pendingReload = false

    @MainActor
    func loadBottles() {
        if isLoadingBottles {
            pendingReload = true
            return
        }

        isLoadingBottles = true
        let bottleData = bottlesList

        Task.detached(priority: .userInitiated) {
            var localBottleData = bottleData
            let loadedBottles = localBottleData.loadBottles()

            await MainActor.run {
                self.bottles = loadedBottles
                self.isLoadingBottles = false

                if self.pendingReload {
                    self.pendingReload = false
                    self.loadBottles()
                }
            }
        }
    }

    func countActive() -> Int {
        return bottles.filter { $0.isAvailable == true }.count
    }

    func createNewBottle(
        bottleName: String,
        winVersion: WinVersion,
        bottleURL: URL,
        options: BottleCreationOptions = .standard
    ) -> URL {
        let newBottleDir = bottleURL.appending(path: UUID().uuidString)
        BottleStorageAccess.saveBookmark(for: bottleURL)
        BottleStorageAccess.startAccessingIfNeeded(for: bottleURL)

        Task.detached {
            var bottleId: Bottle?
            do {
                try FileManager.default.createDirectory(atPath: newBottleDir.path(percentEncoded: false),
                                                        withIntermediateDirectories: true)
                let bottle = Bottle(bottleUrl: newBottleDir, inFlight: true)
                bottleId = bottle

                await MainActor.run {
                    self.bottles.append(bottle)
                }

                bottle.settings.windowsVersion = winVersion
                bottle.settings.name = bottleName
                try await Wine.changeWinVersion(bottle: bottle, win: winVersion)
                let wineVer = try await Wine.wineVersion()
                bottle.settings.wineVersion = SemanticVersion(wineVer) ?? SemanticVersion(0, 0, 0)
                await self.applyCreationOptions(options, to: bottle)
                // Add record
                await MainActor.run {
                    self.bottlesList.paths.append(newBottleDir)
                    self.loadBottles()
                }
                VectorNotifications.notifyBottleCreated(bottleName)
            } catch {
                print("Failed to create new bottle: \(error)")
                VectorNotifications.notifyBottleCreationFailed(
                    bottleName,
                    reason: error.localizedDescription
                )
                if let bottle = bottleId {
                    await MainActor.run {
                        if let index = self.bottles.firstIndex(of: bottle) {
                            self.bottles.remove(at: index)
                        }
                    }
                }
            }
        }
        return newBottleDir
    }

    private func applyCreationOptions(_ options: BottleCreationOptions, to bottle: Bottle) async {
        if options.windowsFidelityModeEnabled {
            bottle.settings.runtimeDLLSyncMode = options.preferredRuntimeDLLSyncMode
            bottle.settings.installerCompatibilityMode = options.installerCompatibilityMode
            bottle.settings.graphicsBackendMode = .auto
            bottle.settings.dxvk = true
            bottle.settings.dxvkAsync = true
            bottle.settings.shaderCacheEnabled = true
            bottle.settings.forceD3D11Compatibility = false
            bottle.settings.dllOverridesPolicy = .auto
            bottle.settings.runtimeSelection = options.preferCompatibilityRuntime
                && VectorWineInstaller.steamCompatibilityWineBinary() != nil ? .compatibility : .auto
        }

        guard options.gamingModeEnabled else {
            return
        }

        BottleGamingModeManager.applyGamingDefaults(
            to: bottle,
            dispatchEndpointURL: options.patchDispatchEndpointURL
        )
        bottle.settings.gamingAutoInstallLaunchers = options.autoInstallLaunchers
        bottle.settings.gamingAutoPinLaunchers = options.autoPinLaunchers
        bottle.settings.gamingAutoApplyKnownGamePatches = options.autoApplyKnownGamePatches
        bottle.settings.patchDispatchEnabled = options.enablePatchDispatch

        if options.autoApplyKnownGamePatches {
            BottleGamingModeManager.ensureKnownGameProfiles(in: bottle)
        }

        if options.enablePatchDispatch {
            await BottleGamingModeManager.syncDispatchProfiles(for: bottle, forceRefresh: true)
        }

        await BottleGamingModeManager.installGamingLaunchersIfEnabled(for: bottle)
        bottle.updateInstalledPrograms()
    }
}
