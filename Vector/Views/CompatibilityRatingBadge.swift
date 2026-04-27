//
//  CompatibilityRatingBadge.swift
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

struct CompatibilityRatingBadge: View {
    let rating: CompatibilityRating

    var body: some View {
        Text(rating.title)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        switch rating {
        case .playable:
            return Color.green.opacity(0.18)
        case .needsTweaks:
            return Color.orange.opacity(0.2)
        case .boots:
            return Color.yellow.opacity(0.2)
        case .broken:
            return Color.red.opacity(0.2)
        case .unsupported:
            return Color.gray.opacity(0.22)
        }
    }

    private var foregroundColor: Color {
        switch rating {
        case .playable:
            return .green
        case .needsTweaks:
            return .orange
        case .boots:
            return .yellow
        case .broken:
            return .red
        case .unsupported:
            return .secondary
        }
    }
}
