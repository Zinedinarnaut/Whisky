//
//  BottleListEntry.swift
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
import UniformTypeIdentifiers

struct BottleListEntry: View {
    let bottle: Bottle
    @Binding var selected: URL?
    @Binding var refresh: Bool

    @State private var showBottleRename: Bool = false
    @State private var name: String = ""

    private var isSelected: Bool {
        selected == bottle.url
    }

    private var availabilityText: String {
        bottle.isAvailable ? "Ready" : "Missing"
    }

    private var availabilityTint: Color {
        bottle.isAvailable ? VectorPanelTokens.success : VectorPanelTokens.warning
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: bottle.isAvailable ? "shippingbox.fill" : "shippingbox")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .white.opacity(0.92) : VectorPanelTokens.subtleText)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(bottle.isAvailable ? 0.92 : 0.48))
                    .lineLimit(1)
                Text("Windows \(bottle.settings.windowsVersion.pretty())")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VectorPanelTokens.subtleText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Circle()
                .fill(availabilityTint.opacity(bottle.isAvailable ? 0.95 : 0.65))
                .frame(width: 7, height: 7)
                .help(availabilityText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: VectorPanelTokens.controlRadius, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VectorPanelTokens.controlRadius, style: .continuous)
                .stroke(isSelected ? VectorPanelTokens.border : Color.clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: VectorPanelTokens.controlRadius, style: .continuous))
            .opacity(bottle.isAvailable ? 1.0 : 0.5)
            .onChange(of: refresh, initial: true) {
                name = bottle.settings.name
            }
            .sheet(isPresented: $showBottleRename) {
                RenameView("rename.bottle.title", name: name) { newName in
                    name = newName
                    bottle.rename(newName: newName)
                }
            }
            .contextMenu {
                Button("button.rename", systemImage: "pencil.line") {
                    showBottleRename.toggle()
                }
                .disabled(!bottle.isAvailable)
                .labelStyle(.titleAndIcon)
                Button("button.removeAlert", systemImage: "trash") {
                    showRemoveAlert(bottle: bottle)
                }
                .labelStyle(.titleAndIcon)
                Divider()
                Button("button.moveBottle", systemImage: "shippingbox.and.arrow.backward") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.canCreateDirectories = true
                    panel.begin { result in
                        if result == .OK {
                            if let url = panel.urls.first {
                                let newBottePath = url
                                    .appending(path: bottle.url.lastPathComponent)

                                bottle.move(destination: newBottePath)
                                selected = newBottePath
                            }
                        }
                    }
                }
                .disabled(!bottle.isAvailable)
                .labelStyle(.titleAndIcon)
                Button("button.exportBottle", systemImage: "arrowshape.turn.up.right") {
                    let panel = NSSavePanel()
                    panel.canCreateDirectories = true
                    panel.allowedContentTypes = [UTType.gzip]
                    panel.allowsOtherFileTypes = false
                    panel.isExtensionHidden = false
                    panel.nameFieldStringValue = bottle.settings.name + ".tar"
                    panel.begin { result in
                        if result == .OK {
                            if let url = panel.url {
                                Task.detached(priority: .background) {
                                    bottle.exportAsArchive(destination: url)
                                }
                            }
                        }
                    }
                }
                .disabled(!bottle.isAvailable)
                .labelStyle(.titleAndIcon)
                Divider()
                Button("button.showInFinder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([bottle.url])
                }
                .disabled(!bottle.isAvailable)
                .labelStyle(.titleAndIcon)
            }
    }

    func showRemoveAlert(bottle: Bottle) {
        let checkbox = NSButton(checkboxWithTitle: String(localized: "button.removeAlert.checkbox"),
                                target: self, action: nil)
        let alert = NSAlert()
        alert.messageText = String(format: String(localized: "button.removeAlert.msg"),
                                   bottle.settings.name)
        alert.informativeText = String(localized: "button.removeAlert.info")
        alert.alertStyle = .warning
        let delete = alert.addButton(withTitle: String(localized: "button.removeAlert.delete"))
        delete.hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "button.removeAlert.cancel"))
        if bottle.isAvailable {
            alert.accessoryView = checkbox
        }

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            Task(priority: .userInitiated) {
                if selected == bottle.url {
                    selected = nil
                }

                bottle.remove(delete: checkbox.state == .on)
            }
        }
    }
}

#Preview {
    BottleListEntry(
        bottle: Bottle(bottleUrl: URL(filePath: "")),
        selected: .constant(nil),
        refresh: .constant(false)
    )
}
