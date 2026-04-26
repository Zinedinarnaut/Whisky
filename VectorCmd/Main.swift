//
//  Main.swift
//  VectorCmd
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

// swiftlint:disable file_length

import Foundation
import VectorKit
import SwiftyTextTable
import Progress
import SemanticVersion
import ArgumentParser

@main
struct Vector: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A CLI interface for Vector.",
        subcommands: [List.self,
                      Create.self,
                      Add.self,
//                      Export.self,
                      Delete.self,
                      Remove.self,
                      Run.self,
                      Shellenv.self,
                      VectorMemory.self,
                      VectorSecurity.self
                      /*Install.self,
                      Uninstall.self*/])
}

extension Vector {
    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List existing bottles.")

        mutating func run() throws {
            var bottlesList = BottleData()
            let bottles = bottlesList.loadBottles()

            let nameCol = TextTableColumn(header: "Name")
            let winVerCol = TextTableColumn(header: "Windows Version")
            let pathCol = TextTableColumn(header: "Path")

            var table = TextTable(columns: [nameCol, winVerCol, pathCol])
            for bottle in bottles {
                table.addRow(values: [bottle.settings.name,
                                      bottle.settings.windowsVersion.pretty(),
                                      bottle.url.prettyPath()])
            }

            print(table.render())
        }
    }

    struct Create: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Create a new bottle.")

        @Argument var name: String

        mutating func run() throws {
            let bottleURL = BottleData.defaultBottleDir.appending(path: UUID().uuidString)

            do {
                try FileManager.default.createDirectory(atPath: bottleURL.path(percentEncoded: false),
                                                        withIntermediateDirectories: true)
                let bottle = Bottle(bottleUrl: bottleURL, inFlight: true)
                // Should allow customisation
                bottle.settings.windowsVersion = .win10
                bottle.settings.name = name
//                try await Wine.changeWinVersion(bottle: bottle, win: winVersion)
//                let wineVer = try await Wine.wineVersion()
                bottle.settings.wineVersion = SemanticVersion(0, 0, 0)

                var bottlesList = BottleData()
                bottlesList.paths.append(bottleURL)
                print("Created new bottle \"\(name)\".")
            } catch {
                throw ValidationError("\(error)")
            }
        }
    }

    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Add an existing bottle.")

        @Argument var path: String

        mutating func run() throws {
            // Should be sanitised
            let bottleURL = URL(filePath: path)
            let settings = try BottleSettings.decode(from: bottleURL)
            var bottlesList = BottleData()
            bottlesList.paths.append(bottleURL)
            print("Bottle \"\(settings.name)\" added.")
        }
    }

    struct Export: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Export an existing bottle.")

        mutating func run() throws {
//            print("Create a bottle")
        }
    }

    struct Delete: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete an existing bottle from disk.")

        @Argument var name: String

        mutating func run() throws {
            var bottlesList = BottleData()
            let bottles = bottlesList.loadBottles()

            // Should ask for confirmation
            let bottleToRemove = bottles.first(where: { $0.settings.name == name })
            if let bottleToRemove = bottleToRemove {
                bottlesList.paths.removeAll(where: { $0 == bottleToRemove.url })
                do {
                    try FileManager.default.removeItem(at: bottleToRemove.url)
                    print("Deleted \"\(name)\".")
                } catch {
                    print(error)
                }
            } else {
                throw ValidationError("No bottle called \"\(name)\" found.")
            }
        }
    }

    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Remove an existing bottle from Vector.",
                                                        discussion: "This will not remove the bottle from disk.")

        @Argument var name: String

        mutating func run() throws {
            var bottlesList = BottleData()
            let bottles = bottlesList.loadBottles()

            let bottleToRemove = bottles.first(where: { $0.settings.name == name })
            if let bottleToRemove = bottleToRemove {
                bottlesList.paths.removeAll(where: { $0 == bottleToRemove.url })
                print("Removed \"\(name)\".")
            } else {
                throw ValidationError("No bottle called \"\(name)\" found.")
            }
        }
    }

    struct Run: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Run a program with Vector.")

        @Argument var bottleName: String
        @Argument var path: String
        @Argument var args: [String] = []

        mutating func run() throws {
            var bottlesList = BottleData()
            let bottles = bottlesList.loadBottles()

            guard let bottle = bottles.first(where: { $0.settings.name == bottleName }) else {
                throw ValidationError("A bottle with that name doesn't exist.")
            }

            let url = URL(fileURLWithPath: path)
            let program = Program(url: url, bottle: bottle)
            program.runInTerminal()
        }
    }

    struct Shellenv: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Prints export statements for a Bottle for eval.")

        @Argument var bottleName: String

        mutating func run() throws {
            var bottlesList = BottleData()
            let bottles = bottlesList.loadBottles()

            guard let bottle = bottles.first(where: { $0.settings.name == bottleName }) else {
                throw ValidationError("A bottle with that name doesn't exist.")
            }

            let envCmd = Wine.generateTerminalEnvironmentCommand(bottle: bottle)
            print(envCmd)

        }
    }

    struct Install: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Install VectorWine.")

        mutating func run() throws {

        }
    }

    struct Uninstall: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Uninstall VectorWine.")

        @Flag(name: [.long, .short], help: "Uninstall VectorWine") var vectorWine = false

        mutating func run() throws {

        }
    }
}

struct VectorMemory: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "memory",
        abstract: "Debug Wine process memory for a Bottle.",
        subcommands: [Status.self, Processes.self, Modules.self, Query.self, Read.self, Write.self]
    )

    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show active memory transport backend status."
        )

        @Argument var bottleName: String
        @Option(name: .long, help: "Transport backend: auto | ntBridge | debugger")
        var transport: String = "auto"

        mutating func run() throws {
            let bottle = try VectorMemory.loadBottle(named: bottleName)
            let service = try VectorMemory.makeService(
                bottle: bottle,
                transport: transport
            )
            let status = try service.transportStatus()

            print("Requested: \(status.requested.rawValue)")
            print("Effective: \(status.effective.rawValue)")
            print("Bridge available: \(status.bridgeAvailable ? "yes" : "no")")
            print("Debugger available: \(status.debuggerAvailable ? "yes" : "no")")
        }
    }

    struct Processes: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List Wine process IDs visible in the target bottle."
        )

        @Argument var bottleName: String
        @Option(name: .long, help: "Transport backend: auto | ntBridge | debugger")
        var transport: String = "auto"

        mutating func run() throws {
            let bottle = try VectorMemory.loadBottle(named: bottleName)
            let service = try VectorMemory.makeService(
                bottle: bottle,
                transport: transport
            )

            let (processes, source) = try VectorMemory.collectProcesses(using: service)
            let nameCol = TextTableColumn(header: "Process")
            let pidCol = TextTableColumn(header: "PID")
            var table = TextTable(columns: [nameCol, pidCol])

            for process in processes {
                table.addRow(values: [process.name, String(process.pid)])
            }

            print("Source: \(source)")
            print(table.render())
        }
    }

    struct Modules: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List modules for a Wine PID.")

        @Argument var bottleName: String
        @Argument var winePID: Int32
        @Option(name: .long, help: "Transport backend: auto | ntBridge | debugger")
        var transport: String = "auto"

        mutating func run() throws {
            let bottle = try VectorMemory.loadBottle(named: bottleName)
            let service = try VectorMemory.makeService(
                bottle: bottle,
                transport: transport
            )
            let handle = try service.openProcess(winePID: winePID)
            defer { service.closeHandle(handle) }

            let modules = try service.enumerateModules(handle: handle)
            let nameCol = TextTableColumn(header: "Module")
            let baseCol = TextTableColumn(header: "Base")
            let endCol = TextTableColumn(header: "End")
            let kindCol = TextTableColumn(header: "Kind")
            let dbgCol = TextTableColumn(header: "Debug")
            var table = TextTable(columns: [nameCol, baseCol, endCol, kindCol, dbgCol])

            for module in modules.sorted(by: { $0.baseAddress < $1.baseAddress }) {
                table.addRow(values: [
                    module.name,
                    VectorMemory.formatAddress(module.baseAddress),
                    VectorMemory.formatAddress(module.endAddress),
                    module.kind,
                    module.debugInfo
                ])
            }

            print(table.render())
        }
    }

    struct Query: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Query virtual memory region containing an address."
        )

        @Argument var bottleName: String
        @Argument var winePID: Int32
        @Argument var address: String
        @Option(name: .long, help: "Transport backend: auto | ntBridge | debugger")
        var transport: String = "auto"

        mutating func run() throws {
            let bottle = try VectorMemory.loadBottle(named: bottleName)
            let service = try VectorMemory.makeService(
                bottle: bottle,
                transport: transport
            )
            let handle = try service.openProcess(winePID: winePID)
            defer { service.closeHandle(handle) }

            let parsedAddress = try VectorMemory.parseAddress(address)
            guard let region = try service.virtualQueryEx(handle: handle, address: parsedAddress) else {
                print("No mapped region contains \(VectorMemory.formatAddress(parsedAddress)).")
                return
            }

            print("Base: \(VectorMemory.formatAddress(region.baseAddress))")
            print("Size: \(region.regionSize) bytes")
            print("State: \(region.state.rawValue)")
            print("Type: \(region.type.rawValue)")
            print("Protection: \(VectorMemory.describeProtection(region.protection))")
        }
    }

    struct Read: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Read bytes from a Wine process."
        )

        @Argument var bottleName: String
        @Argument var winePID: Int32
        @Argument var address: String
        @Argument var size: Int
        @Option(name: .long, help: "Transport backend: auto | ntBridge | debugger")
        var transport: String = "auto"

        mutating func run() throws {
            guard size > 0 else {
                throw ValidationError("Size must be greater than zero.")
            }

            let bottle = try VectorMemory.loadBottle(named: bottleName)
            let service = try VectorMemory.makeService(
                bottle: bottle,
                transport: transport
            )
            let handle = try service.openProcess(winePID: winePID)
            defer { service.closeHandle(handle) }

            let parsedAddress = try VectorMemory.parseAddress(address)
            let result = try service.readProcessMemory(
                handle: handle,
                address: parsedAddress,
                size: size
            )

            print("Read \(result.bytesRead)/\(result.requestedByteCount) bytes")
            print(VectorMemory.hexDump(data: result.data))
            if result.isPartial {
                print("Warning: partial read (crossed invalid/unreadable region).")
            }
        }
    }

    struct Write: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Write hex bytes to a Wine process."
        )

        @Argument var bottleName: String
        @Argument var winePID: Int32
        @Argument var address: String
        @Argument(parsing: .remaining) var hexBytes: [String]
        @Option(name: .long, help: "Transport backend: auto | ntBridge | debugger")
        var transport: String = "auto"

        mutating func run() throws {
            guard !hexBytes.isEmpty else {
                throw ValidationError("Provide bytes as hex, e.g. `4d 5a 90 00`.")
            }

            let bottle = try VectorMemory.loadBottle(named: bottleName)
            let service = try VectorMemory.makeService(
                bottle: bottle,
                transport: transport
            )
            let handle = try service.openProcess(winePID: winePID)
            defer { service.closeHandle(handle) }

            let parsedAddress = try VectorMemory.parseAddress(address)
            let data = try VectorMemory.parseHexBytes(hexBytes)
            let result = try service.writeProcessMemory(
                handle: handle,
                address: parsedAddress,
                data: data
            )

            print("Wrote \(result.bytesWritten)/\(result.requestedByteCount) bytes")
            if !result.succeeded {
                print("Warning: write was partial/blocked by runtime memory protections or debugger limitations.")
            }
        }
    }
}

private extension VectorMemory {
    static func makeService(
        bottle: Bottle,
        transport: String
    ) throws -> WineProcessMemoryService {
        let parsedTransport = try parseTransport(transport)
        return WineProcessMemoryService(
            bottle: bottle,
            preferredTransport: parsedTransport
        )
    }

    static func parseTransport(_ rawValue: String) throws -> WineProcessMemoryTransport {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let transport: WineProcessMemoryTransport?
        switch normalized {
        case "auto":
            transport = .auto
        case "ntbridge", "nt_bridge", "nt-bridge", "nt":
            transport = .ntBridge
        case "debugger", "winedbg", "dbg":
            transport = .debugger
        default:
            transport = nil
        }

        guard let transport else {
            throw ValidationError("Unknown transport '\(rawValue)'. Use auto | ntBridge | debugger.")
        }
        return transport
    }

    static func collectProcesses(using service: WineProcessMemoryService) throws -> ([WineProcessInfo], String) {
        let status = try service.transportStatus()
        let source = status.effective.rawValue
        let processes = try service.listProcesses()
        return (processes, source)
    }

    static func loadBottle(named bottleName: String) throws -> Bottle {
        var bottlesList = BottleData()
        let bottles = bottlesList.loadBottles()

        guard let bottle = bottles.first(where: { $0.settings.name == bottleName }) else {
            throw ValidationError("A bottle with that name doesn't exist.")
        }

        return bottle
    }

    static func parseAddress(_ rawValue: String) throws -> UInt64 {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError("Address cannot be empty.")
        }

        if trimmed.lowercased().hasPrefix("0x") {
            let hex = String(trimmed.dropFirst(2))
            if let value = UInt64(hex, radix: 16) {
                return value
            }
            throw ValidationError("Invalid hex address: \(rawValue)")
        }

        if let decimal = UInt64(trimmed) {
            return decimal
        }
        if let hex = UInt64(trimmed, radix: 16) {
            return hex
        }

        throw ValidationError("Invalid address: \(rawValue)")
    }

    static func parseHexBytes(_ values: [String]) throws -> Data {
        let merged = values.joined(separator: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "0x", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !merged.isEmpty, merged.count.isMultiple(of: 2) else {
            throw ValidationError("Hex bytes must contain an even number of digits.")
        }

        var data = Data(capacity: merged.count / 2)
        var cursor = merged.startIndex
        while cursor < merged.endIndex {
            let next = merged.index(cursor, offsetBy: 2)
            let slice = merged[cursor..<next]
            guard let value = UInt8(slice, radix: 16) else {
                throw ValidationError("Invalid hex byte sequence: \(slice)")
            }
            data.append(value)
            cursor = next
        }

        return data
    }

    static func formatAddress(_ value: UInt64) -> String {
        String(format: "0x%016llx", value)
    }

    static func describeProtection(_ protection: WineMemoryProtection) -> String {
        var flags: [String] = []
        if protection.contains(.read) { flags.append("R") }
        if protection.contains(.write) { flags.append("W") }
        if protection.contains(.execute) { flags.append("X") }
        if protection.contains(.copyOnWrite) { flags.append("C") }
        return flags.isEmpty ? "-" : flags.joined()
    }

    static func hexDump(data: Data) -> String {
        guard !data.isEmpty else { return "(empty)" }
        return data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}

struct VectorSecurity: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "security",
        abstract: "Protected multiplayer and studio-review tooling.",
        subcommands: [Host.self, Export.self]
    )

    struct Host: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print host security capabilities as JSON."
        )

        mutating func run() throws {
            let data = try VectorHostSecurityCapabilityProbe.currentJSON()
            guard let output = String(data: data, encoding: .utf8) else {
                throw ValidationError("Failed to encode host security report.")
            }
            print(output)
        }
    }

    struct Export: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Export a studio-review security bundle as JSON."
        )

        @Argument var bottleName: String
        @Argument var steamAppID: String

        mutating func run() throws {
            let bottle = try VectorMemory.loadBottle(named: bottleName)
            let bundle = VectorProtectedTitlePolicyEngine.studioReviewBundle(
                for: bottle,
                steamAppID: steamAppID
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(bundle)
            guard let output = String(data: data, encoding: .utf8) else {
                throw ValidationError("Failed to encode security export.")
            }
            print(output)
        }
    }
}

// swiftlint:enable file_length
