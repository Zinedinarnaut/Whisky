//
//  Bottle+Extensions.swift
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

import Foundation
import AppKit
import VectorKit
import os.log

// swiftlint:disable file_length

private struct InstalledProgramFilesystemCacheEntry {
    let signature: Int
    let executableURLs: [URL]
}

private enum InstalledProgramFilesystemCache {
    private static let lock = NSLock()
    private static nonisolated(unsafe) var entries: [String: InstalledProgramFilesystemCacheEntry] = [:]

    static func entry(for bottleURL: URL) -> InstalledProgramFilesystemCacheEntry? {
        lock.lock()
        defer { lock.unlock() }
        return entries[bottleURL.path(percentEncoded: false)]
    }

    static func store(_ entry: InstalledProgramFilesystemCacheEntry, for bottleURL: URL) {
        lock.lock()
        entries[bottleURL.path(percentEncoded: false)] = entry
        lock.unlock()
    }

    static func invalidate(for bottleURL: URL) {
        lock.lock()
        entries.removeValue(forKey: bottleURL.path(percentEncoded: false))
        lock.unlock()
    }
}

extension Bottle {
    private var snapshotsDirectory: URL {
        url.appending(path: "Snapshots")
    }

    func openCDrive() {
        NSWorkspace.shared.open(url.appending(path: "drive_c"))
    }

    func openSnapshotsDirectory() {
        do {
            try FileManager.default.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(snapshotsDirectory)
        } catch {
            print("Failed to open snapshots directory")
        }
    }

    @discardableResult
    func createSnapshotArchive() throws -> URL {
        try FileManager.default.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let snapshotName = "\(settings.name)-\(formatter.string(from: .now)).tar.gz"
        let snapshotURL = snapshotsDirectory.appending(path: snapshotName)

        try runTarProcess(arguments: [
            "-zcf",
            snapshotURL.path(percentEncoded: false),
            "-C",
            url.deletingLastPathComponent().path(percentEncoded: false),
            url.lastPathComponent
        ])

        VectorNotifications.notifySnapshotCreated(settings.name)
        return snapshotURL
    }

    @discardableResult
    func restoreLatestSnapshotArchive() throws -> URL {
        let snapshots = try FileManager.default.contentsOfDirectory(
            at: snapshotsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
            .filter { $0.pathExtension == "gz" }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return lhsDate > rhsDate
            }

        guard let latestSnapshot = snapshots.first else {
            throw NSError(domain: "VectorSnapshot", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "No snapshots found for this bottle."
            ])
        }

        try restoreSnapshotArchive(from: latestSnapshot)
        VectorNotifications.notifySnapshotRestored(settings.name)
        return latestSnapshot
    }

    func restoreSnapshotArchive(from snapshotURL: URL) throws {
        let parentDirectory = url.deletingLastPathComponent()
        let backupDirectory = parentDirectory.appending(path: "\(url.lastPathComponent)-restore-backup")

        if FileManager.default.fileExists(atPath: backupDirectory.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: backupDirectory)
        }

        try FileManager.default.moveItem(at: url, to: backupDirectory)

        do {
            try runTarProcess(arguments: [
                "-xzf",
                snapshotURL.path(percentEncoded: false),
                "-C",
                parentDirectory.path(percentEncoded: false)
            ])
            try FileManager.default.removeItem(at: backupDirectory)
        } catch {
            if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                try? FileManager.default.moveItem(at: backupDirectory, to: url)
            }
            throw error
        }
    }

    func openTerminal() {
        let vectorCmdURL = Bundle.main.url(forResource: "VectorCmd", withExtension: nil)
        if let vectorCmdURL = vectorCmdURL {
            let vectorCmd = vectorCmdURL.path(percentEncoded: false)
            let cmd = "eval \\\"$(\\\"\(vectorCmd)\\\" shellenv \\\"\(settings.name)\\\")\\\""

            let script = """
            tell application "Terminal"
            activate
            do script "\(cmd)"
            end tell
            """

            Task.detached(priority: .userInitiated) {
                var error: NSDictionary?
                guard let appleScript = NSAppleScript(source: script) else { return }
                appleScript.executeAndReturnError(&error)

                if let error = error {
                    Logger.wineKit.error("Failed to run terminal script \(error)")
                    guard let description = error["NSAppleScriptErrorMessage"] as? String else { return }
                    await self.showRunError(message: String(describing: description))
                }
            }
        }
    }

    @discardableResult
    func getStartMenuPrograms() -> [Program] {
        let globalStartMenu = url
            .appending(path: "drive_c")
            .appending(path: "ProgramData")
            .appending(path: "Microsoft")
            .appending(path: "Windows")
            .appending(path: "Start Menu")

        let userStartMenu = url
            .appending(path: "drive_c")
            .appending(path: "users")
            .appending(path: "crossover")
            .appending(path: "AppData")
            .appending(path: "Roaming")
            .appending(path: "Microsoft")
            .appending(path: "Windows")
            .appending(path: "Start Menu")

        var startMenuPrograms: [Program] = []
        var linkURLs: [URL] = []
        let globalEnumerator = FileManager.default.enumerator(at: globalStartMenu,
                                                              includingPropertiesForKeys: [.isRegularFileKey],
                                                              options: [.skipsHiddenFiles])
        while let url = globalEnumerator?.nextObject() as? URL {
            if url.pathExtension == "lnk" {
                linkURLs.append(url)
            }
        }

        let userEnumerator = FileManager.default.enumerator(at: userStartMenu,
                                                            includingPropertiesForKeys: [.isRegularFileKey],
                                                            options: [.skipsHiddenFiles])
        while let url = userEnumerator?.nextObject() as? URL {
            if url.pathExtension == "lnk" {
                linkURLs.append(url)
            }
        }

        linkURLs.sort(by: { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() })

        for link in linkURLs {
            do {
                if let program = ShellLinkHeader.getProgram(url: link,
                                                            handle: try FileHandle(forReadingFrom: link),
                                                            bottle: self) {
                    if !startMenuPrograms.contains(where: { $0.url == program.url }) {
                        startMenuPrograms.append(program)
                        try FileManager.default.removeItem(at: link)
                    }
                }
            } catch {
                print(error)
            }
        }

        return startMenuPrograms
    }

    func updateInstalledPrograms() {
        let signature = makeInstalledProgramScanSignature()
        let executableURLs = resolveCachedExecutableURLs(signature: signature)
        let blockedURLs = Set(settings.blocklist)
        let existingProgramsByURL = Dictionary(uniqueKeysWithValues: programs.map { ($0.url, $0) })

        var refreshedPrograms: [Program] = []
        var foundURLs: Set<URL> = []

        for executableURL in executableURLs {
            guard !blockedURLs.contains(executableURL) else { continue }
            foundURLs.insert(executableURL)
            if let existingProgram = existingProgramsByURL[executableURL] {
                refreshedPrograms.append(existingProgram)
            } else {
                refreshedPrograms.append(Program(url: executableURL, bottle: self))
            }
        }

        // Add missing programs from pins.
        for pin in settings.pins {
            guard let url = pin.url else { continue }
            guard !foundURLs.contains(url) else { continue }
            if let existingProgram = existingProgramsByURL[url] {
                refreshedPrograms.append(existingProgram)
            } else {
                refreshedPrograms.append(Program(url: url, bottle: self))
            }
        }

        self.programs = refreshedPrograms.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    @MainActor
    func move(destination: URL) {
        do {
            if let bottle = BottleVM.shared.bottles.first(where: { $0.url == url }) {
                bottle.inFlight = true
                for index in 0..<bottle.settings.pins.count {
                    let pin = bottle.settings.pins[index]
                    if let url = pin.url {
                        bottle.settings.pins[index].url = url.updateParentBottle(old: url,
                                                                                 new: destination)
                    }
                }

                for index in 0..<bottle.settings.blocklist.count {
                    let blockedUrl = bottle.settings.blocklist[index]
                    bottle.settings.blocklist[index] = blockedUrl.updateParentBottle(old: url,
                                                                                     new: destination)
                }
            }
            InstalledProgramFilesystemCache.invalidate(for: url)
            try FileManager.default.moveItem(at: url, to: destination)
            if let path = BottleVM.shared.bottlesList.paths.firstIndex(of: url) {
                BottleVM.shared.bottlesList.paths[path] = destination
            }
            BottleVM.shared.loadBottles()
            VectorNotifications.notifyBottleMoved(settings.name)
        } catch {
            print("Failed to move bottle")
            VectorNotifications.notifyBottleMoveFailed(settings.name, reason: error.localizedDescription)
        }
    }

    func exportAsArchive(destination: URL) {
        do {
            try Tar.tar(folder: url, toURL: destination)
            VectorNotifications.notifyBottleExported(settings.name)
        } catch {
            print("Failed to export bottle")
            VectorNotifications.notifyBottleExportFailed(settings.name, reason: error.localizedDescription)
        }
    }

    @MainActor
    func remove(delete: Bool) {
        do {
            if let bottle = BottleVM.shared.bottles.first(where: { $0.url == url }) {
                bottle.inFlight = true
            }
            InstalledProgramFilesystemCache.invalidate(for: url)

            if delete {
                try FileManager.default.removeItem(at: url)
            }

            if let path = BottleVM.shared.bottlesList.paths.firstIndex(of: url) {
                BottleVM.shared.bottlesList.paths.remove(at: path)
            }
            BottleVM.shared.loadBottles()
            VectorNotifications.notifyBottleRemoved(settings.name)
        } catch {
            print("Failed to remove bottle")
            VectorNotifications.notifyBottleRemoveFailed(settings.name, reason: error.localizedDescription)
        }
    }

    @MainActor
    func rename(newName: String) {
        settings.name = newName
    }

    @MainActor private func showRunError(message: String) {
        let alert = NSAlert()
        alert.messageText = String(localized: "alert.message")
        alert.informativeText = String(localized: "alert.info")
        + " \(self.url.lastPathComponent): "
        + message
        alert.alertStyle = .critical
        alert.addButton(withTitle: String(localized: "button.ok"))
        alert.runModal()
    }

    private func runTarProcess(arguments: [String]) throws {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/tar")
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
            let message = String(data: output, encoding: .utf8) ?? "Failed to run tar"
            throw NSError(domain: "VectorSnapshot", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: message
            ])
        }
    }

    func resolveCachedExecutableURLs(signature: Int) -> [URL] {
        if let cached = InstalledProgramFilesystemCache.entry(for: url),
           cached.signature == signature {
            return cached.executableURLs
        }

        let scannedURLs = scanInstalledExecutableURLs()
        InstalledProgramFilesystemCache.store(
            InstalledProgramFilesystemCacheEntry(signature: signature, executableURLs: scannedURLs),
            for: url
        )
        return scannedURLs
    }

    func scanInstalledExecutableURLs() -> [URL] {
        let driveC = url.appending(path: "drive_c")
        var foundURLs: Set<URL> = []

        for folderName in ["Program Files", "Program Files (x86)"] {
            let folderURL = driveC.appending(path: folderName)
            let enumerator = FileManager.default.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            while let discoveredURL = enumerator?.nextObject() as? URL {
                guard !discoveredURL.hasDirectoryPath else { continue }
                guard discoveredURL.pathExtension.caseInsensitiveCompare("exe") == .orderedSame else { continue }
                foundURLs.insert(discoveredURL)
            }
        }

        return foundURLs.sorted {
            $0.path(percentEncoded: false).localizedCaseInsensitiveCompare(
                $1.path(percentEncoded: false)
            ) == .orderedAscending
        }
    }

    func makeInstalledProgramScanSignature() -> Int {
        let driveC = url.appending(path: "drive_c")
        var hasher = Hasher()
        hashProgramDirectory(driveC.appending(path: "Program Files"), into: &hasher)
        hashProgramDirectory(driveC.appending(path: "Program Files (x86)"), into: &hasher)
        return hasher.finalize()
    }

    func hashProgramDirectory(_ directoryURL: URL, into hasher: inout Hasher) {
        let directoryPath = directoryURL.path(percentEncoded: false)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directoryPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            hasher.combine(directoryPath)
            hasher.combine(false)
            return
        }

        hasher.combine(directoryPath)
        hasher.combine(true)
        hasher.combine((try? directoryURL.resourceValues(forKeys: [.contentModificationDateKey]))
            .flatMap(\.contentModificationDate)?.timeIntervalSince1970 ?? 0)

        let children = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        hasher.combine(children.count)
        for childURL in children {
            let values = try? childURL.resourceValues(forKeys: [.nameKey, .isDirectoryKey, .contentModificationDateKey])
            hasher.combine(values?.name ?? childURL.lastPathComponent)
            hasher.combine(values?.isDirectory ?? false)
            hasher.combine(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)
        }
    }
}
