//
//  Wine+DXVK.swift
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

extension Wine {
    private static let dxvkNativeOverrideTokens = [
        "dxgi",
        "d3d11=n,b",
        "d3d10core=n,b",
        "d3d9=n,b"
    ]
    private static let dxvkDisableEnvironmentKey = "VECTOR_FORCE_DISABLE_DXVK"
    private static let effectiveBackendEnvironmentKey = "VECTOR_EFFECTIVE_GRAPHICS_BACKEND"
    private static let effectiveFallbackBackendEnvironmentKey = "VECTOR_EFFECTIVE_GRAPHICS_BACKEND_FALLBACK"

    static func shouldEnableDXVK(for bottle: Bottle, environment: [String: String]) -> Bool {
        if let forceDisableRawValue = environment[dxvkDisableEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           ["1", "true", "yes", "on"].contains(forceDisableRawValue) {
            return false
        }

        if let resolvedBackend = resolvedBackendMode(for: bottle, environment: environment) {
            switch resolvedBackend {
            case .auto:
                break
            case .dxvk:
                return true
            case .dxmt, .wined3d, .d3dMetal:
                return false
            }
        }

        if bottle.settings.dxvk
            || bottle.settings.forceD3D11Compatibility
            || bottle.settings.graphicsBackendMode == .dxvk {
            return true
        }

        guard let overrides = environment["WINEDLLOVERRIDES"]?.lowercased(),
              !overrides.isEmpty else {
            return false
        }

        return dxvkNativeOverrideTokens.contains(where: overrides.contains)
    }

    static func shouldFallbackToDXVK(environment: [String: String]) -> Bool {
        resolvedFallbackBackendMode(environment: environment) == .dxvk
    }

    static func resolvedBackendMode(
        for bottle: Bottle,
        environment: [String: String]
    ) -> GraphicsBackendMode? {
        if let environmentBackend = backendMode(
            from: environment[effectiveBackendEnvironmentKey]
        ), environmentBackend != .auto {
            return environmentBackend
        }

        if bottle.settings.graphicsBackendMode != .auto {
            return bottle.settings.graphicsBackendMode
        }

        return nil
    }

    static func resolvedFallbackBackendMode(
        environment: [String: String]
    ) -> GraphicsBackendMode? {
        backendMode(from: environment[effectiveFallbackBackendEnvironmentKey])
    }

    private static func backendMode(from rawValue: String?) -> GraphicsBackendMode? {
        guard let rawValue else {
            return nil
        }

        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else {
            return nil
        }

        return GraphicsBackendMode(rawValue: normalized)
    }
}
