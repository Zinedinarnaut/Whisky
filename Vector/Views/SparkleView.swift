//
//  SparkleView.swift
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

import AppKit
import Combine
import SwiftUI
import Sparkle
import VectorKit

// swiftlint:disable file_length type_body_length

struct SparkleView: View {
    @StateObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        _checkForUpdatesViewModel = StateObject(wrappedValue: CheckForUpdatesViewModel(updater: updater))
    }

    var body: some View {
        Button("check.updates", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

// This view model class publishes when new updates can be checked by the user
@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }
}

struct HomeView: View {
    let bottles: [Bottle]
    let onOpenBottle: (URL) -> Void

    private var sortedBottles: [Bottle] {
        bottles.sorted()
    }

    var body: some View {
        ScrollView {
            if sortedBottles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("No bottles created")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Use the + button in the toolbar to create your first bottle.")
                        .font(.system(size: 12))
                        .foregroundStyle(VectorPanelTokens.subtleText)
                }
                .frame(maxWidth: .infinity, minHeight: 320)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(sortedBottles) { bottle in
                        HomeBottleCard(bottle: bottle) {
                            onOpenBottle(bottle.url)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .vectorPanelSurface()
    }
}

private struct HomeBottleCard: View {
    let bottle: Bottle
    let onOpen: () -> Void

    private var statusLabel: String {
        bottle.isAvailable ? "Ready" : "Unavailable"
    }

    private var statusColor: Color {
        bottle.isAvailable ? .green : .orange
    }

    var body: some View {
        Button(action: onOpen) {
            VectorPanelCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(bottle.settings.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                                .lineLimit(2)
                            Text("Windows \(bottle.settings.windowsVersion.pretty())")
                                .font(.system(size: 12))
                                .foregroundStyle(VectorPanelTokens.subtleText)
                        }
                        Spacer(minLength: 8)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 7, height: 7)
                            Text(statusLabel)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(statusColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                        )
                    }

                    Rectangle()
                        .fill(VectorPanelTokens.divider)
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(bottle.url.lastPathComponent)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 12, weight: .medium))
                            Text("Open Bottle")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.82))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PatchStatePill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(VectorPanelTokens.subtleText)
            Text(value)
                .foregroundStyle(tint.opacity(0.95))
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.05), in: Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }
}

struct PatchCenterView: View {
    let bottles: [Bottle]
    @Binding var selectedBottleURL: URL?

    @State private var dispatchStatus: DispatchPatchStatus?
    @State private var loading: Bool = false
    @State private var syncing: Bool = false
    @State private var progress: Double = 0
    @State private var statusMessage: String = ""
    @State private var localOverridesDraft: String = ""
    @State private var localOverrideStatus: String = ""
    @State private var localOverrideLoading: Bool = false
    @State private var localOverrideSaving: Bool = false

    private var sortedBottles: [Bottle] {
        bottles.sorted()
    }

    private var selectedBottle: Bottle? {
        if let selectedBottleURL,
           let bottle = sortedBottles.first(where: { $0.url == selectedBottleURL }) {
            return bottle
        }
        return sortedBottles.first
    }

    private var dispatchEnabled: Bool {
        selectedBottle?.settings.patchDispatchEnabled ?? false
    }

    private var installedDispatchProfileCount: Int {
        guard let selectedBottle else {
            return 0
        }
        return selectedBottle.settings.gameProfiles.filter {
            $0.name.hasPrefix(BottleGamingModeManager.dispatchProfileNamePrefix)
        }.count
    }

    private var updateAvailable: Bool {
        dispatchStatus?.updateAvailable ?? false
    }

    private var recommendedBackendLabel: String {
        guard let backend = dispatchStatus?.recommendedBackend else {
            return "--"
        }
        return backend.rawValue.uppercased()
    }

    private var fallbackBackendLabel: String {
        guard let backend = dispatchStatus?.fallbackBackend else {
            return "--"
        }
        return backend.rawValue.uppercased()
    }

    private var statusBadgeText: String {
        guard dispatchEnabled else {
            return "Dispatch Disabled"
        }
        guard let dispatchStatus else {
            return loading ? "Checking..." : "No Metadata"
        }
        if dispatchStatus.effectiveRuleCount == 0 {
            return "No Effective Rules"
        }
        if dispatchStatus.updateAvailable {
            return "Update Available"
        }
        if dispatchStatus.alreadyApplied {
            return "Already Applied"
        }
        return "No-op"
    }

    private var statusBadgeColor: Color {
        guard dispatchEnabled else {
            return .secondary
        }
        guard let dispatchStatus else {
            return .secondary
        }
        if dispatchStatus.effectiveRuleCount == 0 {
            return .secondary
        }
        return dispatchStatus.updateAvailable ? .orange : .green
    }

    private var patchStateDetail: String {
        guard dispatchEnabled else {
            return "Patch dispatch is disabled for this bottle."
        }
        guard let dispatchStatus else {
            return loading
                ? "Checking remote, bundled, and local override patch metadata..."
                : "No patch status has been loaded yet."
        }
        if dispatchStatus.effectiveRuleCount == 0 {
            return "No effective rules matched this bottle, so applying patches would be a no-op."
        }
        if dispatchStatus.updateAvailable {
            return "A newer effective patch set is available for this bottle."
        }
        if dispatchStatus.alreadyApplied {
            return "The effective patch set already matches the last applied digest."
        }
        return "No remote or local patch changes are pending for this bottle."
    }

    private var applyButtonTitle: String {
        if updateAvailable {
            return "Apply to Bottle"
        }
        if dispatchStatus?.alreadyApplied == true {
            return "Already Applied"
        }
        return "No-op"
    }

    private var applyDisabledReason: String {
        guard dispatchEnabled else {
            return "Enable patch dispatch before applying rules."
        }
        guard let dispatchStatus else {
            return "Check latest metadata before applying rules."
        }
        if dispatchStatus.effectiveRuleCount == 0 {
            return "No effective rules matched this bottle."
        }
        if dispatchStatus.alreadyApplied {
            return "The current patch set is already applied."
        }
        if !dispatchStatus.updateAvailable {
            return "No patch changes are pending."
        }
        return ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VectorPanelCard {
                    VStack(alignment: .leading, spacing: 12) {
                        VectorSectionHeader(title: "Patch Status")
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: "shippingbox.circle")
                                .foregroundStyle(statusBadgeColor)
                            Text(statusBadgeText)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(statusBadgeColor)
                            Spacer()
                            CompatibilityRatingBadge(
                                rating: updateAvailable ? .needsTweaks : .playable
                            )
                        }
                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.system(size: 12))
                                .foregroundStyle(VectorPanelTokens.subtleText)
                        }
                        Text(patchStateDetail)
                            .font(.system(size: 12))
                            .foregroundStyle(VectorPanelTokens.subtleText)
                        if let dispatchStatus, dispatchStatus.recommendedBackend != nil {
                            HStack(spacing: 8) {
                                Text("Effective backend:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.82))
                                Text(recommendedBackendLabel)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.9))
                                if dispatchStatus.fallbackBackend != nil {
                                    Text("Fallback: \(fallbackBackendLabel)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(VectorPanelTokens.subtleText)
                                }
                            }
                        }
                        if let dispatchStatus {
                            HStack(spacing: 8) {
                                PatchStatePill(
                                    title: "Effective",
                                    value: "\(dispatchStatus.effectiveRuleCount) rule(s)",
                                    tint: dispatchStatus.effectiveRuleCount > 0 ? .mint : .secondary
                                )
                                PatchStatePill(
                                    title: "Last applied",
                                    value: formattedDate(dispatchStatus.lastAppliedAt),
                                    tint: dispatchStatus.alreadyApplied ? .green : .secondary
                                )
                                PatchStatePill(
                                    title: "Remote fetched",
                                    value: formattedDate(dispatchStatus.lastFetchedAt),
                                    tint: dispatchStatus.lastFetchedAt == nil ? .secondary : .blue
                                )
                            }
                        }
                        if loading || syncing {
                            ProgressView(value: progress, total: 1)
                                .progressViewStyle(.linear)
                        }
                    }
                }

                VectorPanelCard {
                    VStack(alignment: .leading, spacing: 10) {
                        VectorSectionHeader(title: "Target Bottle")
                        if sortedBottles.isEmpty {
                            Text("No bottles available.")
                                .font(.system(size: 12))
                                .foregroundStyle(VectorPanelTokens.subtleText)
                        } else {
                            VectorSettingRow("Bottle") {
                                Picker("Bottle", selection: $selectedBottleURL) {
                                    ForEach(sortedBottles) { bottle in
                                        Text(bottle.settings.name).tag(Optional(bottle.url))
                                    }
                                }
                                .pickerStyle(.menu)
                                .vectorCompactPicker()
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    dashboardMetric(
                        title: "Channel",
                        value: dispatchStatus?.channel.rawValue.capitalized ?? "--",
                        icon: "line.3.horizontal.decrease.circle.fill",
                        tint: .blue
                    )
                    dashboardMetric(
                        title: "Remote Version",
                        value: "\(dispatchStatus?.remoteVersion ?? 0)",
                        icon: "arrow.down.circle.fill",
                        tint: .orange
                    )
                    dashboardMetric(
                        title: "Installed Version",
                        value: "\(dispatchStatus?.lastAppliedVersion ?? 0)",
                        icon: "checkmark.circle.fill",
                        tint: .green
                    )
                    dashboardMetric(
                        title: "Rule Count",
                        value: "\(dispatchStatus?.remoteRuleCount ?? 0)",
                        icon: "list.number",
                        tint: .mint
                    )
                    dashboardMetric(
                        title: "Rule Version",
                        value: "\(dispatchStatus?.remoteRuleVersion ?? 0)",
                        icon: "square.stack.3d.up.fill",
                        tint: .indigo
                    )
                    dashboardMetric(
                        title: "Backend",
                        value: recommendedBackendLabel,
                        icon: "display.2",
                        tint: .teal
                    )
                }

                VectorPanelCard {
                    VStack(alignment: .leading, spacing: 10) {
                        VectorSectionHeader(title: "Actions")
                        HStack(spacing: 10) {
                            Button("Check Latest") {
                                refreshStatus(checkRemote: true)
                            }
                            .buttonStyle(VectorPrimaryPanelButtonStyle())
                            .disabled(loading || syncing)

                            Button(applyButtonTitle) {
                                applyPatchUpdate()
                            }
                            .buttonStyle(VectorPrimaryPanelButtonStyle())
                            .disabled(loading || syncing || !updateAvailable || !dispatchEnabled)
                        }
                        if dispatchStatus == nil && !loading {
                            Text("No patch metadata yet. Use Check Latest.")
                                .font(.system(size: 12))
                                .foregroundStyle(VectorPanelTokens.subtleText)
                        }
                        if !applyDisabledReason.isEmpty && dispatchStatus != nil {
                            Text(applyDisabledReason)
                                .font(.system(size: 12))
                                .foregroundStyle(VectorPanelTokens.subtleText)
                        }
                    }
                }

                VectorPanelCard {
                    VStack(alignment: .leading, spacing: 10) {
                        VectorSectionHeader(title: "Local Overrides")
                        Text("Rules here override remote dispatch rules for this bottle only.")
                            .font(.system(size: 12))
                            .foregroundStyle(VectorPanelTokens.subtleText)
                        TextEditor(text: $localOverridesDraft)
                            .font(.system(size: 12, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 180, maxHeight: 260)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.black.opacity(0.25))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .disabled(localOverrideLoading || localOverrideSaving)

                        if !localOverrideStatus.isEmpty {
                            Text(localOverrideStatus)
                                .font(.system(size: 12))
                                .foregroundStyle(VectorPanelTokens.subtleText)
                        }

                        HStack(spacing: 10) {
                            Button("Reload") {
                                loadLocalOverridesEditor()
                            }
                            .buttonStyle(VectorPrimaryPanelButtonStyle())
                            .disabled(localOverrideLoading || localOverrideSaving)

                            Button("Save") {
                                saveLocalOverridesEditor()
                            }
                            .buttonStyle(VectorPrimaryPanelButtonStyle())
                            .disabled(localOverrideLoading || localOverrideSaving || selectedBottle == nil)

                            Button("Clear") {
                                clearLocalOverridesEditor()
                            }
                            .buttonStyle(VectorPrimaryPanelButtonStyle())
                            .disabled(localOverrideLoading || localOverrideSaving || selectedBottle == nil)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .vectorPanelSurface()
        .task {
            ensureBottleSelection()
            if dispatchStatus == nil {
                refreshStatus(checkRemote: true)
            }
            if localOverridesDraft.isEmpty {
                loadLocalOverridesEditor()
            }
        }
        .onChange(of: selectedBottleURL) {
            dispatchStatus = nil
            loading = false
            syncing = false
            progress = 0
            statusMessage = ""
            refreshStatus(checkRemote: true)
            loadLocalOverridesEditor()
        }
        .onChange(of: bottles.map(\.url)) {
            ensureBottleSelection()
            loadLocalOverridesEditor()
        }
    }

    @ViewBuilder
    private func dashboardMetric(
        title: String,
        value: String,
        icon: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white.opacity(0.93))
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(VectorPanelTokens.subtleText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(VectorPanelTokens.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return "Unknown"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func refreshStatus(checkRemote: Bool) {
        guard let targetBottle = selectedBottle else {
            dispatchStatus = nil
            statusMessage = "Select a bottle to view patch status."
            return
        }
        guard targetBottle.settings.patchDispatchEnabled else {
            dispatchStatus = DispatchPatchStatus(
                endpointURL: targetBottle.settings.patchDispatchEndpointURL,
                channel: targetBottle.settings.patchDispatchChannel,
                dispatchEnabled: false
            )
            statusMessage = "Patch dispatch is disabled for this bottle."
            return
        }

        loading = true
        progress = 0.2
        statusMessage = "Checking dispatch metadata..."
        Task(priority: .userInitiated) {
            let status = await DispatchPatchService.shared.status(for: targetBottle, checkRemote: checkRemote)
            await MainActor.run {
                dispatchStatus = status
                loading = false
                progress = 0
                if status.updateAvailable {
                    statusMessage = "A newer patch set is available."
                } else if status.alreadyApplied {
                    statusMessage = "Latest patch set already applied to this bottle."
                } else {
                    statusMessage = "Patch metadata is current."
                }
            }
        }
    }

    private func applyPatchUpdate() {
        guard let targetBottle = selectedBottle else {
            statusMessage = "Select a bottle first."
            return
        }
        guard targetBottle.settings.patchDispatchEnabled else {
            statusMessage = "Enable patch dispatch first."
            return
        }

        syncing = true
        progress = 0.05
        statusMessage = "Fetching latest patch manifest..."
        Task(priority: .userInitiated) {
            let latestStatus = await DispatchPatchService.shared.status(for: targetBottle, checkRemote: true)
            await MainActor.run {
                dispatchStatus = latestStatus
                progress = 0.45
                statusMessage = "Applying patches to this bottle..."
            }

            await BottleGamingModeManager.syncDispatchProfiles(for: targetBottle, forceRefresh: true)
            let appliedStatus = await DispatchPatchService.shared.status(for: targetBottle, checkRemote: false)

            await MainActor.run {
                dispatchStatus = appliedStatus
                progress = 1
                syncing = false
                statusMessage = appliedStatus.alreadyApplied
                    ? "Patch set is applied for \(targetBottle.settings.name)."
                    : "Patch sync completed for \(targetBottle.settings.name)."
                targetBottle.updateInstalledPrograms()
            }
        }
    }

    private func ensureBottleSelection() {
        if sortedBottles.isEmpty {
            selectedBottleURL = nil
            dispatchStatus = nil
            return
        }

        if let selectedBottleURL,
           sortedBottles.contains(where: { $0.url == selectedBottleURL }) {
            return
        }

        selectedBottleURL = sortedBottles.first?.url
    }

    private func loadLocalOverridesEditor() {
        guard let targetBottle = selectedBottle else {
            localOverridesDraft = Self.localOverridesTemplate()
            localOverrideStatus = "Select a bottle to edit local overrides."
            return
        }

        localOverrideLoading = true
        localOverrideStatus = "Loading local overrides..."
        Task(priority: .userInitiated) {
            let document = await DispatchPatchService.shared.localOverridesDocument(for: targetBottle)
            let encoded = Self.prettyPrintedLocalOverrides(document) ?? Self.localOverridesTemplate()
            await MainActor.run {
                localOverridesDraft = encoded
                localOverrideLoading = false
                localOverrideStatus = document.rules.isEmpty
                    ? "No local overrides yet."
                    : "Loaded \(document.rules.count) local override rule(s)."
            }
        }
    }

    private func saveLocalOverridesEditor() {
        guard let targetBottle = selectedBottle else {
            localOverrideStatus = "Select a bottle first."
            return
        }

        localOverrideSaving = true
        localOverrideStatus = "Saving local overrides..."
        Task(priority: .userInitiated) {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            do {
                var document = try decoder.decode(
                    DispatchPatchLocalOverridesDocument.self,
                    from: Data(localOverridesDraft.utf8)
                )
                if document.generatedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    document.generatedAt = ISO8601DateFormatter().string(from: Date())
                }
                try await DispatchPatchService.shared.saveLocalOverridesDocument(document, for: targetBottle)
                _ = await DispatchPatchService.shared.rules(for: targetBottle, forceRefresh: true)
                await MainActor.run {
                    localOverrideSaving = false
                    localOverrideStatus = "Saved local overrides."
                    refreshStatus(checkRemote: false)
                }
                await BottleGamingModeManager.syncDispatchProfiles(for: targetBottle, forceRefresh: false)
            } catch {
                await MainActor.run {
                    localOverrideSaving = false
                    localOverrideStatus = "Invalid JSON or save failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func clearLocalOverridesEditor() {
        localOverridesDraft = Self.localOverridesTemplate()
        saveLocalOverridesEditor()
    }

    private static func localOverridesTemplate() -> String {
        """
        {
          "version": 1,
          "generated_at": "",
          "rules": []
        }
        """
    }

    private static func prettyPrintedLocalOverrides(_ document: DispatchPatchLocalOverridesDocument) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(document) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

// swiftlint:enable file_length type_body_length
