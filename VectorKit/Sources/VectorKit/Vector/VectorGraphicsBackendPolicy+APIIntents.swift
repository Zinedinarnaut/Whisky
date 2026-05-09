//
//  VectorGraphicsBackendPolicy+APIIntents.swift
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

extension VectorGraphicsBackendPolicy {
    static func apiIntents(from rules: [DispatchPatchRule]) -> Set<VectorGraphicsAPIIntent> {
        rules.reduce(into: Set<VectorGraphicsAPIIntent>()) { result, rule in
            result.formUnion(apiIntents(from: rule.arguments))
            result.formUnion(apiIntents(from: rule.executableMatch))
            result.formUnion(apiIntents(from: rule.environment.values.joined(separator: " ")))
            if rule.graphicsBackend == .d3dMetal {
                result.insert(.d3d12)
            }
        }
    }

    static func apiIntents(from text: String) -> Set<VectorGraphicsAPIIntent> {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else {
            return []
        }

        var result: Set<VectorGraphicsAPIIntent> = []
        if normalized.contains("dx12")
            || normalized.contains("d3d12")
            || normalized.contains("directx 12") {
            result.insert(.d3d12)
        }
        if normalized.contains("dx11")
            || normalized.contains("d3d11")
            || normalized.contains("directx 11")
            || normalized.contains("unity") {
            result.insert(.d3d11)
        }
        if normalized.contains("d3d10") || normalized.contains("dx10") {
            result.insert(.d3d10)
        }
        if normalized.contains("d3d9") || normalized.contains("dx9") {
            result.insert(.d3d9)
        }
        return result
    }
}
