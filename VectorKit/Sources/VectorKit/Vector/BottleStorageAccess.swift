//
//  BottleStorageAccess.swift
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
import os.log

public enum BottleStorageAccess {
    private static let bookmarksDefaultsKey = "BottleStorageSecurityScopedBookmarks"
    nonisolated(unsafe) private static var activeAccessPaths = Set<String>()
    private static let lock = NSLock()

    public static func saveBookmark(for url: URL) {
        let standardizedURL = url.standardizedFileURL
        let path = standardizedURL.path(percentEncoded: false)
        guard !path.hasPrefix(BottleData.containerDir.path(percentEncoded: false)) else {
            return
        }

        do {
            let data = try standardizedURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = storedBookmarks()
            bookmarks[path] = data
            UserDefaults.standard.set(bookmarks, forKey: bookmarksDefaultsKey)
        } catch {
            Logger.wineKit.warning("Failed to save bottle storage bookmark for \(path, privacy: .public)")
        }
    }

    @discardableResult
    public static func startAccessingIfNeeded(for url: URL) -> Bool {
        let requestedPath = url.standardizedFileURL.path(percentEncoded: false)
        guard !requestedPath.hasPrefix(BottleData.containerDir.path(percentEncoded: false)) else {
            return true
        }

        guard let bookmark = closestBookmark(for: requestedPath) else {
            return false
        }

        lock.lock()
        if activeAccessPaths.contains(bookmark.path) {
            lock.unlock()
            return true
        }
        lock.unlock()

        do {
            var stale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmark.data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            if stale {
                saveBookmark(for: resolvedURL)
            }
            let didStart = resolvedURL.startAccessingSecurityScopedResource()
            if didStart {
                lock.lock()
                activeAccessPaths.insert(bookmark.path)
                lock.unlock()
            }
            return didStart
        } catch {
            Logger.wineKit.warning("Failed to resolve bottle storage bookmark for \(requestedPath, privacy: .public)")
            return false
        }
    }
}

private extension BottleStorageAccess {
    static func storedBookmarks() -> [String: Data] {
        UserDefaults.standard.dictionary(forKey: bookmarksDefaultsKey) as? [String: Data] ?? [:]
    }

    static func closestBookmark(for path: String) -> (path: String, data: Data)? {
        let match = storedBookmarks()
            .filter { path.hasPrefix($0.key) }
            .sorted { $0.key.count > $1.key.count }
            .first
        guard let match else {
            return nil
        }
        return (path: match.key, data: match.value)
    }
}
