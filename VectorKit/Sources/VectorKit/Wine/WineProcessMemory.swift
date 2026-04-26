//
//  WineProcessMemory.swift
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

public struct WineProcessHandle: Hashable, Sendable {
    public let winePID: Int32
    fileprivate let token: UUID
}

public enum WineProcessMemoryTransport: String, Sendable {
    case auto
    case ntBridge
    case debugger
}

public enum WineVirtualMemoryState: String, Sendable {
    case committed
    case reserved
    case free
    case unknown
}

public enum WineVirtualMemoryType: String, Sendable {
    case image
    case mapped
    case privateMemory
    case unknown
}

public struct WineMemoryProtection: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let read = WineMemoryProtection(rawValue: 1 << 0)
    public static let write = WineMemoryProtection(rawValue: 1 << 1)
    public static let execute = WineMemoryProtection(rawValue: 1 << 2)
    public static let copyOnWrite = WineMemoryProtection(rawValue: 1 << 3)
}

public struct WineVirtualMemoryRegion: Hashable, Sendable {
    public let baseAddress: UInt64
    public let regionSize: UInt64
    public let protection: WineMemoryProtection
    public let state: WineVirtualMemoryState
    public let type: WineVirtualMemoryType
}

public struct WineReadResult: Hashable, Sendable {
    public let data: Data
    public let requestedByteCount: Int

    public var bytesRead: Int {
        data.count
    }

    public var isPartial: Bool {
        bytesRead < requestedByteCount
    }
}

public struct WineWriteResult: Hashable, Sendable {
    public let bytesWritten: Int
    public let requestedByteCount: Int

    public var succeeded: Bool {
        bytesWritten == requestedByteCount
    }

    public var isPartial: Bool {
        bytesWritten < requestedByteCount
    }
}

public struct WineModuleInfo: Hashable, Sendable {
    public let kind: String
    public let name: String
    public let baseAddress: UInt64
    public let endAddress: UInt64
    public let debugInfo: String
}

public struct WineProcessInfo: Hashable, Sendable {
    public let name: String
    public let pid: Int32
}

public struct WineProcessMemoryTransportStatus: Hashable, Sendable {
    public let requested: WineProcessMemoryTransport
    public let effective: WineProcessMemoryTransport
    public let bridgeAvailable: Bool
    public let debuggerAvailable: Bool
}

public enum WineProcessMemoryError: LocalizedError {
    case processNotFound(Int32)
    case invalidHandle
    case debuggerUnavailable
    case bridgeUnavailable
    case protectedToolingUnavailable(String)
    case invalidBridgeResponse
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .processNotFound(let pid):
            return "No Wine process found for pid \(pid)."
        case .invalidHandle:
            return "Invalid or closed Wine process handle."
        case .debuggerUnavailable:
            return "No compatible winedbg executable is available for this bottle runtime."
        case .bridgeUnavailable:
            return "No compatible vectorvmctl memory bridge is available for this bottle runtime."
        case .protectedToolingUnavailable(let message):
            return message
        case .invalidBridgeResponse:
            return "Memory bridge returned malformed or incomplete JSON."
        case .commandFailed(let message):
            return message
        }
    }
}

// swiftlint:disable:next type_body_length
public final class WineProcessMemoryService {
    private struct RuntimeBinaries {
        let wine: URL
        let winedbg: URL
        let bridgeTool: URL?
    }

    private struct HandleContext {
        let pid: Int32
    }

    private struct WineProcessEntry {
        let name: String
        let pid: Int32
    }

    private struct ProcessExecutionResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private struct MemoryAuditEvent: Codable {
        let timestamp: String
        let operation: String
        let winePID: Int32?
        let address: String?
        let requestedByteCount: Int?
        let completedByteCount: Int?
        let transport: String
        let result: String
        let message: String
    }

    private final class DataSink: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var data = Data()

        func append(_ newData: Data) {
            lock.lock()
            data.append(newData)
            lock.unlock()
        }

        func snapshot() -> Data {
            lock.lock()
            let current = data
            lock.unlock()
            return current
        }
    }

    private let bottle: Bottle
    private let lock = NSLock()
    private let environmentOverrides: [String: String]
    private let preferredTransport: WineProcessMemoryTransport
    private var handles: [UUID: HandleContext] = [:]
    private var cachedRuntime: RuntimeBinaries?
    private var cachedBridgeSupport: Bool?

    public init(
        bottle: Bottle,
        environmentOverrides: [String: String] = [:],
        preferredTransport: WineProcessMemoryTransport = .auto
    ) {
        self.bottle = bottle
        self.environmentOverrides = environmentOverrides
        self.preferredTransport = preferredTransport
    }

    public func transportStatus() throws -> WineProcessMemoryTransportStatus {
        try assertMemoryToolingAllowed(operation: "transportStatus", pid: nil)
        let requested = resolvedTransportPreference()
        let runtime = try runtimeBinaries()
        let bridgeAvailable = runtime.bridgeTool != nil
        let debuggerPath = runtime.winedbg.path(percentEncoded: false)
        let debuggerAvailable = FileManager.default.isExecutableFile(atPath: debuggerPath)
        let effective: WineProcessMemoryTransport
        switch requested {
        case .auto:
            effective = bridgeAvailable ? .ntBridge : .debugger
        case .ntBridge:
            effective = bridgeAvailable ? .ntBridge : .debugger
        case .debugger:
            effective = .debugger
        }

        let status = WineProcessMemoryTransportStatus(
            requested: requested,
            effective: effective,
            bridgeAvailable: bridgeAvailable,
            debuggerAvailable: debuggerAvailable
        )
        audit(
            operation: "transportStatus",
            pid: nil,
            address: nil,
            requestedByteCount: nil,
            completedByteCount: nil,
            result: "ok",
            transport: effective.rawValue,
            message: "bridge=\(bridgeAvailable) debugger=\(debuggerAvailable)"
        )
        return status
    }

    public func listProcesses() throws -> [WineProcessInfo] {
        try assertMemoryToolingAllowed(operation: "OpenProcess.listProcesses", pid: nil)
        let processes = try performWithPreferredTransport(
            bridgeOperation: { try listWineProcessesViaBridge() },
            debuggerOperation: { try listWineProcesses() }
        )
        let infos = processes.map { WineProcessInfo(name: $0.name, pid: $0.pid) }
            .sorted(by: { $0.pid < $1.pid })
        audit(
            operation: "OpenProcess.listProcesses",
            pid: nil,
            address: nil,
            requestedByteCount: nil,
            completedByteCount: infos.count,
            result: "ok",
            message: "listed Wine-managed processes"
        )
        return infos
    }

    /// Open a Wine process handle scoped to this bottle.
    public func openProcess(winePID: Int32) throws -> WineProcessHandle {
        try assertMemoryToolingAllowed(operation: "OpenProcess", pid: winePID)
        let processes = try performWithPreferredTransport(
            bridgeOperation: { try listWineProcessesViaBridge() },
            debuggerOperation: { try listWineProcesses() }
        )
        guard processes.contains(where: { $0.pid == winePID }) else {
            audit(
                operation: "OpenProcess",
                pid: winePID,
                address: nil,
                requestedByteCount: nil,
                completedByteCount: nil,
                result: "failed",
                message: "process not found"
            )
            throw WineProcessMemoryError.processNotFound(winePID)
        }

        let token = UUID()
        lock.lock()
        handles[token] = HandleContext(pid: winePID)
        lock.unlock()

        audit(
            operation: "OpenProcess",
            pid: winePID,
            address: nil,
            requestedByteCount: nil,
            completedByteCount: nil,
            result: "ok",
            message: "opaque handle opened"
        )
        return WineProcessHandle(winePID: winePID, token: token)
    }

    public func closeHandle(_ handle: WineProcessHandle) {
        lock.lock()
        handles.removeValue(forKey: handle.token)
        lock.unlock()
        audit(
            operation: "CloseHandle",
            pid: handle.winePID,
            address: nil,
            requestedByteCount: nil,
            completedByteCount: nil,
            result: "ok",
            message: "opaque handle closed"
        )
    }

    /// Query the memory region containing `address`, similar to VirtualQueryEx.
    public func virtualQueryEx(handle: WineProcessHandle, address: UInt64) throws -> WineVirtualMemoryRegion? {
        try assertMemoryToolingAllowed(operation: "VirtualQueryEx", pid: handle.winePID)
        let context = try handleContext(for: handle)
        let regions = try performWithPreferredTransport(
            bridgeOperation: { try queryMemoryMapViaBridge(pid: context.pid) },
            debuggerOperation: { try queryMemoryMap(pid: context.pid) }
        )
        let region = regions.first(where: { contains(address: address, in: $0) })
        audit(
            operation: "VirtualQueryEx",
            pid: context.pid,
            address: address,
            requestedByteCount: nil,
            completedByteCount: region == nil ? 0 : Int(min(region?.regionSize ?? 0, UInt64(Int.max))),
            result: region == nil ? "notFound" : "ok",
            message: "validated Wine virtual address region"
        )
        return region
    }

    // swiftlint:disable function_body_length
    /// Read memory from a Wine process using Wine debugger-backed primitives.
    /// Returns a partial read if an unreadable or invalid region is crossed.
    public func readProcessMemory(
        handle: WineProcessHandle,
        address: UInt64,
        size: Int
    ) throws -> WineReadResult {
        try assertMemoryToolingAllowed(operation: "ReadProcessMemory", pid: handle.winePID)
        let context = try handleContext(for: handle)
        guard size > 0 else {
            audit(
                operation: "ReadProcessMemory",
                pid: context.pid,
                address: address,
                requestedByteCount: size,
                completedByteCount: 0,
                result: "ok",
                message: "zero-length read"
            )
            return WineReadResult(data: Data(), requestedByteCount: 0)
        }

        let regions = try performWithPreferredTransport(
            bridgeOperation: { try queryMemoryMapViaBridge(pid: context.pid) },
            debuggerOperation: { try queryMemoryMap(pid: context.pid) }
        )
        var cursor = address
        var remaining = size
        var output = Data()

        while remaining > 0 {
            guard let region = regions.first(where: { contains(address: cursor, in: $0) }) else {
                break
            }
            guard region.state == .committed, region.protection.contains(.read) else {
                break
            }

            let offsetInRegion = cursor - region.baseAddress
            let availableInRegion = region.regionSize > offsetInRegion ? region.regionSize - offsetInRegion : 0
            if availableInRegion == 0 {
                break
            }

            let chunkSize = min(remaining, min(64, Int(availableInRegion)))
            let chunk = try performWithPreferredTransport(
                bridgeOperation: { try readBytesViaBridge(pid: context.pid, address: cursor, count: chunkSize) },
                debuggerOperation: { try readBytes(pid: context.pid, address: cursor, count: chunkSize) }
            )
            if chunk.isEmpty {
                break
            }

            output.append(contentsOf: chunk)
            cursor += UInt64(chunk.count)
            remaining -= chunk.count

            if chunk.count < chunkSize {
                break
            }
        }

        let result = WineReadResult(data: output, requestedByteCount: size)
        audit(
            operation: "ReadProcessMemory",
            pid: context.pid,
            address: address,
            requestedByteCount: size,
            completedByteCount: result.bytesRead,
            result: result.isPartial ? "partial" : "ok",
            message: "read validated through VirtualQueryEx-compatible map"
        )
        return result
    }
    // swiftlint:enable function_body_length

    // swiftlint:disable function_body_length
    /// Write memory to a Wine process.
    ///
    /// This method intentionally stays inside Wine debugger transport to avoid direct host VM access.
    /// Some runtime builds can reject debugger write expressions; in that case this returns a partial/failed result.
    public func writeProcessMemory(
        handle: WineProcessHandle,
        address: UInt64,
        data: Data,
        autoAdjustProtection: Bool = false
    ) throws -> WineWriteResult {
        try assertMemoryToolingAllowed(operation: "WriteProcessMemory", pid: handle.winePID)
        _ = autoAdjustProtection
        let context = try handleContext(for: handle)
        guard !data.isEmpty else {
            audit(
                operation: "WriteProcessMemory",
                pid: context.pid,
                address: address,
                requestedByteCount: 0,
                completedByteCount: 0,
                result: "ok",
                message: "zero-length write"
            )
            return WineWriteResult(bytesWritten: 0, requestedByteCount: 0)
        }

        let regions = try performWithPreferredTransport(
            bridgeOperation: { try queryMemoryMapViaBridge(pid: context.pid) },
            debuggerOperation: { try queryMemoryMap(pid: context.pid) }
        )
        var bytesWritten = 0

        while bytesWritten < data.count {
            let writeAddress = address + UInt64(bytesWritten)
            guard let region = regions.first(where: { contains(address: writeAddress, in: $0) }) else {
                break
            }
            guard region.state == .committed else {
                break
            }
            guard region.protection.contains(.write) || region.protection.contains(.copyOnWrite) else {
                break
            }

            let offsetInRegion = writeAddress - region.baseAddress
            let availableInRegion = region.regionSize > offsetInRegion ? region.regionSize - offsetInRegion : 0
            if availableInRegion == 0 {
                break
            }

            let remaining = data.count - bytesWritten
            let chunkSize = min(remaining, min(64, Int(availableInRegion)))
            let start = data.index(data.startIndex, offsetBy: bytesWritten)
            let end = data.index(start, offsetBy: chunkSize)
            let chunk = Data(data[start..<end])
            let completed = try performWithPreferredTransport(
                bridgeOperation: { try writeBytesViaBridge(pid: context.pid, address: writeAddress, data: chunk) },
                debuggerOperation: { try writeBytes(pid: context.pid, address: writeAddress, data: chunk) }
            )
            guard completed > 0 else {
                break
            }

            bytesWritten += completed
            if completed < chunkSize {
                break
            }
        }

        let result = WineWriteResult(bytesWritten: bytesWritten, requestedByteCount: data.count)
        audit(
            operation: "WriteProcessMemory",
            pid: context.pid,
            address: address,
            requestedByteCount: data.count,
            completedByteCount: bytesWritten,
            result: result.isPartial ? "partial" : "ok",
            message: "write validated through VirtualQueryEx-compatible map"
        )
        return result
    }
    // swiftlint:enable function_body_length

    public func enumerateModules(handle: WineProcessHandle) throws -> [WineModuleInfo] {
        try assertMemoryToolingAllowed(operation: "GetModuleBase.enumerateModules", pid: handle.winePID)
        let context = try handleContext(for: handle)
        let modules = try performWithPreferredTransport(
            bridgeOperation: { try enumerateModulesViaBridge(pid: context.pid) },
            debuggerOperation: {
                let output = try runDebuggerCommand(pid: context.pid, commands: ["info share"])
                return parseModuleList(from: output)
            }
        )
        audit(
            operation: "GetModuleBase.enumerateModules",
            pid: context.pid,
            address: nil,
            requestedByteCount: nil,
            completedByteCount: modules.count,
            result: "ok",
            message: "module list enumerated"
        )
        return modules
    }

    public func getModuleBase(handle: WineProcessHandle, moduleName: String) throws -> UInt64? {
        try assertMemoryToolingAllowed(operation: "GetModuleBase", pid: handle.winePID)
        let normalizedTarget = normalizeModuleName(moduleName)
        guard !normalizedTarget.isEmpty else { return nil }

        let modules = try enumerateModules(handle: handle)
        let baseAddress = modules.first(where: { normalizeModuleName($0.name) == normalizedTarget })?.baseAddress
        audit(
            operation: "GetModuleBase",
            pid: handle.winePID,
            address: baseAddress,
            requestedByteCount: nil,
            completedByteCount: nil,
            result: baseAddress == nil ? "notFound" : "ok",
            message: "module=\(moduleName)"
        )
        return baseAddress
    }
}

private extension WineProcessMemoryService {
    private func performWithPreferredTransport<T>(
        bridgeOperation: () throws -> T,
        debuggerOperation: () throws -> T
    ) throws -> T {
        switch resolvedTransportPreference() {
        case .debugger:
            return try debuggerOperation()
        case .ntBridge:
            guard try isBridgeAvailable() else {
                throw WineProcessMemoryError.bridgeUnavailable
            }
            return try bridgeOperation()
        case .auto:
            guard try isBridgeAvailable() else {
                return try debuggerOperation()
            }

            do {
                return try bridgeOperation()
            } catch {
                if shouldFallbackToDebugger(after: error) {
                    Logger.wineKit.warning(
                        // swiftlint:disable:next line_length
                        "Memory NT bridge failed, falling back to debugger path: \(error.localizedDescription, privacy: .public)"
                    )
                    return try debuggerOperation()
                }
                throw error
            }
        }
    }

    private func assertMemoryToolingAllowed(operation: String, pid: Int32?) throws {
        do {
            try VectorProtectedTitlePolicyEngine.assertMemoryToolingAllowed(for: bottle)
        } catch {
            audit(
                operation: operation,
                pid: pid,
                address: nil,
                requestedByteCount: nil,
                completedByteCount: nil,
                result: "blocked",
                message: error.localizedDescription
            )
            throw error
        }
    }

    private func resolvedTransportPreference() -> WineProcessMemoryTransport {
        if let override = environmentOverrides["VECTOR_MEMORY_TRANSPORT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           let parsed = parseTransportName(override) {
            return parsed
        }

        if let processOverride = ProcessInfo.processInfo.environment["VECTOR_MEMORY_TRANSPORT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           let parsed = parseTransportName(processOverride) {
            return parsed
        }

        return preferredTransport
    }

    private func parseTransportName(_ rawValue: String) -> WineProcessMemoryTransport? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "auto":
            return .auto
        case "ntbridge", "nt_bridge", "nt-bridge", "nt":
            return .ntBridge
        case "debugger", "winedbg", "dbg":
            return .debugger
        default:
            return nil
        }
    }

    private func isBridgeAvailable() throws -> Bool {
        lock.lock()
        if let cachedBridgeSupport {
            lock.unlock()
            return cachedBridgeSupport
        }
        lock.unlock()

        let runtime = try runtimeBinaries()
        guard let bridgeTool = runtime.bridgeTool else { return cacheBridgeAvailability(false) }
        let bridgePath = bridgeTool.path(percentEncoded: false)
        guard FileManager.default.isExecutableFile(atPath: bridgePath) else { return cacheBridgeAvailability(false) }

        let environment = commandEnvironment(for: runtime)
        let supportsBridge: Bool
        do {
            let probe = try runProcess(
                executableURL: bridgeTool,
                arguments: ["--json", "bridge", "capabilities"],
                environment: environment,
                stdin: nil
            )
            supportsBridge = try parseBridgeCapabilityProbe(probe)
        } catch {
            supportsBridge = false
        }

        return cacheBridgeAvailability(supportsBridge)
    }

    private func shouldFallbackToDebugger(after error: Error) -> Bool {
        guard let memoryError = error as? WineProcessMemoryError else {
            return false
        }

        switch memoryError {
        case .bridgeUnavailable, .invalidBridgeResponse:
            return true
        case .commandFailed(let message):
            let normalized = message.lowercased()
            return normalized.contains("unknown command")
                || normalized.contains("not supported")
                || normalized.contains("json")
                || normalized.contains("bridge")
        case .processNotFound, .invalidHandle, .debuggerUnavailable, .protectedToolingUnavailable:
            return false
        }
    }

    private func shouldFallbackToLegacyBridgeCommand(after error: Error) -> Bool {
        guard let memoryError = error as? WineProcessMemoryError else {
            return false
        }

        switch memoryError {
        case .commandFailed(let message):
            let normalized = message.lowercased()
            return normalized.contains("unknown command")
                || normalized.contains("not supported")
                || normalized.contains("unrecognized")
                || normalized.contains("invalid command")
        case .invalidBridgeResponse:
            return true
        case .processNotFound, .invalidHandle, .debuggerUnavailable, .bridgeUnavailable, .protectedToolingUnavailable:
            return false
        }
    }

    private func handleContext(for handle: WineProcessHandle) throws -> HandleContext {
        lock.lock()
        let context = handles[handle.token]
        lock.unlock()

        guard let context else {
            throw WineProcessMemoryError.invalidHandle
        }

        return context
    }

    private func contains(address: UInt64, in region: WineVirtualMemoryRegion) -> Bool {
        let regionEndExclusive = region.baseAddress + region.regionSize
        return address >= region.baseAddress && address < regionEndExclusive
    }

    private func listWineProcessesViaBridge() throws -> [WineProcessEntry] {
        let response = try runBridgeCommand(arguments: ["process", "list"])
        guard let processItems = response["processes"] as? [[String: Any]] else {
            throw WineProcessMemoryError.invalidBridgeResponse
        }

        return processItems.compactMap { item in
            guard let name = item["name"] as? String,
                  let pidValue = item["pid"] else {
                return nil
            }

            let pid: Int32?
            if let intPID = pidValue as? Int32 {
                pid = intPID
            } else if let intPID = pidValue as? Int {
                pid = Int32(intPID)
            } else if let pidString = pidValue as? String, let parsed = Int32(pidString) {
                pid = parsed
            } else {
                pid = nil
            }

            guard let pid else { return nil }
            return WineProcessEntry(name: name, pid: pid)
        }
    }

    private func queryMemoryMapViaBridge(pid: Int32) throws -> [WineVirtualMemoryRegion] {
        let response: [String: Any]
        do {
            response = try runBridgeCommand(arguments: ["nt", "query-virtual-memory", "--pid", String(pid)])
        } catch {
            guard shouldFallbackToLegacyBridgeCommand(after: error) else { throw error }
            response = try runBridgeCommand(arguments: ["memory", "map", "--pid", String(pid)])
        }
        guard let regionItems = response["regions"] as? [[String: Any]] else {
            throw WineProcessMemoryError.invalidBridgeResponse
        }

        let regions = try regionItems.compactMap { item -> WineVirtualMemoryRegion? in
            guard let baseString = item["base"] as? String,
                  let sizeValue = item["size"],
                  let stateString = item["state"] as? String else {
                return nil
            }

            let baseAddress = try parseAddressString(baseString)
            let size = try parseUInt64Value(sizeValue)
            let protectionString = (item["protection"] as? String) ?? "-"
            let typeString = (item["type"] as? String) ?? "unknown"

            return WineVirtualMemoryRegion(
                baseAddress: baseAddress,
                regionSize: size,
                protection: parseProtection(protectionString),
                state: parseMemoryState(stateString),
                type: parseMemoryType(typeString)
            )
        }

        return regions.sorted(by: { $0.baseAddress < $1.baseAddress })
    }

    private func readBytesViaBridge(pid: Int32, address: UInt64, count: Int) throws -> [UInt8] {
        let addressString = String(format: "0x%llx", address)
        let response: [String: Any]
        do {
            response = try runBridgeCommand(arguments: [
                "nt", "read-virtual-memory",
                "--pid", String(pid),
                "--address", addressString,
                "--size", String(count)
            ])
        } catch {
            guard shouldFallbackToLegacyBridgeCommand(after: error) else { throw error }
            response = try runBridgeCommand(arguments: [
                "memory", "read",
                "--pid", String(pid),
                "--address", addressString,
                "--size", String(count)
            ])
        }
        guard let dataHex = stringValue(in: response, keys: ["dataHex", "data_hex"]) else {
            throw WineProcessMemoryError.invalidBridgeResponse
        }

        return try bytes(fromHex: dataHex)
    }

    private func writeBytesViaBridge(pid: Int32, address: UInt64, data: Data) throws -> Int {
        let addressString = String(format: "0x%llx", address)
        let hex = hexString(from: data)
        let response: [String: Any]
        do {
            response = try runBridgeCommand(arguments: [
                "nt", "write-virtual-memory",
                "--pid", String(pid),
                "--address", addressString,
                "--hex", hex
            ])
        } catch {
            guard shouldFallbackToLegacyBridgeCommand(after: error) else { throw error }
            response = try runBridgeCommand(arguments: [
                "memory", "write",
                "--pid", String(pid),
                "--address", addressString,
                "--hex", hex
            ])
        }

        guard let bytesWrittenValue = response["bytesWritten"] else {
            throw WineProcessMemoryError.invalidBridgeResponse
        }
        return Int(try parseUInt64Value(bytesWrittenValue))
    }

    private func enumerateModulesViaBridge(pid: Int32) throws -> [WineModuleInfo] {
        let response = try runBridgeCommand(arguments: ["module", "list", "--pid", String(pid)])
        guard let moduleItems = response["modules"] as? [[String: Any]] else {
            throw WineProcessMemoryError.invalidBridgeResponse
        }

        return try moduleItems.compactMap { item -> WineModuleInfo? in
            guard let kind = item["kind"] as? String,
                  let name = item["name"] as? String,
                  let base = item["base"] as? String,
                  let end = item["end"] as? String else {
                return nil
            }
            let debugInfo = (item["debug"] as? String) ?? "-"
            return WineModuleInfo(
                kind: kind,
                name: name,
                baseAddress: try parseAddressString(base),
                endAddress: try parseAddressString(end),
                debugInfo: debugInfo
            )
        }
    }

    private func runBridgeCommand(arguments: [String]) throws -> [String: Any] {
        let runtime = try runtimeBinaries()
        guard let bridgeTool = runtime.bridgeTool else {
            throw WineProcessMemoryError.bridgeUnavailable
        }

        let environment = commandEnvironment(for: runtime)
        let result = try runProcess(
            executableURL: bridgeTool,
            arguments: ["--json"] + arguments,
            environment: environment,
            stdin: nil
        )

        let combined = result.stdout + result.stderr
        guard result.exitCode == 0 else {
            throw WineProcessMemoryError.commandFailed(
                "Memory bridge failed (\(result.exitCode)): \(combined.trimmingCharacters(in: .whitespacesAndNewlines))"
            )
        }

        guard let payload = extractJSONObjectPayload(from: combined) else {
            throw WineProcessMemoryError.invalidBridgeResponse
        }

        guard let data = payload.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WineProcessMemoryError.invalidBridgeResponse
        }

        if let operationSucceeded = object["ok"] as? Bool, !operationSucceeded {
            let message = (object["error"] as? String)
                ?? "Bridge operation reported failure."
            throw WineProcessMemoryError.commandFailed(message)
        }

        return object
    }

    private func cacheBridgeAvailability(_ isAvailable: Bool) -> Bool {
        lock.lock()
        cachedBridgeSupport = isAvailable
        lock.unlock()
        return isAvailable
    }

    private func parseBridgeCapabilityProbe(_ probe: ProcessExecutionResult) throws -> Bool {
        guard probe.exitCode == 0,
              let payload = extractJSONObjectPayload(from: probe.stdout + probe.stderr),
              let payloadData = payload.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return false
        }

        guard let operationSucceeded = object["ok"] as? Bool,
              operationSucceeded,
              let schemaVersion = object["schemaVersion"] as? Int,
              schemaVersion >= 1,
              let capabilities = object["capabilities"] as? [String] else {
            return false
        }

        let availableCapabilities = Set(capabilities)
        let commonCapabilities: Set<String> = [
            "process.list",
            "module.list"
        ]
        let ntCapabilities: Set<String> = [
            "nt.queryVirtualMemory",
            "nt.readVirtualMemory",
            "nt.writeVirtualMemory"
        ]
        let ntSnakeCapabilities: Set<String> = [
            "nt.query_virtual_memory",
            "nt.read_virtual_memory",
            "nt.write_virtual_memory"
        ]
        let legacyCapabilities: Set<String> = [
            "memory.map",
            "memory.read",
            "memory.write"
        ]
        guard commonCapabilities.isSubset(of: availableCapabilities) else {
            return false
        }
        return ntCapabilities.isSubset(of: availableCapabilities)
            || ntSnakeCapabilities.isSubset(of: availableCapabilities)
            || legacyCapabilities.isSubset(of: availableCapabilities)
    }

    private func extractJSONObjectPayload(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.first == "{", trimmed.last == "}" {
            return trimmed
        }
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}") else {
            return nil
        }
        return String(trimmed[start...end])
    }

    private func parseAddressString(_ raw: String) throws -> UInt64 {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let value: UInt64?
        if normalized.hasPrefix("0x") {
            value = UInt64(normalized.dropFirst(2), radix: 16)
        } else {
            value = UInt64(normalized, radix: 16) ?? UInt64(normalized)
        }
        guard let value else {
            throw WineProcessMemoryError.invalidBridgeResponse
        }
        return value
    }

    private func parseUInt64Value(_ value: Any) throws -> UInt64 {
        if let number = value as? UInt64 { return number }
        if let number = value as? Int { return UInt64(number) }
        if let number = value as? Int64 { return UInt64(number) }
        if let string = value as? String {
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized.hasPrefix("0x"), let number = UInt64(normalized.dropFirst(2), radix: 16) {
                return number
            }
            if let number = UInt64(normalized) {
                return number
            }
        }
        throw WineProcessMemoryError.invalidBridgeResponse
    }

    private func bytes(fromHex hex: String) throws -> [UInt8] {
        let cleaned = hex
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count.isMultiple(of: 2) else {
            throw WineProcessMemoryError.invalidBridgeResponse
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            let pair = cleaned[index..<next]
            guard let byte = UInt8(pair, radix: 16) else {
                throw WineProcessMemoryError.invalidBridgeResponse
            }
            bytes.append(byte)
            index = next
        }

        return bytes
    }

    private func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private func stringValue(in response: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = response[key] as? String {
                return value
            }
        }
        return nil
    }

    private func queryMemoryMap(pid: Int32) throws -> [WineVirtualMemoryRegion] {
        let output = try runDebuggerCommand(pid: pid, commands: ["info maps"])
        return parseMemoryMap(from: output)
    }

    private func listWineProcesses() throws -> [WineProcessEntry] {
        let output = try runWineCommand(["cmd", "/c", "tasklist /fo csv /nh"])
        return output
            .components(separatedBy: .newlines)
            .compactMap(parseTasklistLine(_:))
    }

    private func parseTasklistLine(_ line: String) -> WineProcessEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.lowercased().hasPrefix("info:") else {
            return nil
        }

        let fields = trimmed
            .replacingOccurrences(of: "\"", with: "")
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard fields.count >= 2,
              let pid = Int32(fields[1]),
              !fields[0].isEmpty else {
            return nil
        }

        return WineProcessEntry(name: fields[0], pid: pid)
    }

    private func parseMemoryMap(from output: String) -> [WineVirtualMemoryRegion] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line -> WineVirtualMemoryRegion? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty,
                      let firstCharacter = trimmed.first,
                      firstCharacter.isHexDigit else {
                    return nil
                }

                let parts = trimmed.split(whereSeparator: \.isWhitespace)
                guard parts.count >= 3 else {
                    return nil
                }

                guard let startAddress = UInt64(parts[0], radix: 16),
                      let endAddress = UInt64(parts[1], radix: 16),
                      endAddress >= startAddress else {
                    return nil
                }

                let state = parseMemoryState(String(parts[2]))
                let type: WineVirtualMemoryType = parts.count >= 4
                    ? parseMemoryType(String(parts[3]))
                    : .unknown
                let protection: WineMemoryProtection = parts.count >= 5
                    ? parseProtection(String(parts[4]))
                    : []
                let regionSize = endAddress - startAddress + 1

                return WineVirtualMemoryRegion(
                    baseAddress: startAddress,
                    regionSize: regionSize,
                    protection: protection,
                    state: state,
                    type: type
                )
            }
            .sorted(by: { $0.baseAddress < $1.baseAddress })
    }

    private func parseMemoryState(_ rawValue: String) -> WineVirtualMemoryState {
        switch rawValue.lowercased() {
        case "commit":
            return .committed
        case "reserve":
            return .reserved
        case "free":
            return .free
        default:
            return .unknown
        }
    }

    private func parseMemoryType(_ rawValue: String) -> WineVirtualMemoryType {
        switch rawValue.lowercased() {
        case "image":
            return .image
        case "mapped":
            return .mapped
        case "private":
            return .privateMemory
        default:
            return .unknown
        }
    }

    private func parseProtection(_ rawValue: String) -> WineMemoryProtection {
        var protection: WineMemoryProtection = []
        for character in rawValue.uppercased() {
            switch character {
            case "R":
                protection.insert(.read)
            case "W":
                protection.insert(.write)
            case "X":
                protection.insert(.execute)
            case "C":
                protection.insert(.copyOnWrite)
            default:
                break
            }
        }

        return protection
    }

    private func parseModuleList(from output: String) -> [WineModuleInfo] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line -> WineModuleInfo? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                guard trimmed.contains("-"), !trimmed.hasPrefix("Module ") else {
                    return nil
                }

                let parts = trimmed.split(whereSeparator: \.isWhitespace)
                guard parts.count >= 5 else {
                    return nil
                }

                let kind = String(parts[0])
                let startToken = String(parts[1]).replacingOccurrences(of: "-", with: "")
                let endToken = String(parts[2])
                let debugInfo = String(parts[3])
                let moduleName = parts[4...].joined(separator: " ")

                guard let baseAddress = UInt64(startToken, radix: 16),
                      let endAddress = UInt64(endToken, radix: 16) else {
                    return nil
                }

                return WineModuleInfo(
                    kind: kind,
                    name: moduleName,
                    baseAddress: baseAddress,
                    endAddress: endAddress,
                    debugInfo: debugInfo
                )
            }
    }

    private func normalizeModuleName(_ name: String) -> String {
        var value = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if value.hasSuffix(".dll") || value.hasSuffix(".exe") {
            value = String(value.dropLast(4))
        }

        return value
    }

    private func readBytes(pid: Int32, address: UInt64, count: Int) throws -> [UInt8] {
        guard count > 0 else { return [] }

        let command = "x/\(count)b 0x\(String(address, radix: 16))"
        let output = try runDebuggerCommand(pid: pid, commands: [command])
        return parseReadBytes(from: output)
    }

    private func parseReadBytes(from output: String) -> [UInt8] {
        if output.localizedCaseInsensitiveContains("invalid address") {
            return []
        }

        var bytes: [UInt8] = []
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separatorIndex = trimmed.lastIndex(of: ":") else {
                continue
            }

            let valueSlice = trimmed[trimmed.index(after: separatorIndex)...]
            for token in valueSlice.split(whereSeparator: \.isWhitespace) {
                guard token.count <= 2, let value = UInt8(token, radix: 16) else {
                    continue
                }
                bytes.append(value)
            }
        }

        return bytes
    }

    private func writeByte(pid: Int32, address: UInt64, value: UInt8) throws -> Bool {
        let addressString = "0x\(String(address, radix: 16))"
        let valueString = "0x\(String(format: "%02x", value))"
        let setCommand = "set *\(addressString) = \(valueString)"
        let output = try runDebuggerCommand(pid: pid, commands: [setCommand])
        if output.localizedCaseInsensitiveContains("syntax error")
            || output.localizedCaseInsensitiveContains("type mismatch")
            || output.localizedCaseInsensitiveContains("invalid address") {
            return false
        }

        let verifyBytes = try readBytes(pid: pid, address: address, count: 1)
        guard let firstByte = verifyBytes.first else {
            return false
        }

        return firstByte == value
    }

    private func writeBytes(pid: Int32, address: UInt64, data: Data) throws -> Int {
        var completed = 0
        for (index, value) in data.enumerated() {
            let writeAddress = address + UInt64(index)
            guard try writeByte(pid: pid, address: writeAddress, value: value) else {
                break
            }
            completed += 1
        }
        return completed
    }

    private func runWineCommand(_ args: [String]) throws -> String {
        let runtime = try runtimeBinaries()
        let environment = commandEnvironment(for: runtime)
        let result = try runProcess(
            executableURL: runtime.wine,
            arguments: args,
            environment: environment,
            stdin: nil
        )

        let output = result.stdout + result.stderr
        guard result.exitCode == 0 else {
            throw WineProcessMemoryError.commandFailed(
                "Wine command failed (\(result.exitCode)): \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
            )
        }

        return output
    }

    private func runDebuggerCommand(pid: Int32, commands: [String]) throws -> String {
        let runtime = try runtimeBinaries()
        let environment = commandEnvironment(for: runtime)
        var scriptCommands = commands
        if scriptCommands.last?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "quit" {
            scriptCommands.append("quit")
        }
        let script = scriptCommands.joined(separator: "\n") + "\n"
        let result = try runProcess(
            executableURL: runtime.winedbg,
            arguments: [String(pid)],
            environment: environment,
            stdin: script
        )
        let output = result.stdout + result.stderr
        if output.localizedCaseInsensitiveContains("can't attach process") {
            throw WineProcessMemoryError.processNotFound(pid)
        }
        guard result.exitCode == 0 else {
            let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw WineProcessMemoryError.commandFailed(
                "Debugger command failed (\(result.exitCode)): \(trimmedOutput)"
            )
        }

        return output
    }

    private func commandEnvironment(for runtime: RuntimeBinaries) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let runtimePath = runtime.wine.deletingLastPathComponent().path(percentEncoded: false)
        let existingPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "\(runtimePath):\(existingPath)"
        environment["WINEPREFIX"] = bottle.url.path(percentEncoded: false)
        environment["WINEDEBUG"] = "-all"
        environment.merge(environmentOverrides, uniquingKeysWith: { _, newValue in newValue })
        return environment
    }

    // swiftlint:disable:next function_parameter_count
    private func audit(
        operation: String,
        pid: Int32?,
        address: UInt64?,
        requestedByteCount: Int?,
        completedByteCount: Int?,
        result: String,
        transport: String? = nil,
        message: String
    ) {
        let event = MemoryAuditEvent(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            operation: operation,
            winePID: pid,
            address: address.map { String(format: "0x%llx", $0) },
            requestedByteCount: requestedByteCount,
            completedByteCount: completedByteCount,
            transport: transport ?? resolvedTransportPreference().rawValue,
            result: result,
            message: message
        )

        guard let data = try? JSONEncoder().encode(event) else {
            return
        }

        let auditURL = bottle.url.appending(path: ".vector-memory-audit.jsonl")
        let path = auditURL.path(percentEncoded: false)
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: auditURL) else {
            return
        }
        defer {
            try? handle.close()
        }

        _ = try? handle.seekToEnd()
        _ = try? handle.write(contentsOf: data)
        _ = try? handle.write(contentsOf: Data("\n".utf8))
    }

    private func runtimeBinaries() throws -> RuntimeBinaries {
        lock.lock()
        if let cachedRuntime {
            lock.unlock()
            return cachedRuntime
        }
        lock.unlock()

        let bundledWine = VectorWineInstaller.binFolder.appending(path: "wine64")
        let selectedWine = selectedWineBinary(fallback: bundledWine)

        let winedbgCandidates: [URL] = {
            var urls: [URL] = []
            urls.append(selectedWine.deletingLastPathComponent().appending(path: "winedbg"))

            if let compatibilityWine = VectorWineInstaller.steamCompatibilityWineBinary() {
                urls.append(compatibilityWine.deletingLastPathComponent().appending(path: "winedbg"))
            }

            return urls
        }()

        let bridgeCandidates: [URL] = {
            var urls: [URL] = []
            if let bridgeOverride = environmentOverrides["VECTOR_WINE_MEMCTL_OVERRIDE"]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !bridgeOverride.isEmpty {
                urls.append(URL(filePath: bridgeOverride))
            }
            urls.append(selectedWine.deletingLastPathComponent().appending(path: "vectorvmctl"))
            urls.append(selectedWine.deletingLastPathComponent().appending(path: "vector_memctl"))
            return urls
        }()

        guard let winedbg = winedbgCandidates.first(where: {
            let path = $0.path(percentEncoded: false)
            return FileManager.default.isExecutableFile(atPath: path)
        }) else {
            throw WineProcessMemoryError.debuggerUnavailable
        }

        let bridgeTool = bridgeCandidates.first(where: {
            let path = $0.path(percentEncoded: false)
            return FileManager.default.isExecutableFile(atPath: path)
        })

        let runtime = RuntimeBinaries(wine: selectedWine, winedbg: winedbg, bridgeTool: bridgeTool)
        lock.lock()
        cachedRuntime = runtime
        lock.unlock()
        return runtime
    }

    private func selectedWineBinary(fallback bundledWine: URL) -> URL {
        switch bottle.settings.runtimeSelection {
        case .compatibility:
            return VectorWineInstaller.steamCompatibilityWineBinary() ?? bundledWine
        case .crossover:
            return VectorWineInstaller.crossOverWineBinary() ?? bundledWine
        case .custom:
            let customPath = bottle.settings.customWineBinaryPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let customURL = URL(filePath: customPath)
            let customExecutablePath = customURL.path(percentEncoded: false)
            if FileManager.default.isExecutableFile(atPath: customExecutablePath) {
                return customURL
            }
            return bundledWine
        case .auto:
            if VectorWineInstaller.isCrossOverBottleURL(bottle.url),
               let crossOverWine = VectorWineInstaller.crossOverWineBinary() {
                return crossOverWine
            }
            return bundledWine
        case .bundled:
            return bundledWine
        }
    }

    private func runProcess(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        stdin: String?
    ) throws -> ProcessExecutionResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = executableURL.deletingLastPathComponent()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdinPipe = Pipe()

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = stdinPipe

        let stdoutSink = DataSink()
        let stderrSink = DataSink()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stdoutSink.append(data)
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stderrSink.append(data)
        }

        try process.run()

        if let stdin {
            stdinPipe.fileHandleForWriting.write(Data(stdin.utf8))
        }
        try? stdinPipe.fileHandleForWriting.close()

        process.waitUntilExit()

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        let remainingStdout = try stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
        let remainingStderr = try stderrPipe.fileHandleForReading.readToEnd() ?? Data()
        stdoutSink.append(remainingStdout)
        stderrSink.append(remainingStderr)

        let stdout = String(data: stdoutSink.snapshot(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrSink.snapshot(), encoding: .utf8) ?? ""
        return ProcessExecutionResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )
    }
}

// swiftlint:disable:this file_length
