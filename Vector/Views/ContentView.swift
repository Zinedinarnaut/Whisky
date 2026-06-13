//
//  ContentView.swift
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
import SemanticVersion
import Metal

private struct PatchUpdateCandidate: Identifiable, Hashable {
    let bottleURL: URL
    let bottleName: String
    let remoteVersion: Int
    let remoteGeneratedAt: String

    var id: URL { bottleURL }
}

private struct OnboardingEnvironmentItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let success: Bool
}

private struct OnboardingMetalProbe {
    let deviceName: String
    let recommendedBackend: GraphicsBackendMode
    let supportedFamilies: [String]
    let recommendation: String
}

private enum SidebarDetail: Hashable {
    case home
    case compatibility
    case patchCenter
    case bottle
}

// swiftlint:disable type_body_length file_length
struct ContentView: View {
    private static let checkVectorWineUpdatesKey = "checkVectorWineUpdates"
    private static let checkWhiskyWineUpdatesLegacyKey = "checkWhiskyWineUpdates"

    @AppStorage("selectedBottleURL") private var selectedBottleURL: URL?
    @AppStorage("checkVectorWineUpdates") private var checkVectorWineUpdates = true
    @AppStorage("vectorOnboardingCompleted") private var vectorOnboardingCompleted = false
    @EnvironmentObject var bottleVM: BottleVM
    @Binding var showSetup: Bool

    @State private var selected: URL?
    @State private var showBottleCreation: Bool = false
    @State private var bottlesLoaded: Bool = false
    @State private var newlyCreatedBottleURL: URL?
    @State private var openedFileURL: URL?
    @State private var triggerRefresh: Bool = false
    @State private var refreshAnimation: Angle = .degrees(0)
    @State private var didScheduleUpdateCheck: Bool = false

    @State private var bottleFilter = ""
    @State private var selectedDetail: SidebarDetail = .home
    @State private var patchCenterSelectedBottleURL: URL?
    @State private var showOnboardingFlow: Bool = false
    @State private var didSchedulePatchScan: Bool = false
    @State private var patchUpdateCandidates: [PatchUpdateCandidate] = []
    @State private var patchUpdateSelections: Set<URL> = []
    @State private var showPatchUpdateModal: Bool = false
    @State private var showPatchSelectionList: Bool = false
    @State private var scanningPatchUpdates: Bool = false
    @State private var applyingPatchUpdates: Bool = false
    @State private var patchUpdateProgress: Double = 0
    @State private var patchUpdateStatusText: String = ""

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showBottleCreation.toggle()
                } label: {
                    Image(systemName: "plus")
                        .help("button.createBottle")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    bottleVM.loadBottles()
                    if let bottle = bottleVM.bottles.first(where: { $0.url == selected }) {
                        bottle.updateInstalledPrograms()
                    }
                    triggerRefresh.toggle()
                    withAnimation(.default) {
                        refreshAnimation = .degrees(360)
                    } completion: {
                        refreshAnimation = .degrees(0)
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .help("button.refresh")
                        .rotationEffect(refreshAnimation)
                }
            }
        }
        .sheet(isPresented: $showBottleCreation) {
            BottleCreationView(newlyCreatedBottleURL: $newlyCreatedBottleURL)
        }
        .sheet(isPresented: $showSetup) {
            SetupView(showSetup: $showSetup, firstTime: false)
        }
        .sheet(
            isPresented: $showOnboardingFlow,
            onDismiss: {
                vectorOnboardingCompleted = true
                schedulePatchScanIfNeeded(force: true)
            },
            content: {
                VectorOnboardingFlowSheet(
                    bottles: bottleVM.bottles,
                    checkVectorWineUpdates: $checkVectorWineUpdates
                ) { recommendedBackend in
                    applyOnboardingBackendRecommendation(recommendedBackend)
                    vectorOnboardingCompleted = true
                    showOnboardingFlow = false
                }
            }
        )
        .sheet(isPresented: $showPatchUpdateModal) {
            PatchUpdateFlowSheet(
                candidates: patchUpdateCandidates,
                selectedBottleURLs: $patchUpdateSelections,
                showSelectionList: $showPatchSelectionList,
                applying: applyingPatchUpdates,
                progress: patchUpdateProgress,
                statusText: patchUpdateStatusText,
                onClose: {
                    showPatchUpdateModal = false
                    showPatchSelectionList = false
                },
                onUpdateAll: {
                    applyPatchUpdates(to: patchUpdateCandidates.map(\.bottleURL))
                },
                onUpdateSelection: {
                    applyPatchUpdates(to: Array(patchUpdateSelections))
                }
            )
        }
        .sheet(item: $openedFileURL) { url in
            FileOpenView(fileURL: url,
                         currentBottle: selected,
                         bottles: bottleVM.bottles)
        }
        .onChange(of: selected) {
            selectedBottleURL = selected
            patchCenterSelectedBottleURL = selected
            if selected != nil {
                selectedDetail = .bottle
            } else if selectedDetail == .bottle {
                selectedDetail = .home
            }
        }
        .handlesExternalEvents(preferring: [], allowing: ["*"])
        .onOpenURL { url in
            openedFileURL = url
        }
        .task {
            bottleVM.loadBottles()
            bottlesLoaded = true

            if let bottle = bottleVM.bottles.first(where: { $0.url == selectedBottleURL && $0.isAvailable }) {
                selected = bottle.url
            } else {
                selected = nil
            }
            patchCenterSelectedBottleURL = selected ?? bottleVM.bottles.first?.url

            if !VectorWineInstaller.isVectorWineInstalled() {
                showSetup = true
            }

            if shouldCheckVectorWineUpdatesOnLaunch() {
                scheduleVectorWineUpdateCheckIfNeeded()
            }

            if !vectorOnboardingCompleted && !showSetup {
                showOnboardingFlow = true
            } else {
                schedulePatchScanIfNeeded(force: false)
            }
        }
        .onChange(of: showSetup) { _, setupVisible in
            if !setupVisible, !vectorOnboardingCompleted {
                showOnboardingFlow = true
            }
        }
        .onChange(of: bottleVM.bottles.map(\.url)) {
            schedulePatchScanIfNeeded(force: false)
        }
    }

    var sidebar: some View {
        ScrollViewReader { proxy in
            List(selection: $selected) {
                Section("Browse") {
                    sidebarPageButton(
                        title: "Home",
                        icon: "house.fill",
                        detail: .home
                    )
                    sidebarPageButton(
                        title: "Compatibility Database",
                        icon: "list.bullet.rectangle.portrait.fill",
                        detail: .compatibility
                    )
                    sidebarPageButton(
                        title: "Patch Center",
                        icon: "arrow.triangle.2.circlepath.circle.fill",
                        detail: .patchCenter
                    )
                }
                Section {
                    ForEach(filteredBottles) { bottle in
                        Group {
                            if bottle.inFlight {
                                HStack {
                                    Text(bottle.settings.name)
                                    Spacer()
                                    ProgressView().controlSize(.small)
                                }
                                .opacity(0.5)
                            } else {
                                BottleListEntry(bottle: bottle, selected: $selected, refresh: $triggerRefresh)
                                    .selectionDisabled(!bottle.isAvailable)
                            }
                        }
                        .id(bottle.url)
                        .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .animation(.default, value: bottleVM.bottles)
            .animation(.default, value: bottleFilter)
            .listStyle(.sidebar)
            .onChange(of: newlyCreatedBottleURL) { _, url in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    selected = url
                    withAnimation {
                        proxy.scrollTo(url, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var detail: some View {
        switch selectedDetail {
        case .home:
            HomeView(
                bottles: bottleVM.bottles,
                onOpenBottle: { bottleURL in
                    selected = bottleURL
                    selectedDetail = .bottle
                }
            )
        case .compatibility:
            CompatibilityDatabaseView(games: VectorCompatibilityDatabase.knownGames)
        case .patchCenter:
            PatchCenterView(
                bottles: bottleVM.bottles,
                selectedBottleURL: $patchCenterSelectedBottleURL
            )
        case .bottle:
            if let bottleURL = selected,
               let bottle = bottleVM.bottles.first(where: { $0.url == bottleURL }) {
                BottleView(bottle: bottle)
                    .disabled(bottle.inFlight)
                    .id(bottle.url)
            } else if (bottleVM.bottles.isEmpty || bottleVM.countActive() == 0) && bottlesLoaded {
                VStack {
                    Text("No bottles created yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Use the + button in the toolbar to create your first bottle.")
                        .font(.system(size: 12))
                        .foregroundStyle(VectorPanelTokens.subtleText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HomeView(
                    bottles: bottleVM.bottles,
                    onOpenBottle: { bottleURL in
                        selected = bottleURL
                        selectedDetail = .bottle
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func sidebarPageButton(
        title: String,
        icon: String,
        detail: SidebarDetail
    ) -> some View {
        Button {
            if detail == .patchCenter, patchCenterSelectedBottleURL == nil {
                patchCenterSelectedBottleURL = selected ?? bottleVM.bottles.first?.url
            }
            selectedDetail = detail
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selectedDetail == detail ? .white.opacity(0.92) : VectorPanelTokens.subtleText)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(selectedDetail == detail ? 0.92 : 0.70))
                Spacer()
                if selectedDetail == detail {
                    Circle()
                        .fill(Color.white.opacity(0.72))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: VectorPanelTokens.controlRadius, style: .continuous)
                    .fill(selectedDetail == detail ? Color.white.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VectorPanelTokens.controlRadius, style: .continuous)
                    .stroke(selectedDetail == detail ? VectorPanelTokens.border : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
        .listRowBackground(Color.clear)
    }

    var filteredBottles: [Bottle] {
        if bottleFilter.isEmpty {
            bottleVM.bottles
                .sorted()
        } else {
            bottleVM.bottles
                .filter { $0.settings.name.localizedCaseInsensitiveContains(bottleFilter) }
                .sorted()
        }
    }

    private func applyOnboardingBackendRecommendation(_ backend: GraphicsBackendMode) {
        for bottle in bottleVM.bottles {
            bottle.settings.graphicsBackendMode = backend
            switch backend {
            case .dxvk:
                bottle.settings.dxvk = true
                bottle.settings.dxvkAsync = true
            case .dxmt:
                bottle.settings.dxvk = false
                bottle.settings.dxvkAsync = false
            case .d3dMetal, .wined3d, .auto:
                bottle.settings.dxvk = false
            }
        }
    }

    private func schedulePatchScanIfNeeded(force: Bool) {
        if !force && didSchedulePatchScan {
            return
        }
        if scanningPatchUpdates || applyingPatchUpdates {
            return
        }
        if !force {
            didSchedulePatchScan = true
        }

        scanningPatchUpdates = true
        patchUpdateStatusText = "Checking patch availability..."

        Task(priority: .utility) {
            var candidates: [PatchUpdateCandidate] = []
            for bottle in bottleVM.bottles where bottle.settings.patchDispatchEnabled {
                let status = await DispatchPatchService.shared.status(for: bottle, checkRemote: true)
                guard status.dispatchEnabled, status.updateAvailable else {
                    continue
                }
                candidates.append(
                    PatchUpdateCandidate(
                        bottleURL: bottle.url,
                        bottleName: bottle.settings.name,
                        remoteVersion: status.remoteVersion,
                        remoteGeneratedAt: status.remoteGeneratedAt
                    )
                )
            }

            let sorted = candidates.sorted {
                $0.bottleName.localizedCaseInsensitiveCompare($1.bottleName) == .orderedAscending
            }

            await MainActor.run {
                scanningPatchUpdates = false
                patchUpdateCandidates = sorted
                patchUpdateSelections = Set(sorted.map(\.bottleURL))
                if !sorted.isEmpty, !showOnboardingFlow, !showSetup {
                    patchUpdateStatusText = "Applying patch updates automatically..."
                    applyPatchUpdates(to: sorted.map(\.bottleURL), automatic: true)
                } else if sorted.isEmpty {
                    patchUpdateStatusText = "All bottles are up to date."
                }
            }
        }
    }

    private func applyPatchUpdates(to bottleURLs: [URL], automatic: Bool = false) {
        let uniqueBottleURLs = Array(Set(bottleURLs))
        guard !uniqueBottleURLs.isEmpty else {
            patchUpdateStatusText = "Select at least one bottle."
            return
        }

        applyingPatchUpdates = true
        patchUpdateProgress = 0
        patchUpdateStatusText = automatic
            ? "Applying patch updates automatically..."
            : "Applying patch updates..."
        if automatic {
            showPatchUpdateModal = false
            showPatchSelectionList = false
        }

        Task(priority: .userInitiated) {
            let sortedURLs = uniqueBottleURLs.sorted {
                $0.absoluteString.localizedCaseInsensitiveCompare($1.absoluteString) == .orderedAscending
            }
            let totalCount = max(1, sortedURLs.count)
            var completed = 0

            for bottleURL in sortedURLs {
                if let bottle = bottleVM.bottles.first(where: { $0.url == bottleURL }) {
                    await BottleGamingModeManager.syncDispatchProfiles(for: bottle, forceRefresh: true)
                    await MainActor.run {
                        bottle.updateInstalledPrograms()
                    }
                }
                completed += 1
                await MainActor.run {
                    patchUpdateProgress = Double(completed) / Double(totalCount)
                }
            }

            await MainActor.run {
                applyingPatchUpdates = false
                showPatchUpdateModal = false
                showPatchSelectionList = false
                patchUpdateProgress = 0
                patchUpdateCandidates.removeAll(where: { uniqueBottleURLs.contains($0.bottleURL) })
                patchUpdateSelections.subtract(uniqueBottleURLs)
                patchUpdateStatusText = automatic
                    ? "Patch updates were applied automatically."
                    : "Patch updates complete."
            }
        }
    }

    private func shouldCheckVectorWineUpdatesOnLaunch() -> Bool {
        let defaults = UserDefaults.standard

        if let value = defaults.object(forKey: Self.checkVectorWineUpdatesKey) as? Bool {
            return value
        }

        if let legacyValue = defaults.object(forKey: Self.checkWhiskyWineUpdatesLegacyKey) as? Bool {
            return legacyValue
        }

        return checkVectorWineUpdates
    }

    private func scheduleVectorWineUpdateCheckIfNeeded() {
        guard !didScheduleUpdateCheck else {
            return
        }
        didScheduleUpdateCheck = true

        Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            guard shouldCheckVectorWineUpdatesOnLaunch() else { return }

            let updateInfo = await Task.detached(priority: .utility) {
                await VectorWineInstaller.shouldUpdateVectorWine()
            }.value
            guard updateInfo.0 else { return }

            let alert = NSAlert()
            alert.messageText = String(localized: "update.vectorwine.title")
            alert.informativeText = String(
                format: String(localized: "update.vectorwine.description"),
                String(VectorWineInstaller.vectorWineVersion() ?? SemanticVersion(0, 0, 0)),
                String(updateInfo.1)
            )
            alert.alertStyle = .warning
            alert.addButton(withTitle: String(localized: "update.vectorwine.update"))
            alert.addButton(withTitle: String(localized: "button.removeAlert.cancel"))

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                VectorWineInstaller.uninstall()
                showSetup = true
            }
        }
    }
}

private struct VectorOnboardingFlowSheet: View {
    let bottles: [Bottle]
    @Binding var checkVectorWineUpdates: Bool
    let onComplete: (GraphicsBackendMode) -> Void

    @State private var environmentItems: [OnboardingEnvironmentItem] = []
    @State private var metalProbe: OnboardingMetalProbe?
    @State private var applyRecommendationToBottles = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Vector Setup")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white.opacity(0.94))

            Text("First-run checks and initial configuration")
                .font(.system(size: 13))
                .foregroundStyle(VectorPanelTokens.subtleText)

            VectorPanelCard {
                VStack(alignment: .leading, spacing: 8) {
                    VectorSectionHeader(title: "Environment Validation")
                    ForEach(environmentItems) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(item.success ? VectorPanelTokens.success : VectorPanelTokens.danger)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                                Text(item.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(VectorPanelTokens.subtleText)
                            }
                            Spacer()
                        }
                    }
                }
            }

            VectorPanelCard {
                VStack(alignment: .leading, spacing: 8) {
                    VectorSectionHeader(title: "Metal Capability")
                    if let metalProbe {
                        VectorSettingRow("Device", subtitle: metalProbe.deviceName) {
                            EmptyView()
                        }
                        VectorSettingRow(
                            "Recommended backend",
                            subtitle: metalProbe.recommendedBackend.rawValue.uppercased()
                        ) {
                            EmptyView()
                        }
                        Text(metalProbe.recommendation)
                            .font(.system(size: 12))
                            .foregroundStyle(VectorPanelTokens.subtleText)
                        if !metalProbe.supportedFamilies.isEmpty {
                            Text(metalProbe.supportedFamilies.joined(separator: ", "))
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    } else {
                        ProgressView("Running Metal capability probe...")
                            .controlSize(.small)
                    }
                }
            }

            VectorPanelCard {
                VStack(alignment: .leading, spacing: 8) {
                    VectorSectionHeader(title: "Initial Configuration")
                    Toggle("Enable Vector runtime update checks", isOn: $checkVectorWineUpdates)
                        .toggleStyle(VectorCompactToggleStyle())
                    Toggle(
                        "Apply recommended graphics backend to existing bottles",
                        isOn: $applyRecommendationToBottles
                    )
                        .toggleStyle(VectorCompactToggleStyle())
                        .disabled(bottles.isEmpty || metalProbe == nil)
                }
            }

            HStack(spacing: 10) {
                Button("Continue") {
                    let backend = applyRecommendationToBottles
                        ? (metalProbe?.recommendedBackend ?? .auto)
                        : .auto
                    onComplete(backend)
                }
                .buttonStyle(VectorPrimaryPanelButtonStyle())
            }
        }
        .padding(16)
        .frame(width: 640)
        .vectorPanelSurface()
        .task {
            runEnvironmentValidation()
            runMetalProbe()
        }
    }

    private func runEnvironmentValidation() {
        var items: [OnboardingEnvironmentItem] = []
        let runtimeInstalled = VectorWineInstaller.isVectorWineInstalled()
        items.append(
            OnboardingEnvironmentItem(
                title: "Vector runtime",
                detail: runtimeInstalled ? "Installed" : "Missing runtime installation",
                success: runtimeInstalled
            )
        )

        let rosettaInstalled = Rosetta2.isRosettaInstalled
        items.append(
            OnboardingEnvironmentItem(
                title: "Rosetta 2",
                detail: rosettaInstalled ? "Available" : "Not detected",
                success: rosettaInstalled
            )
        )

        let logsWritable: Bool
        do {
            try FileManager.default.createDirectory(at: Wine.logsFolder, withIntermediateDirectories: true)
            logsWritable = true
        } catch {
            logsWritable = false
        }
        items.append(
            OnboardingEnvironmentItem(
                title: "Logs directory",
                detail: logsWritable ? "Writable" : "Cannot write to logs folder",
                success: logsWritable
            )
        )
        environmentItems = items
    }

    private func runMetalProbe() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            metalProbe = OnboardingMetalProbe(
                deviceName: "No Metal device",
                recommendedBackend: .wined3d,
                supportedFamilies: [],
                recommendation: "No Metal device detected. Use WineD3D fallback."
            )
            return
        }

        let families: [(String, MTLGPUFamily)] = [
            ("Mac 2", .mac2),
            ("Apple 7", .apple7),
            ("Apple 8", .apple8),
            ("Apple 9", .apple9)
        ]
        let supported = families
            .filter { device.supportsFamily($0.1) }
            .map(\.0)

        let backend: GraphicsBackendMode = supported.contains("Mac 2") ? .dxvk : .d3dMetal
        let recommendation: String
        if backend == .dxvk {
            recommendation =
                "DXVK is recommended for current GPU capability. Use D3D11 compatibility per-game if needed."
        } else {
            recommendation = "D3DMetal fallback is recommended for this GPU profile."
        }

        metalProbe = OnboardingMetalProbe(
            deviceName: device.name,
            recommendedBackend: backend,
            supportedFamilies: supported,
            recommendation: recommendation
        )
    }
}

private struct PatchUpdateFlowSheet: View {
    let candidates: [PatchUpdateCandidate]
    @Binding var selectedBottleURLs: Set<URL>
    @Binding var showSelectionList: Bool
    let applying: Bool
    let progress: Double
    let statusText: String
    let onClose: () -> Void
    let onUpdateAll: () -> Void
    let onUpdateSelection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Patch Updates Available")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white.opacity(0.94))

            Text("New patch manifests were detected for one or more bottles.")
                .font(.system(size: 13))
                .foregroundStyle(VectorPanelTokens.subtleText)

            VectorPanelCard {
                VStack(alignment: .leading, spacing: 10) {
                    VectorSectionHeader(title: "Detected Bottles")
                    ForEach(candidates) { candidate in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(candidate.bottleName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                                Text(
                                    candidate.remoteGeneratedAt.isEmpty
                                        ? "Version \(candidate.remoteVersion)"
                                        : candidate.remoteGeneratedAt
                                )
                                .font(.system(size: 11))
                                .foregroundStyle(VectorPanelTokens.subtleText)
                            }
                            Spacer()
                            if showSelectionList {
                                Toggle("", isOn: Binding(
                                    get: { selectedBottleURLs.contains(candidate.bottleURL) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedBottleURLs.insert(candidate.bottleURL)
                                        } else {
                                            selectedBottleURLs.remove(candidate.bottleURL)
                                        }
                                    }
                                ))
                                .labelsHidden()
                                .toggleStyle(.checkbox)
                            }
                        }
                    }
                }
            }

            if applying {
                ProgressView(value: progress, total: 1)
                    .progressViewStyle(.linear)
            }
            if !statusText.isEmpty {
                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(VectorPanelTokens.subtleText)
            }

            if showSelectionList {
                HStack(spacing: 10) {
                    Button("Update Selected") {
                        onUpdateSelection()
                    }
                    .buttonStyle(VectorPrimaryPanelButtonStyle())
                    .disabled(applying || selectedBottleURLs.isEmpty)

                    Button("Cancel Selection") {
                        showSelectionList = false
                    }
                    .buttonStyle(VectorPrimaryPanelButtonStyle())
                    .disabled(applying)
                }
            } else {
                HStack(spacing: 10) {
                    Button("Update All Bottles") {
                        onUpdateAll()
                    }
                    .buttonStyle(VectorPrimaryPanelButtonStyle())
                    .disabled(applying || candidates.isEmpty)

                    Button("Select Bottles") {
                        showSelectionList = true
                    }
                    .buttonStyle(VectorPrimaryPanelButtonStyle())
                    .disabled(applying || candidates.isEmpty)
                }
            }

            Button("Later") {
                onClose()
            }
            .buttonStyle(VectorDangerPanelButtonStyle())
            .disabled(applying)
        }
        .padding(16)
        .frame(width: 620)
        .vectorPanelSurface()
    }
}

#Preview {
    ContentView(showSetup: .constant(false))
        .environmentObject(BottleVM.shared)
}
// swiftlint:enable type_body_length file_length
