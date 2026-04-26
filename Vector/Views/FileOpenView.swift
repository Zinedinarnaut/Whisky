//
//  FileOpenView.swift
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

struct FileOpenView: View {
    var fileURL: URL
    var currentBottle: URL?
    var bottles: [Bottle]

    @State private var selection: URL = URL(filePath: "")
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Picker("run.bottle", selection: $selection) {
                    ForEach(bottles, id: \.self) {
                        Text($0.settings.name)
                            .tag($0.url)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .formStyle(.grouped)
            .navigationTitle(String(format: String(localized: "run.title"), fileURL.lastPathComponent))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("create.cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("button.run") {
                        run()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: ViewWidth.small)
        .onAppear {
            // Makes sure there are more than 0 bottles.
            // Otherwise, it will crash on the nil cascade
            if bottles.count <= 0 {
                dismiss()
                return
            }

            selection = bottles.first(where: { $0.url == currentBottle })?.url ?? bottles[0].url

            if bottles.count == 1 {
                // If the user only has one bottle
                // there's nothing for them to select
                run()
            }
        }
    }

    func run() {
        if let bottle = bottles.first(where: { $0.url == selection }) {
            Task.detached(priority: .userInitiated) {
                do {
                    if fileURL.pathExtension == "bat" {
                        try await Wine.runBatchFile(url: fileURL,
                                                    bottle: bottle)
                    } else {
                        try await Wine.runProgram(at: fileURL, bottle: bottle)
                    }
                } catch {
                    print(error)
                }
            }
            dismiss()
        }
    }
}

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
                    game.notes.joined(separator: " ").lowercased()
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Compatibility Database")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))

            HStack(spacing: 10) {
                TextField("Search title or key notes", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                Picker("Status", selection: $ratingFilter) {
                    ForEach(CompatibilityRatingFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 170)
            }

            if filteredGames.isEmpty {
                ContentUnavailableView(
                    "No Matching Games",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search or change the status filter.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredGames) { game in
                            compatibilityGameCard(game)
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

    @ViewBuilder
    private func compatibilityGameCard(_ game: CompatibilityGame) -> some View {
        VectorPanelCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                        Text(game.store)
                            .font(.system(size: 12))
                            .foregroundStyle(VectorPanelTokens.subtleText)
                    }
                    Spacer(minLength: 8)
                    CompatibilityRatingBadge(rating: game.rating)
                }

                compatibilityProtectionSummary(game)

                if let firstNote = game.notes.first, !firstNote.isEmpty {
                    Text(firstNote)
                        .font(.system(size: 12))
                        .foregroundStyle(VectorPanelTokens.subtleText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if game.notes.count > 1 {
                    Text("+\(game.notes.count - 1) more notes")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.46))
                }

                if !game.recommendedArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(game.recommendedArguments)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(game.recommendedArguments)
                } else if !game.recommendedPreset.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(game.recommendedPreset)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)
                        .help(game.recommendedPreset)
                }

                compatibilityOfficialSupportBadge(game)
            }
        }
    }

    @ViewBuilder
    private func compatibilityProtectionSummary(_ game: CompatibilityGame) -> some View {
        if game.trustClassification == .blockedAntiCheat || game.trustClassification == .protectedMultiplayer {
            Text(game.antiCheatProvider ?? "Protected multiplayer")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.red.opacity(0.75))
        }
    }

    @ViewBuilder
    private func compatibilityOfficialSupportBadge(_ game: CompatibilityGame) -> some View {
        if game.officialSupportRequired {
            Text("Official support required")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange.opacity(0.78))
        }
    }
}

struct CompatibilityRatingBadge: View {
    let rating: CompatibilityRating

    var body: some View {
        Text(rating.title)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        switch rating {
        case .playable:
            return Color.green.opacity(0.18)
        case .needsTweaks:
            return Color.orange.opacity(0.2)
        case .boots:
            return Color.yellow.opacity(0.2)
        case .broken:
            return Color.red.opacity(0.2)
        case .unsupported:
            return Color.gray.opacity(0.22)
        }
    }

    private var foregroundColor: Color {
        switch rating {
        case .playable:
            return .green
        case .needsTweaks:
            return .orange
        case .boots:
            return .yellow
        case .broken:
            return .red
        case .unsupported:
            return .secondary
        }
    }
}
