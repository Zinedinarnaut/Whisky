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
            .filter { game in
                let matchesFilter: Bool
                if let required = ratingFilter.rating {
                    matchesFilter = game.rating == required
                } else {
                    matchesFilter = true
                }

                guard matchesFilter else {
                    return false
                }

                let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedQuery.isEmpty else {
                    return true
                }

                let normalizedQuery = trimmedQuery.lowercased()
                let haystack = [
                    game.title.lowercased(),
                    game.store.lowercased(),
                    game.appID ?? "",
                    game.recommendedPreset.lowercased(),
                    game.recommendedArguments.lowercased(),
                    game.notes.joined(separator: " ").lowercased(),
                    game.antiCheatProvider?.lowercased() ?? "",
                    game.supportContactStatus.lowercased()
                ].joined(separator: " ")

                return haystack.contains(normalizedQuery)
            }
            .sorted { lhs, rhs in
                if lhs.rating.sortIndex == rhs.rating.sortIndex {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.rating.sortIndex < rhs.rating.sortIndex
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CompatibilityDatabaseHeader(totalCount: games.count, filteredCount: filteredGames.count)
            CompatibilitySummaryStrip(games: games)
            CompatibilityFilterPanel(searchQuery: $searchQuery, ratingFilter: $ratingFilter)

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
                    .foregroundStyle(.green.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

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

private struct CompatibilityFilterPanel: View {
    @Binding var searchQuery: String
    @Binding var ratingFilter: CompatibilityRatingFilter

    var body: some View {
        VectorPanelCard {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(VectorPanelTokens.subtleText)
                TextField("Search games, AppID, store, notes, or anti-cheat", text: $searchQuery)
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

    private var appIDText: String {
        game.appID.map { "AppID \($0)" } ?? "No AppID"
    }

    private var primaryRecommendation: String {
        if !game.recommendedPreset.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return game.recommendedPreset
        }
        if !game.recommendedArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return game.recommendedArguments
        }
        return "Default bottle settings"
    }

    var body: some View {
        VectorPanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        HStack(spacing: 8) {
                            CompatibilityMetadataPill(text: game.store, icon: "bag")
                            CompatibilityMetadataPill(text: appIDText, icon: "number")
                        }
                    }
                    Spacer(minLength: 8)
                    CompatibilityRatingBadge(rating: game.rating)
                }

                if !game.recommendedArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CompatibilityRecommendationRow(
                        title: "Recommended args",
                        value: game.recommendedArguments,
                        monospaced: true
                    )
                }
                CompatibilityRecommendationRow(
                    title: "Recommended preset",
                    value: primaryRecommendation,
                    monospaced: false
                )

                if let note = game.notes.first {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundStyle(VectorPanelTokens.subtleText)
                        .lineLimit(2)
                }

                if game.trustClassification == .blockedAntiCheat || game.trustClassification == .protectedMultiplayer {
                    CompatibilityWarningRow(
                        title: game.antiCheatProvider ?? "Protected multiplayer",
                        detail: game.officialSupportRequired
                            ? "Official runtime support required before local play."
                            : "Protected multiplayer policy applies."
                    )
                }

                if !game.fallbackPlayOptions.isEmpty {
                    Text("Fallback: \(game.fallbackPlayOptions.joined(separator: ", "))")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
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
        .background(Color.white.opacity(0.05), in: Capsule())
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
