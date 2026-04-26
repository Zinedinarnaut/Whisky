//
//  VectorNotifications.swift
//  VectorKit
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

import Foundation
import UserNotifications

public enum VectorNotificationCategory: String, CaseIterable, Sendable {
    case launches
    case bottleLifecycle
    case maintenance

    fileprivate var defaultsKey: String {
        switch self {
        case .launches:
            return "notificationsLaunchesEnabled"
        case .bottleLifecycle:
            return "notificationsBottleLifecycleEnabled"
        case .maintenance:
            return "notificationsMaintenanceEnabled"
        }
    }
}

public enum VectorNotifications {
    public static let notificationsEnabledDefaultsKey = "notificationsEnabled"

    private static let categoryIdentifier = "com.isaacmarovitz.Vector.general"

    public static func configure() {
        registerDefaults()
        Task { @MainActor in
            UNUserNotificationCenter.current().delegate = VectorNotificationCenterDelegateStore.shared.delegate
        }
    }

    public static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            notificationsEnabledDefaultsKey: true,
            VectorNotificationCategory.launches.defaultsKey: true,
            VectorNotificationCategory.bottleLifecycle.defaultsKey: true,
            VectorNotificationCategory.maintenance.defaultsKey: true
        ])
    }

    public static func isCategoryEnabled(_ category: VectorNotificationCategory) -> Bool {
        UserDefaults.standard.bool(forKey: category.defaultsKey)
    }

    public static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    public static func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    public static func sendTestNotification() {
        post(
            category: .maintenance,
            title: "Vector notifications enabled",
            body: "You will now get launch, bottle, and maintenance notifications."
        )
    }

    public static func notifyLaunchStarted(programName: String, bottleName: String) {
        post(
            category: .launches,
            title: "Launch started",
            body: "\(programName) is launching in \(bottleName)."
        )
    }

    public static func notifyLaunchSucceeded(programName: String, bottleName: String) {
        post(
            category: .launches,
            title: "Launch command sent",
            body: "\(programName) was handed off to Wine in \(bottleName)."
        )
    }

    public static func notifyLaunchFailed(programName: String, bottleName: String, reason: String) {
        post(
            category: .launches,
            title: "Launch failed",
            body: "\(programName) in \(bottleName) failed: \(reason)"
        )
    }

    public static func notifyBottleCreated(_ bottleName: String) {
        post(
            category: .bottleLifecycle,
            title: "Bottle created",
            body: "\(bottleName) is ready."
        )
    }

    public static func notifyBottleCreationFailed(_ bottleName: String, reason: String) {
        post(
            category: .bottleLifecycle,
            title: "Bottle creation failed",
            body: "\(bottleName) could not be created: \(reason)"
        )
    }

    public static func notifyBottleMoved(_ bottleName: String) {
        post(
            category: .bottleLifecycle,
            title: "Bottle moved",
            body: "\(bottleName) was moved successfully."
        )
    }

    public static func notifyBottleMoveFailed(_ bottleName: String, reason: String) {
        post(
            category: .bottleLifecycle,
            title: "Bottle move failed",
            body: "\(bottleName) could not be moved: \(reason)"
        )
    }

    public static func notifyBottleRemoved(_ bottleName: String) {
        post(
            category: .bottleLifecycle,
            title: "Bottle removed",
            body: "\(bottleName) was removed from Vector."
        )
    }

    public static func notifyBottleRemoveFailed(_ bottleName: String, reason: String) {
        post(
            category: .bottleLifecycle,
            title: "Bottle remove failed",
            body: "\(bottleName) could not be removed: \(reason)"
        )
    }

    public static func notifyBottleExported(_ bottleName: String) {
        post(
            category: .bottleLifecycle,
            title: "Bottle exported",
            body: "\(bottleName) archive export completed."
        )
    }

    public static func notifyBottleExportFailed(_ bottleName: String, reason: String) {
        post(
            category: .bottleLifecycle,
            title: "Bottle export failed",
            body: "\(bottleName) export failed: \(reason)"
        )
    }

    public static func notifySnapshotCreated(_ bottleName: String) {
        post(
            category: .maintenance,
            title: "Snapshot created",
            body: "A snapshot was created for \(bottleName)."
        )
    }

    public static func notifySnapshotRestored(_ bottleName: String) {
        post(
            category: .maintenance,
            title: "Snapshot restored",
            body: "Latest snapshot for \(bottleName) was restored."
        )
    }

    public static func notifyMaintenanceStarted(task: String, bottleName: String) {
        post(
            category: .maintenance,
            title: "Maintenance started",
            body: "\(task) started for \(bottleName)."
        )
    }

    public static func notifyMaintenanceFailed(task: String, bottleName: String, reason: String) {
        post(
            category: .maintenance,
            title: "Maintenance failed",
            body: "\(task) failed for \(bottleName): \(reason)"
        )
    }

    public static func notifyMaintenanceCompleted(task: String, bottleName: String) {
        post(
            category: .maintenance,
            title: "Maintenance complete",
            body: "\(task) completed for \(bottleName)."
        )
    }

    public static func notifyPatchSyncCompleted(_ bottleName: String) {
        post(
            category: .maintenance,
            title: "Patch update complete",
            body: "Dispatch patches were applied to \(bottleName)."
        )
    }

    public static func notifyPatchSyncFailed(_ bottleName: String, reason: String) {
        post(
            category: .maintenance,
            title: "Patch update failed",
            body: "Dispatch patch update failed for \(bottleName): \(reason)"
        )
    }

    private static func post(category: VectorNotificationCategory, title: String, body: String) {
        guard shouldSendNotification(for: category) else {
            return
        }

        Task.detached(priority: .utility) {
            let status = await authorizationStatus()
            switch status {
            case .authorized, .provisional:
                await enqueueNotification(title: title, body: body, category: category)
            case .notDetermined:
                let granted = await requestAuthorization()
                guard granted else { return }
                await enqueueNotification(title: title, body: body, category: category)
            case .denied:
                return
            @unknown default:
                return
            }
        }
    }

    private static func shouldSendNotification(for category: VectorNotificationCategory) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: notificationsEnabledDefaultsKey) else {
            return false
        }
        return defaults.bool(forKey: category.defaultsKey)
    }

    private static func enqueueNotification(title: String, body: String, category: VectorNotificationCategory) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.threadIdentifier = "vector.\(category.rawValue)"

        let request = UNNotificationRequest(
            identifier: "vector.\(category.rawValue).\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            return
        }
    }
}

@MainActor
private final class VectorNotificationCenterDelegateStore {
    static let shared = VectorNotificationCenterDelegateStore()
    let delegate = VectorNotificationCenterDelegate()
}

private final class VectorNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
