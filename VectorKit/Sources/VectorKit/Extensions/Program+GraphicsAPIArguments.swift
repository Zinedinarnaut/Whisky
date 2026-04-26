//
//  Program+GraphicsAPIArguments.swift
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

extension Program {
    enum GraphicsAPIKind {
        case d3d12
        case d3d11
        case vulkan
        case opengl
    }

    func normalizeGraphicsAPIArguments(arguments: inout [String]) {
        var selectedKind: GraphicsAPIKind?
        for argument in arguments {
            guard let kind = graphicsAPIKind(for: argument) else {
                continue
            }
            selectedKind = kind
        }

        guard let selectedKind else {
            return
        }

        let selectedFlag = preferredGraphicsAPIFlag(for: selectedKind, from: arguments)
        arguments.removeAll { graphicsAPIKind(for: $0) != nil }

        if let selectedFlag {
            arguments.append(selectedFlag)
        }
    }

    func preferredGraphicsAPIFlag(
        for kind: GraphicsAPIKind,
        from arguments: [String]
    ) -> String? {
        let matchingFlags = arguments.filter { graphicsAPIKind(for: $0) == kind }
        guard !matchingFlags.isEmpty else {
            return nil
        }

        if kind == .d3d12 {
            if let forced = matchingFlags.last(where: { $0.caseInsensitiveCompare("-force-d3d12") == .orderedSame }) {
                return forced
            }
        } else if kind == .d3d11 {
            if let forced = matchingFlags.last(where: { $0.caseInsensitiveCompare("-force-d3d11") == .orderedSame }) {
                return forced
            }
        }

        return matchingFlags.last
    }

    func graphicsAPIKind(for argument: String) -> GraphicsAPIKind? {
        switch argument.lowercased() {
        case "-dx12", "-d3d12", "-force-d3d12":
            return .d3d12
        case "-dx11", "-d3d11", "-force-d3d11":
            return .d3d11
        case "-vulkan":
            return .vulkan
        case "-opengl":
            return .opengl
        default:
            return nil
        }
    }
}
