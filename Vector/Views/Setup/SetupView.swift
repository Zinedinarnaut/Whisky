//
//  SetupView.swift
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

enum SetupStage {
    case rosetta
    case vectorWineDownload
    case vectorWineInstall
}

struct SetupView: View {
    @State private var path: [SetupStage] = []
    @State var tarLocation: URL = URL(fileURLWithPath: "")
    @State var runtimeManifest: VectorWineRuntimeManifest?
    @Binding var showSetup: Bool
    var firstTime: Bool = true

    var body: some View {
        VStack {
            NavigationStack(path: $path) {
                WelcomeView(path: $path, showSetup: $showSetup, firstTime: firstTime)
                    .navigationBarBackButtonHidden(true)
                    .navigationDestination(for: SetupStage.self) { stage in
                        switch stage {
                        case .rosetta:
                            RosettaView(path: $path, showSetup: $showSetup)
                        case .vectorWineDownload:
                            VectorWineDownloadView(
                                tarLocation: $tarLocation,
                                runtimeManifest: $runtimeManifest,
                                path: $path
                            )
                        case .vectorWineInstall:
                            VectorWineInstallView(
                                tarLocation: $tarLocation,
                                runtimeManifest: $runtimeManifest,
                                path: $path,
                                showSetup: $showSetup
                            )
                        }
                    }
            }
        }
        .padding()
        .interactiveDismissDisabled()
    }
}
