//
//  VectorWineInstallView.swift
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

struct VectorWineInstallView: View {
    @State var installing: Bool = true
    @State var error: Error?
    @Binding var tarLocation: URL
    @Binding var runtimeManifest: VectorWineRuntimeManifest?
    @Binding var path: [SetupStage]
    @Binding var showSetup: Bool

    var body: some View {
        VStack {
            VStack {
                Text("setup.vectorwine.install")
                    .font(.title)
                    .fontWeight(.bold)
                Text("setup.vectorwine.install.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if installing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 80)
                } else if let error {
                    Image(systemName: "xmark.octagon")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.red)
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.top, 4)
                } else {
                    Image(systemName: "checkmark.circle")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.green)
                }
                Spacer()
            }
            Spacer()
        }
        .frame(width: 400, height: 200)
        .onAppear {
            Task.detached {
                do {
                    try await VectorWineInstaller.install(from: tarLocation, manifest: runtimeManifest)
                    await MainActor.run {
                        installing = false
                    }
                    sleep(2)
                    await proceed()
                } catch {
                    await MainActor.run {
                        installing = false
                        self.error = error
                    }
                }
            }
        }
    }

    @MainActor
    func proceed() {
        showSetup = false
    }
}
