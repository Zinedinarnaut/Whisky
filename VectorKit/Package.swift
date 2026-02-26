// swift-tools-version: 5.9
//
//  PortableExecutable.swift
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

import PackageDescription

let package = Package(
    name: "VectorKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VectorKit",
            targets: ["VectorKit"]
        )
    ],
    dependencies: [
      .package(url: "https://github.com/SwiftPackageIndex/SemanticVersion.git", from: "0.5.1")
    ],
    targets: [
        .target(
            name: "VectorKit",
            dependencies: ["SemanticVersion"]
        )
    ],
    swiftLanguageVersions: [.version("6")]
)
