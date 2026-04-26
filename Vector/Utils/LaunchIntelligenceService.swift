//
//  LaunchIntelligenceService.swift
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
import VectorKit

#if canImport(FoundationModels)
import FoundationModels
#endif

struct LaunchIntelligenceRecommendation: Sendable {
    let backend: GraphicsBackendMode
    let fallbackBackend: GraphicsBackendMode?
    let confidence: Double
    let reason: String
    let sourceRuleID: String?
}

actor LaunchIntelligenceService {
    static let shared = LaunchIntelligenceService()

    func recommendBackend(
        for bottle: Bottle,
        rules: [DispatchPatchRule],
        diagnostics: [String] = [],
        preferAppleIntelligence: Bool = true
    ) async -> LaunchIntelligenceRecommendation {
        if let matchedRule = matchedRule(for: bottle, rules: rules),
           let backend = matchedRule.graphicsBackend {
            let summary = await summarizeReason(
                base: "VecPatch recommends \(backend.rawValue.uppercased()) for this launch.",
                diagnostics: diagnostics,
                preferAppleIntelligence: preferAppleIntelligence
            )
            return LaunchIntelligenceRecommendation(
                backend: backend,
                fallbackBackend: matchedRule.fallbackGraphicsBackend,
                confidence: 0.92,
                reason: summary,
                sourceRuleID: matchedRule.id
            )
        }

        if let heuristic = heuristicRecommendation(diagnostics: diagnostics) {
            return heuristic
        }

        return LaunchIntelligenceRecommendation(
            backend: bottle.settings.graphicsBackendMode,
            fallbackBackend: nil,
            confidence: 0.55,
            reason: "No high-confidence override detected. Keeping the current bottle backend.",
            sourceRuleID: nil
        )
    }

    private func matchedRule(for bottle: Bottle, rules: [DispatchPatchRule]) -> DispatchPatchRule? {
        let activeSteamAppID = bottle.settings.activeSteamAppID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !activeSteamAppID.isEmpty {
            let appIDMatch = rules.first { rule in
                !rule.steamAppID.isEmpty && rule.steamAppID == activeSteamAppID && rule.graphicsBackend != nil
            }
            if let appIDMatch {
                return appIDMatch
            }
        }

        return rules.first { $0.graphicsBackend != nil }
    }

    private func heuristicRecommendation(diagnostics: [String]) -> LaunchIntelligenceRecommendation? {
        let normalizedDiagnostics = diagnostics.joined(separator: "\n").lowercased()
        if normalizedDiagnostics.contains("directx 12 is not supported") {
            return LaunchIntelligenceRecommendation(
                backend: .dxvk,
                fallbackBackend: .d3dMetal,
                confidence: 0.84,
                reason: "Detected DX12 capability failure. Switching to DXVK D3D11 path is recommended.",
                sourceRuleID: nil
            )
        }

        if normalizedDiagnostics.contains("d3d11-compatible gpu") {
            return LaunchIntelligenceRecommendation(
                backend: .d3dMetal,
                fallbackBackend: .dxvk,
                confidence: 0.76,
                reason: "Detected D3D11 feature-level failure. Prefer D3DMetal with DXVK fallback.",
                sourceRuleID: nil
            )
        }

        return nil
    }

    private func summarizeReason(
        base: String,
        diagnostics: [String],
        preferAppleIntelligence: Bool
    ) async -> String {
        guard preferAppleIntelligence else {
            return base
        }

        #if canImport(FoundationModels)
        if #available(macOS 15.0, *) {
            let prompt = """
            Rewrite this launch recommendation in one concise sentence.

            Recommendation: \(base)
            Diagnostics: \(diagnostics.prefix(5).joined(separator: " | "))
            """
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    return text
                }
            } catch {
                return "\(base) Apple Intelligence unavailable: \(error.localizedDescription)."
            }
        }
        #endif

        return base
    }
}
