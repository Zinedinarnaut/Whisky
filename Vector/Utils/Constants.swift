//
//  Constants.swift
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
import VectorKit

enum ViewWidth {
    static let small: Double = 400
    static let medium: Double = 500
    static let large: Double = 600
}

enum CompatibilityRating: String, CaseIterable, Identifiable {
    case playable
    case needsTweaks
    case boots
    case broken
    case unsupported

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playable:
            return "Playable"
        case .needsTweaks:
            return "Needs Tweaks"
        case .boots:
            return "Boots"
        case .broken:
            return "Broken"
        case .unsupported:
            return "Unsupported"
        }
    }

    var sortIndex: Int {
        switch self {
        case .playable:
            return 0
        case .needsTweaks:
            return 1
        case .boots:
            return 2
        case .broken:
            return 3
        case .unsupported:
            return 4
        }
    }
}

struct CompatibilityGame: Identifiable, Hashable {
    let id: String
    let title: String
    let store: String
    let appID: String?
    let rating: CompatibilityRating
    let recommendedArguments: String
    let recommendedPreset: String
    let notes: [String]
    let confidence: Double
    let tags: [String]
    let lastVerifiedOn: String
    let trustClassification: GameTrustClassification
    let antiCheatProvider: String?
    let officialSupportRequired: Bool
    let fallbackPlayOptions: [String]
    let supportContactStatus: String
    let localProfileName: String?
    let remoteVecPatchRuleID: String?
    let dependencyRepairs: [String]

    var hasLocalProfile: Bool {
        !(localProfileName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasRemoteVecPatchRule: Bool {
        !(remoteVecPatchRuleID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasDependencyRepairs: Bool {
        !dependencyRepairs.isEmpty
    }

    var searchableTags: [String] {
        var orderedTags = tags
        orderedTags.append(hasLocalProfile ? "local-profile" : "no-local-profile")
        orderedTags.append(hasRemoteVecPatchRule ? "remote-vecpatch" : "no-remote-rule")
        orderedTags.append(hasDependencyRepairs ? "dependency-repair" : "no-dedicated-repair")
        if officialSupportRequired {
            orderedTags.append("official-support-required")
        }
        if trustClassification == .blockedAntiCheat || trustClassification == .protectedMultiplayer {
            orderedTags.append("protected")
            orderedTags.append("blocked")
        }
        return orderedTags.reduce(into: []) { result, tag in
            if !result.contains(tag) {
                result.append(tag)
            }
        }
    }

    init(
        id: String,
        title: String,
        store: String,
        appID: String?,
        rating: CompatibilityRating,
        recommendedArguments: String,
        recommendedPreset: String,
        notes: [String],
        confidence: Double = 0.7,
        tags: [String] = [],
        lastVerifiedOn: String = "2026-04-28",
        trustClassification: GameTrustClassification = .singlePlayer,
        antiCheatProvider: String? = nil,
        officialSupportRequired: Bool = false,
        fallbackPlayOptions: [String] = [],
        supportContactStatus: String = "",
        localProfileName: String? = nil,
        remoteVecPatchRuleID: String? = nil,
        dependencyRepairs: [String] = []
    ) {
        self.id = id
        self.title = title
        self.store = store
        self.appID = appID
        self.rating = rating
        self.recommendedArguments = recommendedArguments
        self.recommendedPreset = recommendedPreset
        self.notes = notes
        self.confidence = min(1, max(0, confidence))
        self.tags = tags
        self.lastVerifiedOn = lastVerifiedOn
        self.trustClassification = trustClassification
        self.antiCheatProvider = antiCheatProvider
        self.officialSupportRequired = officialSupportRequired
        self.fallbackPlayOptions = fallbackPlayOptions
        self.supportContactStatus = supportContactStatus
        self.localProfileName = localProfileName
        self.remoteVecPatchRuleID = remoteVecPatchRuleID
        self.dependencyRepairs = dependencyRepairs
    }
}
