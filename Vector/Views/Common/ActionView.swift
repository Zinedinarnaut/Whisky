//
//  ActionView.swift
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

struct ActionView: View {
    let text: LocalizedStringKey
    let subtitle: String
    let actionName: LocalizedStringKey
    let action: () -> Void

    init(
        text: LocalizedStringKey,
        subtitle: String = "",
        actionName: LocalizedStringKey,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.subtitle = subtitle
        self.actionName = actionName
        self.action = action
    }

    var body: some View {
        HStack(alignment: subtitle.isEmpty ? .center : .top) {
            VStack(alignment: .leading) {
                Text(text)
                    .foregroundStyle(.primary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .truncationMode(.middle)
                        .lineLimit(2)
                        .help(subtitle)
                }
            }
            Spacer()
            Button(actionName) {
                action()
            }
        }
    }
}

enum VectorPanelTokens {
    static let background = Color(nsColor: NSColor(calibratedWhite: 0.08, alpha: 1))
    static let surface = Color(nsColor: NSColor(calibratedWhite: 0.11, alpha: 1))
    static let border = Color.white.opacity(0.08)
    static let divider = Color.white.opacity(0.07)
    static let subtleText = Color.white.opacity(0.62)
    static let sectionText = Color.white.opacity(0.56)
    static let danger = Color(red: 0.89, green: 0.40, blue: 0.40)
}

struct VectorPanelCard<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        padding: CGFloat = 14,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(VectorPanelTokens.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(VectorPanelTokens.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 5)
    }
}

struct VectorSectionHeader: View {
    let title: String
    var expanded: Bool?
    var onToggle: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(VectorPanelTokens.sectionText)
            Spacer(minLength: 8)
            if let expanded {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VectorPanelTokens.sectionText)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle?()
        }
    }
}

struct VectorSettingRow<Control: View>: View {
    let title: String
    var subtitle: String?
    var height: CGFloat
    @ViewBuilder let control: () -> Control

    init(
        _ title: String,
        subtitle: String? = nil,
        height: CGFloat = 38,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.height = height
        self.control = control
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(VectorPanelTokens.subtleText)
                }
            }
            Spacer(minLength: 10)
            control()
        }
        .frame(minHeight: height)
    }
}

struct VectorControlListRow: View {
    let icon: String
    let title: String
    var destructive: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(destructive ? VectorPanelTokens.danger : .white.opacity(0.82))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(destructive ? VectorPanelTokens.danger : .white.opacity(0.92))
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct VectorPrimaryPanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.20 : 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
            )
    }
}

struct VectorDangerPanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(VectorPanelTokens.danger)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.23 : 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
    }
}

struct VectorCompactToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.label
            Spacer(minLength: 8)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Color.white.opacity(0.28) : Color.white.opacity(0.12))
                    .frame(width: 42, height: 24)
                Circle()
                    .fill(Color.white.opacity(configuration.isOn ? 0.95 : 0.72))
                    .frame(width: 20, height: 20)
                    .padding(2)
            }
            .animation(.easeInOut(duration: 0.16), value: configuration.isOn)
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
}

struct VectorCompactPickerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .labelsHidden()
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

extension View {
    func vectorCompactPicker() -> some View {
        modifier(VectorCompactPickerModifier())
    }

    func vectorPanelSurface() -> some View {
        background(VectorPanelTokens.background)
    }
}
