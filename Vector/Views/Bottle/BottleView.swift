//
//  BottleView.swift
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
import UniformTypeIdentifiers
import VectorKit

enum BottleStage {
    case config
    case programs
    case processes
}

struct BottleView: View {
    @ObservedObject var bottle: Bottle
    @State private var path = NavigationPath()
    @State private var programLoading: Bool = false
    @State private var showWinetricksSheet: Bool = false

    private let gridLayout = [GridItem(.adaptive(minimum: 100, maximum: .infinity))]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VectorPanelCard {
                        VStack(alignment: .leading, spacing: 12) {
                            VectorSectionHeader(title: "Pinned Apps")
                            LazyVGrid(columns: gridLayout, alignment: .leading, spacing: 10) {
                                ForEach(bottle.pinnedPrograms, id: \.id) { pinnedProgram in
                                    PinView(
                                        bottle: bottle,
                                        program: pinnedProgram.program,
                                        pin: pinnedProgram.pin,
                                        path: $path
                                    )
                                }
                                PinAddView(bottle: bottle)
                            }
                        }
                    }

                    VectorPanelCard {
                        VStack(alignment: .leading, spacing: 8) {
                            VectorSectionHeader(title: "Bottle Controls")
                            VStack(spacing: 2) {
                                NavigationLink(value: BottleStage.programs) {
                                    BottleControlNavigationRow(icon: "list.bullet", title: "Programs")
                                }
                                NavigationLink(value: BottleStage.config) {
                                    BottleControlNavigationRow(icon: "gearshape", title: "Configuration")
                                }
                                NavigationLink(value: BottleStage.processes) {
                                    BottleControlNavigationRow(icon: "hockey.puck.circle", title: "Running Processes")
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(VectorPanelTokens.background)
            .bottomBar {
                HStack {
                    Spacer()
                    Button("button.cDrive") {
                        bottle.openCDrive()
                    }
                    Button("button.terminal") {
                        bottle.openTerminal()
                    }
                    Button("button.winetricks") {
                        showWinetricksSheet.toggle()
                    }
                    Button("button.run") {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = false
                        panel.canChooseFiles = true
                        panel.allowedContentTypes = [UTType.exe,
                                                     UTType(exportedAs: "com.microsoft.msi-installer"),
                                                     UTType(exportedAs: "com.microsoft.bat")]
                        panel.directoryURL = bottle.url.appending(path: "drive_c")
                        panel.begin { result in
                            programLoading = true
                            Task(priority: .userInitiated) {
                                if result == .OK {
                                    if let url = panel.urls.first {
                                        do {
                                            if url.pathExtension == "bat" {
                                                try await Wine.runBatchFile(url: url, bottle: bottle)
                                            } else {
                                                try await Wine.runProgram(at: url, bottle: bottle)
                                            }
                                        } catch {
                                            print("Failed to run external program: \(error)")
                                        }
                                        programLoading = false
                                    }
                                } else {
                                    programLoading = false
                                }
                                updateStartMenu()
                            }
                        }
                    }
                    .disabled(programLoading)
                    if programLoading {
                        Spacer()
                            .frame(width: 10)
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding()
            }
            .onAppear {
                updateStartMenu()
            }
            .disabled(!bottle.isAvailable)
            .navigationTitle(bottle.settings.name)
            .sheet(isPresented: $showWinetricksSheet) {
                WinetricksView(bottle: bottle)
            }
            .onChange(of: bottle.settings) { oldValue, newValue in
                guard oldValue != newValue else { return }
                // Trigger a reload
                BottleVM.shared.bottles = BottleVM.shared.bottles
            }
            .navigationDestination(for: BottleStage.self) { stage in
                switch stage {
                case .config:
                    ConfigView(bottle: bottle)
                case .programs:
                    ProgramsView(
                        bottle: bottle, path: $path
                    )
                case .processes:
                    RunningProcessesView(bottle: bottle)
                }
            }
            .navigationDestination(for: Program.self) { program in
                ProgramView(program: program)
            }
        }
    }

    private func updateStartMenu() {
        bottle.updateInstalledPrograms()

        let startMenuPrograms = bottle.getStartMenuPrograms()
        for startMenuProgram in startMenuPrograms {
            for program in bottle.programs where
            // For some godforsaken reason "foo/bar" != "foo/Bar" so...
            program.url.path().caseInsensitiveCompare(startMenuProgram.url.path()) == .orderedSame {
                program.pinned = true
                guard !bottle.settings.pins.contains(where: { $0.url == program.url }) else { return }
                bottle.settings.pins.append(PinnedProgram(
                    name: program.url.deletingPathExtension().lastPathComponent,
                    url: program.url
                ))
            }
        }
    }
}

private struct BottleControlNavigationRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VectorPanelTokens.subtleText)
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(Color.white.opacity(0.001), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
