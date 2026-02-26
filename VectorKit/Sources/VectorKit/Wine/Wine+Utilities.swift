//
//  Wine+Utilities.swift
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

public extension Wine {
    static func wineVersion() async throws -> String {
        var output = try await runWine(["--version"], bottle: nil)
        output.replace("wine-", with: "")

        // Deal with WineCX version names.
        if let index = output.firstIndex(where: { $0.isWhitespace }) {
            return String(output.prefix(upTo: index))
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    static func runBatchFile(url: URL, bottle: Bottle) async throws -> String {
        try await runWine(["cmd", "/c", url.path(percentEncoded: false)], bottle: bottle)
    }
}
