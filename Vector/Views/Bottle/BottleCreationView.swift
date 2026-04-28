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

    @AppStorage("defaultBottleLocation") private var defaultBottleLocation = BottleData.defaultBottleDir

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
    @State private var saveLocationAsDefault: Bool = false

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

                Section("Storage") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bottle location")
                                Text(newBottleURL.prettyPath())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Button("Default") {
                                newBottleURL = defaultBottleLocation
                            }
                            Button("Choose...") {
                                chooseBottleLocation()
                            }
                        }

                        Toggle("Use this location as my default", isOn: $saveLocationAsDefault)

                        Text(storageLocationStatus.message)
                            .font(.caption)
                            .foregroundColor(storageLocationStatus.textColor)
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
                    .disabled(!nameValid || !storageLocationStatus.isUsable)
                }
            }
            .onSubmit {
                submit()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: ViewWidth.small)
    }

    private var storageLocationStatus: BottleStorageLocationStatus {
        BottleStorageLocationStatus(url: newBottleURL)
    }

    private func chooseBottleLocation() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = newBottleURL
        panel.prompt = "Use Location"
        panel.message = "Choose where Vector should store this bottle. External drives are supported."
        panel.begin { result in
            if result == .OK, let url = panel.urls.first {
                newBottleURL = url
            }
        }
    }

    func submit() {
        guard nameValid, storageLocationStatus.isUsable else {
            return
        }

        if saveLocationAsDefault {
            defaultBottleLocation = newBottleURL
        }

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

private struct BottleStorageLocationStatus {
    var isUsable: Bool
    var isWarning: Bool
    var message: String
    var textColor: Color {
        if !isUsable {
            return .red
        }
        return isWarning ? .orange : .secondary
    }

    init(url: URL) {
        let fileManager = FileManager.default
        let path = url.path(percentEncoded: false)
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue {
            self.isUsable = false
            self.isWarning = false
            self.message = "Selected location is a file, not a folder."
            return
        }

        let validationURL = fileManager.fileExists(atPath: path) ? url : url.deletingLastPathComponent()
        let validationPath = validationURL.path(percentEncoded: false)
        guard fileManager.fileExists(atPath: validationPath),
              fileManager.isWritableFile(atPath: validationPath) else {
            self.isUsable = false
            self.isWarning = false
            self.message = "Vector cannot write to this location."
            return
        }

        let values = try? validationURL.resourceValues(
            forKeys: [.volumeNameKey, .volumeIsInternalKey, .volumeAvailableCapacityForImportantUsageKey]
        )
        let volumeName = values?.volumeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let locationKind = values?.volumeIsInternal == false ? "External storage" : "Local storage"
        let freeBytes = values?.volumeAvailableCapacityForImportantUsage
        let freeSpace = freeBytes.map {
            ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
        }

        if let freeBytes, freeBytes < 10_000_000_000 {
            self.isUsable = false
            self.isWarning = false
            self.message = "\(locationKind) has only \(freeSpace ?? "limited space") available."
            return
        }

        let details = [locationKind, volumeName, freeSpace.map { "\($0) available" }]
            .compactMap { $0 }
            .joined(separator: " - ")

        self.isUsable = true
        self.isWarning = (freeBytes ?? 40_000_000_000) < 30_000_000_000
        let prefix = isWarning ? "Low free space - " : ""
        self.message = details.isEmpty ? "Ready to create bottles here." : "\(prefix)\(details)"
    }
}

#Preview {
    BottleCreationView(newlyCreatedBottleURL: .constant(nil))
}
