//
//  SettingsView.swift
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
import UserNotifications
import VectorKit

struct SettingsView: View {
    @AppStorage("SUEnableAutomaticChecks") var vectorUpdate = true
    @AppStorage("killOnTerminate") var killOnTerminate = true
    @AppStorage("checkVectorWineUpdates") var checkVectorWineUpdates = true
    @AppStorage("defaultBottleLocation") var defaultBottleLocation = BottleData.defaultBottleDir
    @AppStorage(VectorNotifications.notificationsEnabledDefaultsKey) var notificationsEnabled = true
    @AppStorage("notificationsLaunchesEnabled") var notificationsLaunchesEnabled = true
    @AppStorage("notificationsBottleLifecycleEnabled") var notificationsBottleLifecycleEnabled = true
    @AppStorage("notificationsMaintenanceEnabled") var notificationsMaintenanceEnabled = true
    @AppStorage("VectorDeveloperToolsEnabled") var developerToolsEnabled = false

    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section("settings.general") {
                Toggle("settings.toggle.kill.on.terminate", isOn: $killOnTerminate)
                ActionView(
                    text: "settings.path",
                    subtitle: defaultBottleLocation.prettyPath(),
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
                            defaultBottleLocation = url
                        }
                    }
                }
            }
            Section("settings.updates") {
                Toggle("settings.toggle.vector.updates", isOn: $vectorUpdate)
                Toggle("settings.toggle.vectorwine.updates", isOn: $checkVectorWineUpdates)
            }

            Section("Notifications") {
                Toggle("Enable notifications", isOn: $notificationsEnabled)
                Toggle("Launch notifications", isOn: $notificationsLaunchesEnabled)
                    .disabled(!notificationsEnabled)
                Toggle("Bottle lifecycle notifications", isOn: $notificationsBottleLifecycleEnabled)
                    .disabled(!notificationsEnabled)
                Toggle("Maintenance notifications", isOn: $notificationsMaintenanceEnabled)
                    .disabled(!notificationsEnabled)

                HStack {
                    Text("Permission")
                    Spacer()
                    Text(notificationPermissionLabel)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button("Request Permission") {
                        Task {
                            _ = await VectorNotifications.requestAuthorization()
                            await refreshNotificationAuthorizationStatus()
                        }
                    }
                    .disabled(
                        notificationAuthorizationStatus == .authorized
                            || notificationAuthorizationStatus == .provisional
                    )

                    Button("Send Test Notification") {
                        VectorNotifications.sendTestNotification()
                    }
                    .disabled(!notificationsEnabled)
                }
            }

#if DEBUG
            Section("Developer") {
                Toggle("Developer Mode", isOn: $developerToolsEnabled)
                Text(
                    "Enables Wine memory tooling for single-player/debug bottles only. "
                        + "Protected multiplayer titles stay locked."
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
#endif
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: ViewWidth.medium)
        .task {
            await refreshNotificationAuthorizationStatus()
        }
        .onChange(of: notificationsEnabled) {
            if notificationsEnabled {
                Task {
                    await refreshNotificationAuthorizationStatus()
                }
            }
        }
    }

    private var notificationPermissionLabel: String {
        switch notificationAuthorizationStatus {
        case .notDetermined:
            return "Not requested"
        case .denied:
            return "Denied"
        case .authorized:
            return "Allowed"
        case .provisional:
            return "Provisional"
        @unknown default:
            return "Unknown"
        }
    }

    private func refreshNotificationAuthorizationStatus() async {
        notificationAuthorizationStatus = await VectorNotifications.authorizationStatus()
    }
}

#Preview {
    SettingsView()
}
