//
//  BottleCreationView.swift
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

private enum BottleCreationTemplate: String, CaseIterable, Identifiable {
    case standard
    case gaming
    case windowsFidelity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .gaming:
            return "Gaming"
        case .windowsFidelity:
            return "Windows Fidelity"
        }
    }
}

struct BottleCreationView: View {
    @Binding var newlyCreatedBottleURL: URL?

    @State private var newBottleName: String = ""
    @State private var newBottleVersion: WinVersion = .win10
    @State private var newBottleURL: URL = UserDefaults.standard.url(forKey: "defaultBottleLocation")
                                           ?? BottleData.defaultBottleDir
    @State private var nameValid: Bool = false
    @State private var creationTemplate: BottleCreationTemplate = .standard
    @State private var autoInstallLaunchers: Bool = true
    @State private var autoPinLaunchers: Bool = true
    @State private var autoApplyKnownPatches: Bool = true
    @State private var enablePatchDispatch: Bool = true
    @State private var patchDispatchEndpointURL: String = BottleDispatchConfig.defaultEndpointURL

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("create.name", text: $newBottleName)
                    .onChange(of: newBottleName) { _, name in
                        nameValid = !name.isEmpty
                    }

                Picker("create.win", selection: $newBottleVersion) {
                    ForEach(WinVersion.allCases.reversed(), id: \.self) {
                        Text($0.pretty())
                    }
                }

                Picker("Bottle Profile", selection: $creationTemplate) {
                    ForEach(BottleCreationTemplate.allCases) { template in
                        Text(template.title).tag(template)
                    }
                }
                .help(
                    "Choose Standard for a basic bottle, Gaming for launcher + patch automation, "
                    + "or Windows Fidelity for installer-safe defaults."
                )

                if creationTemplate == .gaming {
                    Toggle("Auto-install launcher installers", isOn: $autoInstallLaunchers)
                        .help(
                            "Downloads Steam, Epic, Ubisoft Connect, and GOG installers "
                            + "into the bottle and runs unattended install where available."
                        )
                    Toggle("Auto-pin launchers", isOn: $autoPinLaunchers)
                        .help(
                            "Pins detected launcher executables and downloaded installers "
                            + "so they are immediately accessible."
                        )
                    Toggle("Auto-apply known game patches", isOn: $autoApplyKnownPatches)
                        .help("Seeds this bottle with built-in compatibility profiles for supported games.")
                    Toggle("Enable patch dispatch sync", isOn: $enablePatchDispatch)
                        .help(
                            "Fetches remote patch rules from the dispatch endpoint and "
                            + "merges them into game profiles."
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Patch dispatch endpoint")
                        TextField(BottleDispatchConfig.defaultEndpointURL, text: $patchDispatchEndpointURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .disabled(!enablePatchDispatch)
                    }
                    .help("HTTPS endpoint that serves JSON patch rules for this bottle.")
                }

                if creationTemplate == .windowsFidelity {
                    Text(
                        "Windows Fidelity enables installer compatibility mode and "
                        + "runtime DLL verify+repair defaults."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                ActionView(
                    text: "create.path",
                    subtitle: newBottleURL.prettyPath(),
                    actionName: "create.browse"
                ) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.canCreateDirectories = true
                    panel.directoryURL = BottleData.containerDir
                    panel.begin { result in
                        if result == .OK, let url = panel.urls.first {
                            newBottleURL = url
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("create.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("create.cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("create.create") {
                        submit()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!nameValid)
                }
            }
            .onSubmit {
                submit()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: ViewWidth.small)
    }

    func submit() {
        let options: BottleCreationOptions
        if creationTemplate == .gaming {
            options = BottleCreationOptions(
                gamingModeEnabled: true,
                windowsFidelityModeEnabled: false,
                autoInstallLaunchers: autoInstallLaunchers,
                autoPinLaunchers: autoPinLaunchers,
                autoApplyKnownGamePatches: autoApplyKnownPatches,
                enablePatchDispatch: enablePatchDispatch,
                patchDispatchEndpointURL: patchDispatchEndpointURL,
                installerCompatibilityMode: false,
                preferredRuntimeDLLSyncMode: .verifyOnly,
                preferCompatibilityRuntime: false
            )
        } else if creationTemplate == .windowsFidelity {
            options = .windowsFidelity
        } else {
            options = .standard
        }

        newlyCreatedBottleURL = BottleVM.shared.createNewBottle(bottleName: newBottleName,
                                                                winVersion: newBottleVersion,
                                                                bottleURL: newBottleURL,
                                                                options: options)
        dismiss()
    }
}

#Preview {
    BottleCreationView(newlyCreatedBottleURL: .constant(nil))
}
