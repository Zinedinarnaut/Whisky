//
//  VectorWineRuntimeManifest.swift
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
import SemanticVersion

public struct VectorWineRuntimeManifest: Codable, Sendable {
    public let version: String
    public let archiveURL: URL
    public let archiveSHA256: String
    public let wineVersion: String
    public let dxvkVersion: String
    public let d3dMetalVersion: String
    public let winetricksVersion: String
    public let wineMonoVersion: String
    public var runtimeChannel: String?
    public var buildID: String?
    public var createdAt: String?
    public var vectorVMCTLSHA256: String?

    public init(
        version: String,
        archiveURL: URL,
        archiveSHA256: String,
        wineVersion: String,
        dxvkVersion: String,
        d3dMetalVersion: String,
        winetricksVersion: String,
        wineMonoVersion: String,
        runtimeChannel: String? = nil,
        buildID: String? = nil,
        createdAt: String? = nil,
        vectorVMCTLSHA256: String? = nil
    ) {
        self.version = version
        self.archiveURL = archiveURL
        self.archiveSHA256 = archiveSHA256
        self.wineVersion = wineVersion
        self.dxvkVersion = dxvkVersion
        self.d3dMetalVersion = d3dMetalVersion
        self.winetricksVersion = winetricksVersion
        self.wineMonoVersion = wineMonoVersion
        self.runtimeChannel = runtimeChannel
        self.buildID = buildID
        self.createdAt = createdAt
        self.vectorVMCTLSHA256 = vectorVMCTLSHA256
    }

    public var semanticVersion: SemanticVersion {
        SemanticVersion(version) ?? SemanticVersion(0, 0, 0)
    }

    public var semanticWineVersion: SemanticVersion? {
        SemanticVersion(wineVersion)
    }
}
