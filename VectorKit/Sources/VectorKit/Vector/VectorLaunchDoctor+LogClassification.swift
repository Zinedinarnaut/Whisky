//
//  VectorLaunchDoctor+LogClassification.swift
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

struct VectorLaunchDoctorLogRule {
    var id: String
    var severity: VectorLaunchDoctorFindingSeverity
    var title: String
    var detail: String
    var failureClass: VectorLaunchDoctorFailureClass
    var needles: [String]
    var requiresAllNeedles: Bool = false

    func matches(_ logText: String) -> Bool {
        if requiresAllNeedles {
            return needles.allSatisfy(logText.contains)
        }
        return needles.contains(where: logText.contains)
    }
}

extension VectorLaunchDoctor {
    static func recentLogClassifications(for bottle: Bottle) -> [VectorLaunchDoctorFinding] {
        let logText = recentLogText(for: bottle, maxCount: 4).lowercased()
        guard !logText.isEmpty else {
            return []
        }

        return logClassificationRules.compactMap { rule in
            guard rule.matches(logText) else {
                return nil
            }
            return VectorLaunchDoctorFinding(
                id: rule.id,
                severity: rule.severity,
                title: rule.title,
                detail: rule.detail,
                failureClass: rule.failureClass
            )
        }
    }
}

private extension VectorLaunchDoctor {
    static let logClassificationRules: [VectorLaunchDoctorLogRule] = [
        VectorLaunchDoctorLogRule(
            id: "log-dx-feature-level",
            severity: .warning,
            title: "D3D feature level failure",
            detail: "Recent logs indicate the game could not see the required D3D11 feature level.",
            failureClass: .dxFeatureLevel,
            needles: ["dx11 feature level 10.0", "d3d11-compatible gpu", "feature level 11.0"]
        ),
        VectorLaunchDoctorLogRule(
            id: "log-dx12-unsupported",
            severity: .warning,
            title: "DX12 path is unsupported",
            detail: "Recent logs indicate the game requested a DX12 path that needs D3DMetal coverage.",
            failureClass: .dx12Unsupported,
            needles: ["directx 12 is not supported", "d3d12 not supported"]
        ),
        VectorLaunchDoctorLogRule(
            id: "log-wineserver-mismatch",
            severity: .warning,
            title: "Wine/wineserver mismatch",
            detail: "Recent logs show mixed Wine runtime binaries. Kill stale wineservers before retrying.",
            failureClass: .wineserverMismatch,
            needles: ["version mismatch", "wrong wineserver is still running"]
        ),
        VectorLaunchDoctorLogRule(
            id: "log-runtime-dependency",
            severity: .warning,
            title: "Runtime dependency fault",
            detail: "Recent logs mention .NET, Visual C++, or WebView runtime components.",
            failureClass: .missingRuntimeDependency,
            needles: ["mscoree.dll", "vcruntime", "msvcp", "edgewebview"]
        ),
        VectorLaunchDoctorLogRule(
            id: "log-webview-auth",
            severity: .warning,
            title: "Microsoft auth WebView fault",
            detail: "Recent logs/UI state match the Microsoft sign-in callback/WebView failure class.",
            failureClass: .webViewAuth,
            needles: [
                "you have reached a page that is not normally shown",
                "microsoft will never ask you to copy or share this url"
            ]
        ),
        VectorLaunchDoctorLogRule(
            id: "log-media-playback",
            severity: .warning,
            title: "Media playback dependency fault",
            detail: "Recent logs indicate missing or broken Windows media playback plumbing.",
            failureClass: .mediaPlayback,
            needles: ["mfplat.dll", "winegstreamer", "failed to initialize video", "video playback"]
        ),
        VectorLaunchDoctorLogRule(
            id: "log-steam-bootstrap",
            severity: .info,
            title: "Steam bootstrap/UI signal",
            detail: "Recent logs include Steam webhelper/CEF signals; use Steam safe UI mode if blank.",
            failureClass: .steamBootstrap,
            needles: ["steamwebhelper", "cef", "htmlcache"]
        )
    ]

    static func recentLogText(for bottle: Bottle, maxCount: Int) -> String {
        let bottlePath = bottle.url.path(percentEncoded: false)
        let logFiles = sortedLogFiles().prefix(30)
        var snippets: [String] = []

        for logURL in logFiles {
            guard let content = try? String(contentsOf: logURL, encoding: .utf8),
                  content.contains("Bottle URL: \(bottlePath)")
                    || content.contains("Bottle Name: \(bottle.settings.name)") else {
                continue
            }
            snippets.append(tail(content, maxLines: 120))
            if snippets.count >= maxCount {
                break
            }
        }

        return snippets.joined(separator: "\n")
    }

    static func sortedLogFiles() -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: Wine.logsFolder,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return files.filter { $0.pathExtension == "log" }.sorted {
            creationDate($0) > creationDate($1)
        }
    }

    static func creationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }

    static func tail(_ content: String, maxLines: Int) -> String {
        content.components(separatedBy: .newlines).suffix(maxLines).joined(separator: "\n")
    }
}
