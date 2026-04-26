//
//  HostSecurityCapabilityProbe.swift
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
import Metal

public enum VectorHostSecurityMode: String, Codable, CaseIterable, Sendable {
    case fullSecurity
    case reducedSecurity
    case permissiveSecurity
    case unknown

    public var displayName: String {
        switch self {
        case .fullSecurity:
            return "Full Security"
        case .reducedSecurity:
            return "Reduced Security"
        case .permissiveSecurity:
            return "Permissive Security"
        case .unknown:
            return "Unknown"
        }
    }
}

public enum VectorSIPState: String, Codable, CaseIterable, Sendable {
    case enabled
    case disabled
    case unknown

    public var displayName: String {
        switch self {
        case .enabled:
            return "Enabled"
        case .disabled:
            return "Disabled"
        case .unknown:
            return "Unknown"
        }
    }
}

public struct VectorHostSecurityCapabilityReport: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var generatedAt: String
    public var securityMode: VectorHostSecurityMode
    public var sipState: VectorSIPState
    public var authenticatedRootEnabled: Bool?
    public var systemExtensionsAvailable: Bool
    public var driverKitHostAvailable: Bool
    public var driverKitAppEntitled: Bool
    public var rosettaInstalled: Bool
    public var processTranslated: Bool
    public var metalSupported: Bool
    public var metalDeviceName: String
    public var gptkRuntimeAvailable: Bool
    public var d3dMetalPayloadInstalled: Bool
    public var vectorRuntimeInstalled: Bool
    public var hostAllowsAdvancedDiagnostics: Bool
    public var developerModeEnabled: Bool
    public var advancedDiagnosticsUnlocked: Bool
    public var evidence: [String]

    public var compactSummary: String {
        let advancedState = advancedDiagnosticsUnlocked ? "advanced diagnostics unlocked" : "standard diagnostics"
        return "\(securityMode.displayName), SIP \(sipState.displayName.lowercased()), \(advancedState)"
    }
}

public enum VectorHostSecurityCapabilityProbe {
    private struct SystemToolResult {
        let stdout: String
        let stderr: String
        let code: Int32

        var combinedOutput: String {
            (stdout + "\n" + stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private struct SecurityProbeState {
        let csrutil: SystemToolResult
        let authenticatedRoot: SystemToolResult
        let nvramCSR: SystemToolResult
        let bootArgs: SystemToolResult
        let bootPolicy: SystemToolResult
        let sipState: VectorSIPState
        let authenticatedRootEnabled: Bool?
        let securityMode: VectorHostSecurityMode
    }

    public static func current() -> VectorHostSecurityCapabilityReport {
        let security = securityProbeState()
        let metalDevice = MTLCreateSystemDefaultDevice()
        let entitlements = currentProcessEntitlements()
        let driverKitAppEntitled = entitlements.keys.contains { key in
            key.localizedCaseInsensitiveContains("driverkit")
        }
        let gptkRuntimeAvailable = VectorWineInstaller.steamCompatibilityWineBinary() != nil
            || fileExists("/Applications/Game Porting Toolkit.app")
        let d3dMetalPayloadInstalled = fileExists(
            VectorWineInstaller.libraryFolder.appending(path: "D3DMetal").path(percentEncoded: false)
        )
        let developerModeEnabled = developerToolsEnabled()
        let hostAllowsAdvancedDiagnostics = security.securityMode == .reducedSecurity
            || security.securityMode == .permissiveSecurity
            || security.sipState == .disabled

        return VectorHostSecurityCapabilityReport(
            schemaVersion: 1,
            generatedAt: isoDateString(),
            securityMode: security.securityMode,
            sipState: security.sipState,
            authenticatedRootEnabled: security.authenticatedRootEnabled,
            systemExtensionsAvailable: isExecutable("/usr/bin/systemextensionsctl"),
            driverKitHostAvailable: driverKitHostAvailable(),
            driverKitAppEntitled: driverKitAppEntitled,
            rosettaInstalled: Rosetta2.isRosettaInstalled,
            processTranslated: processIsTranslated(),
            metalSupported: metalDevice != nil,
            metalDeviceName: metalDevice?.name ?? "Unavailable",
            gptkRuntimeAvailable: gptkRuntimeAvailable,
            d3dMetalPayloadInstalled: d3dMetalPayloadInstalled,
            vectorRuntimeInstalled: VectorWineInstaller.isVectorWineInstalled(),
            hostAllowsAdvancedDiagnostics: hostAllowsAdvancedDiagnostics,
            developerModeEnabled: developerModeEnabled,
            advancedDiagnosticsUnlocked: developerModeEnabled && hostAllowsAdvancedDiagnostics,
            evidence: compactEvidence(
                csrutil: security.csrutil,
                authenticatedRoot: security.authenticatedRoot,
                nvramCSR: security.nvramCSR,
                bootArgs: security.bootArgs,
                bootPolicy: security.bootPolicy
            )
        )
    }

    public static func currentJSON(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        }
        return try encoder.encode(current())
    }
}

private extension VectorHostSecurityCapabilityProbe {
    private static func securityProbeState() -> SecurityProbeState {
        let csrutil = runSystemTool("/usr/bin/csrutil", arguments: ["status"])
        let authenticatedRoot = runSystemTool("/usr/bin/csrutil", arguments: ["authenticated-root", "status"])
        let nvramCSR = runSystemTool("/usr/sbin/nvram", arguments: ["csr-active-config"])
        let bootArgs = runSystemTool("/usr/sbin/nvram", arguments: ["boot-args"])
        let bootPolicy = runSystemTool("/usr/bin/bputil", arguments: ["-d"])
        let sipState = parseSIPState(csrutil.combinedOutput)
        let authenticatedRootEnabled = parseAuthenticatedRootState(authenticatedRoot.combinedOutput)
        let securityMode = inferSecurityMode(
            sipState: sipState,
            csrutilOutput: csrutil.combinedOutput,
            authenticatedRootEnabled: authenticatedRootEnabled,
            csrActiveConfig: nvramCSR.combinedOutput,
            bootPolicy: bootPolicy.combinedOutput
        )
        return SecurityProbeState(
            csrutil: csrutil,
            authenticatedRoot: authenticatedRoot,
            nvramCSR: nvramCSR,
            bootArgs: bootArgs,
            bootPolicy: bootPolicy,
            sipState: sipState,
            authenticatedRootEnabled: authenticatedRootEnabled,
            securityMode: securityMode
        )
    }

    private static func parseSIPState(_ output: String) -> VectorSIPState {
        let normalized = output.lowercased()
        if normalized.contains("disabled") {
            return .disabled
        }
        if normalized.contains("enabled") {
            return .enabled
        }
        return .unknown
    }

    private static func parseAuthenticatedRootState(_ output: String) -> Bool? {
        let normalized = output.lowercased()
        if normalized.contains("disabled") {
            return false
        }
        if normalized.contains("enabled") {
            return true
        }
        return nil
    }

    private static func inferSecurityMode(
        sipState: VectorSIPState,
        csrutilOutput: String,
        authenticatedRootEnabled: Bool?,
        csrActiveConfig: String,
        bootPolicy: String
    ) -> VectorHostSecurityMode {
        let normalizedCSR = csrutilOutput.lowercased()
        let normalizedConfig = csrActiveConfig.lowercased()
        let normalizedPolicy = bootPolicy.lowercased()
        if sipState == .disabled {
            return .permissiveSecurity
        }
        if normalizedPolicy.contains("reduced security")
            || normalizedPolicy.contains("permissive security")
            || normalizedCSR.contains("reduced security")
            || authenticatedRootEnabled == false
            || csrActiveConfigLooksRelaxed(normalizedConfig) {
            return .reducedSecurity
        }
        if normalizedPolicy.contains("full security") {
            return .fullSecurity
        }
        return .unknown
    }

    private static func csrActiveConfigLooksRelaxed(_ output: String) -> Bool {
        guard output.contains("csr-active-config") else {
            return false
        }
        let relaxedTokens = [
            "%01", "%02", "%03", "%04", "%05", "%06", "%07", "%08",
            "01000000", "02000000", "03000000", "ff", "ff0f0000"
        ]
        return relaxedTokens.contains { output.contains($0) }
    }

    private static func driverKitHostAvailable() -> Bool {
        fileExists("/System/Library/DriverExtensions")
            || fileExists("/Library/SystemExtensions")
            || fileExists("/System/Library/Frameworks/DriverKit.framework")
    }

    private static func processIsTranslated() -> Bool {
        var translated: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("sysctl.proc_translated", &translated, &size, nil, 0)
        return result == 0 && translated == 1
    }

    private static func currentProcessEntitlements() -> [String: String] {
        let path = Bundle.main.bundleURL.path(percentEncoded: false)
        let result = runSystemTool("/usr/bin/codesign", arguments: ["-d", "--entitlements", ":-", path])
        return entitlementsDictionary(from: result.stdout + result.stderr)
    }

    private static func entitlementsDictionary(from output: String) -> [String: String] {
        guard let plistStart = output.range(of: "<?xml")?.lowerBound else {
            return [:]
        }
        let plistText = String(output[plistStart...])
        guard let data = plistText.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any] else {
            return [:]
        }
        return plist.reduce(into: [String: String]()) { result, pair in
            result[pair.key] = String(describing: pair.value)
        }
    }

    private static func developerToolsEnabled() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["VECTOR_DEVELOPER_TOOLS"] == "1" {
            return true
        }
        return UserDefaults.standard.bool(forKey: "VectorDeveloperToolsEnabled")
    }

    private static func compactEvidence(
        csrutil: SystemToolResult,
        authenticatedRoot: SystemToolResult,
        nvramCSR: SystemToolResult,
        bootArgs: SystemToolResult,
        bootPolicy: SystemToolResult
    ) -> [String] {
        [
            evidenceLine(label: "csrutil", result: csrutil),
            evidenceLine(label: "authenticated-root", result: authenticatedRoot),
            evidenceLine(label: "csr-active-config", result: nvramCSR),
            evidenceLine(label: "boot-args", result: bootArgs),
            evidenceLine(label: "boot-policy", result: bootPolicy)
        ].filter { !$0.isEmpty }
    }

    private static func evidenceLine(label: String, result: SystemToolResult) -> String {
        let output = result.combinedOutput
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: " | ")
        guard !output.isEmpty else {
            return "\(label): exit=\(result.code)"
        }
        return "\(label): exit=\(result.code) \(output)"
    }

    private static func runSystemTool(_ executable: String, arguments: [String]) -> SystemToolResult {
        guard isExecutable(executable) else {
            return SystemToolResult(stdout: "", stderr: "not found", code: -1)
        }
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
            let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return SystemToolResult(stdout: stdout, stderr: stderr, code: process.terminationStatus)
        } catch {
            return SystemToolResult(stdout: "", stderr: error.localizedDescription, code: -1)
        }
    }

    private static func isExecutable(_ path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    private static func fileExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    private static func isoDateString() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
