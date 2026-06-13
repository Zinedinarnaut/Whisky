//
//  CompatibilityDatabaseView.swift
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

import SwiftUI
import VectorKit

// swiftlint:disable file_length

private enum CompatibilityRatingFilter: String, CaseIterable, Identifiable {
    case all
    case playable
    case needsTweaks
    case boots
    case broken
    case unsupported

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .playable:
            return "Playable"
        case .needsTweaks:
            return "Needs Tweaks"
        case .boots:
            return "Boots"
        case .broken:
            return "Broken"
        case .unsupported:
            return "Unsupported"
        }
    }

    var rating: CompatibilityRating? {
        switch self {
        case .all:
            return nil
        case .playable:
            return .playable
        case .needsTweaks:
            return .needsTweaks
        case .boots:
            return .boots
        case .broken:
            return .broken
        case .unsupported:
            return .unsupported
        }
    }
}

struct CompatibilityDatabaseView: View {
    let games: [CompatibilityGame]

    @State private var searchQuery = ""
    @State private var ratingFilter: CompatibilityRatingFilter = .all

    private var filteredGames: [CompatibilityGame] {
        games
            .filter(matchesGame)
            .sorted { lhs, rhs in
                if lhs.rating.sortIndex == rhs.rating.sortIndex {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.rating.sortIndex < rhs.rating.sortIndex
            }
    }

    private func matchesGame(_ game: CompatibilityGame) -> Bool {
        if let required = ratingFilter.rating, game.rating != required {
            return false
        }

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        return searchHaystack(for: game).contains(trimmedQuery.lowercased())
    }

    private func searchHaystack(for game: CompatibilityGame) -> String {
        let visibility = VectorCompatibilityDatabase.patchVisibility(for: game)
        var parts: [String] = []
        parts.reserveCapacity(21)
        parts.append(game.title)
        parts.append(game.store)
        parts.append(game.appID ?? "")
        parts.append(game.recommendedPreset)
        parts.append(game.recommendedArguments)
        parts.append(game.notes.joined(separator: " "))
        parts.append(game.searchableTags.joined(separator: " "))
        parts.append(game.localProfileName ?? "")
        parts.append(game.remoteVecPatchRuleID ?? "")
        parts.append(game.dependencyRepairs.joined(separator: " "))
        parts.append(game.trustClassification.rawValue)
        parts.append(game.antiCheatProvider ?? "")
        parts.append(game.supportContactStatus)
        parts.append(visibility.backend)
        parts.append(visibility.fallbackBackend ?? "")
        parts.append(visibility.executableMatch ?? "")
        parts.append(visibility.patchVersion)
        parts.append(visibility.patchState)
        parts.append(visibility.riskLevel)
        parts.append(visibility.recommendedAction ?? "")
        parts.append(visibility.knownIssues.joined(separator: " "))
        return parts.joined(separator: " ").lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CompatibilityDatabaseHeader(totalCount: games.count, filteredCount: filteredGames.count)
            CompatibilityFilterPanel(
                searchQuery: $searchQuery,
                ratingFilter: $ratingFilter
            )

            ScrollView {
                if filteredGames.isEmpty {
                    ContentUnavailableView(
                        "No Matching Games",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search or status filter.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredGames) { game in
                            CompatibilityGameCard(game: game)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .vectorPanelSurface()
    }
}

private struct CompatibilityDatabaseHeader: View {
    let totalCount: Int
    let filteredCount: Int

    var body: some View {
        VectorPanelCard {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "checklist.checked")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(VectorPanelTokens.success.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .background(VectorPanelTokens.success.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Compatibility Database")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                    Text("Known launch status, recommended presets, and protected multiplayer notes.")
                        .font(.system(size: 12))
                        .foregroundStyle(VectorPanelTokens.subtleText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(filteredCount)")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.94))
                    Text("of \(totalCount) shown")
                        .font(.system(size: 11))
                        .foregroundStyle(VectorPanelTokens.subtleText)
                }
            }
        }
    }
}

private struct CompatibilitySummaryStrip: View {
    let games: [CompatibilityGame]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(CompatibilityRating.allCases) { rating in
                CompatibilitySummaryPill(
                    rating: rating,
                    count: games.filter { $0.rating == rating }.count
                )
            }
        }
    }
}
private struct CompatibilitySummaryPill: View {
    let rating: CompatibilityRating
    let count: Int

    var body: some View {
        VectorPanelCard {
            VStack(alignment: .leading, spacing: 5) {
                Text("\(count)")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
                CompatibilityRatingBadge(rating: rating)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CompatibilityCoverageStrip: View {
    let games: [CompatibilityGame]

    private var knownIssueCount: Int {
        games.filter { game in
            !VectorCompatibilityDatabase.patchVisibility(for: game).knownIssues.isEmpty
        }.count
    }

    private var coverageItems: [CompatibilityCoverageSummaryItem] {
        [
            CompatibilityCoverageSummaryItem(
                title: "Playable",
                count: games.filter { $0.rating == .playable }.count,
                icon: "checkmark.seal",
                color: VectorPanelTokens.success
            ),
            CompatibilityCoverageSummaryItem(
                title: "Remote rules",
                count: games.filter { $0.hasRemoteVecPatchRule }.count,
                icon: "antenna.radiowaves.left.and.right",
                color: .mint
            ),
            CompatibilityCoverageSummaryItem(
                title: "Dependency repairs",
                count: games.filter { $0.hasDependencyRepairs }.count,
                icon: "wrench.and.screwdriver",
                color: VectorPanelTokens.warning
            ),
            CompatibilityCoverageSummaryItem(
                title: "Known issues",
                count: knownIssueCount,
                icon: "exclamationmark.triangle",
                color: .yellow
            ),
            CompatibilityCoverageSummaryItem(
                title: "Protected",
                count: games.filter { $0.officialSupportRequired }.count,
                icon: "lock.shield",
                color: .red
            )
        ]
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(coverageItems) { item in
                VectorPanelCard {
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .foregroundStyle(item.color.opacity(0.9))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.count)")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.94))
                            Text(item.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(VectorPanelTokens.subtleText)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct CompatibilityCoverageSummaryItem: Identifiable {
    let title: String
    let count: Int
    let icon: String
    let color: Color

    var id: String { title }
}

private struct CompatibilityFilterPanel: View {
    @Binding var searchQuery: String
    @Binding var ratingFilter: CompatibilityRatingFilter

    var body: some View {
        VectorPanelCard {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(VectorPanelTokens.subtleText)
                TextField("Search games, notes, AppID, or anti-cheat", text: $searchQuery)
                    .textFieldStyle(.plain)
                Picker("Status", selection: $ratingFilter) {
                    ForEach(CompatibilityRatingFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            }
        }
    }
}

private struct CompatibilityGameCard: View {
    let game: CompatibilityGame

    private var visibility: CompatibilityPatchVisibilityMetadata {
        VectorCompatibilityDatabase.patchVisibility(for: game)
    }

    private var appIDText: String {
        game.appID.map { "AppID \($0)" } ?? "No AppID"
    }

    private var patchCoverage: String {
        if game.officialSupportRequired {
            return "Official support required"
        }
        if game.hasRemoteVecPatchRule {
            return "Remote rule + local profile"
        }
        if game.hasLocalProfile {
            return "Local profile"
        }
        return "Metadata only"
    }

    private var primaryNote: String {
        if game.trustClassification == .blockedAntiCheat || game.officialSupportRequired {
            return "Official anti-cheat/runtime support is required before local play."
        }
        if let recommendedAction = visibility.recommendedAction, !recommendedAction.isEmpty {
            return recommendedAction
        }
        if let note = game.notes.first, !note.isEmpty {
            return note
        }
        return game.recommendedPreset
    }

    var body: some View {
        VectorPanelCard(padding: 13) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        Text(primaryNote)
                            .font(.system(size: 12))
                            .foregroundStyle(VectorPanelTokens.subtleText)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    CompatibilityRatingBadge(rating: game.rating)
                }

                if game.trustClassification == .blockedAntiCheat || game.trustClassification == .protectedMultiplayer {
                    CompatibilityWarningRow(
                        title: game.antiCheatProvider ?? "Protected multiplayer",
                        detail: game.officialSupportRequired
                            ? "Official runtime support required before local play."
                            : "Protected multiplayer policy applies."
                    )
                }

                HStack(spacing: 8) {
                    CompatibilityMetadataPill(text: game.store, icon: "bag")
                    CompatibilityMetadataPill(text: appIDText, icon: "number")
                    Spacer(minLength: 8)
                    Text("Verified \(game.lastVerifiedOn)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.46))
                }

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        CompatibilityPatchVisibilityPanel(
                            coverage: patchCoverage,
                            confidence: game.confidence,
                            metadata: visibility,
                            repairs: game.dependencyRepairs
                        )

                        if !game.fallbackPlayOptions.isEmpty {
                            Text("Fallback: \(game.fallbackPlayOptions.joined(separator: ", "))")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("Technical details")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VectorPanelTokens.subtleText)
                }
            }
        }
    }
}

private struct CompatibilityPatchVisibilityPanel: View {
    let coverage: String
    let confidence: Double
    let metadata: CompatibilityPatchVisibilityMetadata
    let repairs: [String]

    private var fixSummary: String {
        if !repairs.isEmpty {
            return repairs.prefix(2).joined(separator: ", ")
        }
        return metadata.recommendedAction ?? "No dedicated fix path"
    }

    private var issueSummary: String {
        metadata.knownIssues.first ?? "No known issue flagged"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                CompatibilityVisibilityItem(
                    title: "Backend",
                    value: metadata.backendDisplay,
                    icon: "display.2",
                    tint: .teal,
                    monospaced: true
                )
                CompatibilityVisibilityItem(
                    title: "Patch",
                    value: "\(metadata.patchState) · \(metadata.patchVersion)",
                    icon: "shippingbox.circle",
                    tint: metadata.patchState == "blocked" ? .red : .mint,
                    monospaced: true
                )
                CompatibilityVisibilityItem(
                    title: "Coverage",
                    value: coverage,
                    icon: "target",
                    tint: .blue
                )
                CompatibilityVisibilityItem(
                    title: "Confidence",
                    value: "\(Int(confidence * 100))%",
                    icon: "gauge.with.dots.needle.bottom.50percent",
                    tint: VectorPanelTokens.success,
                    monospaced: true
                )
            }
            HStack(spacing: 8) {
                CompatibilityVisibilityItem(
                    title: "Fix metadata",
                    value: fixSummary,
                    icon: "wrench.and.screwdriver",
                    tint: repairs.isEmpty ? .secondary : VectorPanelTokens.warning
                )
                CompatibilityVisibilityItem(
                    title: "Known issue",
                    value: issueSummary,
                    icon: "exclamationmark.triangle",
                    tint: metadata.knownIssues.isEmpty ? .secondary : .yellow
                )
            }
        }
    }
}

private struct CompatibilityVisibilityItem: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    var monospaced: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint.opacity(0.9))
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(VectorPanelTokens.subtleText)
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: monospaced ? .monospaced : .default))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(value)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct CompatibilityMetadataPill: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(VectorPanelTokens.subtleText)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct CompatibilityCoveragePill: View {
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(tint.opacity(0.95))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct CompatibilityRecommendationRow: View {
    let title: String
    let value: String
    let monospaced: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 118, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .regular, design: monospaced ? .monospaced : .default))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(value)
        }
    }
}

private struct CompatibilityWarningRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.red.opacity(0.78))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.82))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(VectorPanelTokens.subtleText)
            }
        }
        .padding(9)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.red.opacity(0.14), lineWidth: 1)
        )
    }
}
