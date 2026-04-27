//
//  RunningProcessView.swift
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

struct BottleProcess: Identifiable, Sendable {
    var id: String { pid }
    var pid: String
    var procName: String
    var sessionName: String
    var sessionID: String
    var memoryUsage: String
    var memoryBytes: Int64?
    var status: String
    var userName: String
    var cpuTime: String
    var windowTitle: String

    var displayStatus: String {
        status.isEmpty ? "Unknown" : status
    }

    var displayWindowTitle: String {
        windowTitle.isEmpty || windowTitle == "N/A" ? "No visible window" : windowTitle
    }
}

struct RunningProcessesView: View {
    @ObservedObject var bottle: Bottle

    @State private var processes = [BottleProcess]()
    @State private var processSortOrder = [KeyPathComparator(\BottleProcess.pid)]
    @State private var selectedProcess: BottleProcess.ID?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastUpdated: Date?
    @State private var autoRefresh = false
    @State private var refreshTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding([.horizontal, .top])

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 10)
            }

            if isLoading && processes.isEmpty {
                loadingView
            } else if processes.isEmpty {
                emptyView
            } else {
                Table(processes, selection: $selectedProcess, sortOrder: $processSortOrder) {
                    TableColumn("PID", value: \.pid)
                        .width(min: 56, ideal: 70)
                    TableColumn("Executable", value: \.procName)
                        .width(min: 180, ideal: 230)
                    TableColumn("Memory", value: \.memoryUsage)
                        .width(min: 90, ideal: 110)
                    TableColumn("CPU Time", value: \.cpuTime)
                        .width(min: 90, ideal: 110)
                    TableColumn("Status", value: \.displayStatus)
                        .width(min: 90, ideal: 110)
                    TableColumn("User", value: \.userName)
                        .width(min: 120, ideal: 160)
                    TableColumn("Window", value: \.displayWindowTitle)
                        .width(min: 180, ideal: 260)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            footer
                .padding()
        }
        .onAppear {
            Task {
                await fetchProcesses()
            }
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
        .onChange(of: autoRefresh) { _, enabled in
            configureAutoRefresh(enabled)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Running Processes")
                        .font(.headline)
                    Text("Live process and resource snapshot for this bottle.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Auto refresh", isOn: $autoRefresh)
                    .toggleStyle(.switch)
            }

            HStack(spacing: 10) {
                ProcessMetricCard(title: "Processes", value: "\(processes.count)")
                ProcessMetricCard(title: "Memory", value: totalMemoryUsageText)
                ProcessMetricCard(title: "Active", value: "\(activeProcessCount)")
                ProcessMetricCard(title: "Updated", value: lastUpdatedText)
            }
        }
    }

    private var footer: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                Text("Refreshing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("process.table.refresh") {
                Task {
                    await fetchProcesses()
                }
            }
            Button("Kill All", role: .destructive) {
                Task {
                    await killAllProcesses()
                }
            }
            Button("process.table.kill") {
                Task {
                    await killProcess()
                }
            }
            .disabled(selectedProcess == nil)
        }
    }

    private var loadingView: some View {
        HStack(alignment: .center) {
            Spacer()
            VStack(alignment: .center) {
                ProgressView()
                    .padding()
                Text("process.table.loading")
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "cpu")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
            Text("No running Wine processes")
                .font(.headline)
            Text("Launch something in this bottle, then refresh this panel.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var totalMemoryUsageText: String {
        let totalBytes = processes.compactMap(\.memoryBytes).reduce(Int64(0), +)
        guard totalBytes > 0 else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .memory)
    }

    private var activeProcessCount: Int {
        processes.filter {
            let status = $0.displayStatus.lowercased()
            return status.contains("running") || status.contains("unknown")
        }.count
    }

    private var lastUpdatedText: String {
        guard let lastUpdated else { return "Never" }

        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: lastUpdated)
    }

    private func configureAutoRefresh(_ enabled: Bool) {
        refreshTask?.cancel()
        refreshTask = nil

        guard enabled else { return }

        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                await fetchProcesses(showLoadingIndicator: false)
            }
        }
    }

    func fetchProcesses(showLoadingIndicator: Bool = true) async {
        if showLoadingIndicator {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
        }

        let output: String
        do {
            output = try await Wine.runWine(["tasklist.exe", "/fo", "csv", "/nh", "/v"], bottle: bottle)
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Unable to read bottle processes: \(error.localizedDescription)"
            }
            return
        }

        let newProcessList = TasklistParser.parse(output)
        await MainActor.run {
            processes = newProcessList.sorted(using: processSortOrder)
            selectedProcess = processes.contains { $0.id == selectedProcess } ? selectedProcess : nil
            isLoading = false
            errorMessage = nil
            lastUpdated = Date()
        }
    }

    func killProcess() async {
        guard let selectedProcess,
              let thisProcess = await MainActor.run(body: {
                  processes.first(where: { $0.id == selectedProcess })
              }) else {
            return
        }

        do {
            try await Wine.runWine(["taskkill.exe", "/PID", thisProcess.pid, "/F"], bottle: bottle)
            try await Task.sleep(nanoseconds: 2_000_000_000)
        } catch {
            await MainActor.run {
                errorMessage = "Unable to kill \(thisProcess.procName): \(error.localizedDescription)"
            }
        }
        await fetchProcesses()
    }

    func killAllProcesses() async {
        do {
            try Wine.killBottle(bottle: bottle)
            try await Task.sleep(nanoseconds: 2_000_000_000)
        } catch {
            await MainActor.run {
                errorMessage = "Unable to kill bottle processes: \(error.localizedDescription)"
            }
        }
        await fetchProcesses()
    }

}

private enum TasklistParser {
    static func parse(_ output: String) -> [BottleProcess] {
        output
            .split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
            .compactMap { line -> BottleProcess? in
                let fields = parseCSVLine(String(line))
                guard fields.count >= 2 else {
                    return nil
                }

                let procName = fields[safe: 0]
                let pid = fields[safe: 1]
                guard !procName.isEmpty,
                      !pid.isEmpty,
                      !procName.localizedCaseInsensitiveContains("Image Name"),
                      !procName.localizedCaseInsensitiveContains("INFO:") else {
                    return nil
                }

                let memoryUsage = fields[safe: 4]
                return BottleProcess(
                    pid: pid,
                    procName: procName,
                    sessionName: fields[safe: 2],
                    sessionID: fields[safe: 3],
                    memoryUsage: memoryUsage.isEmpty ? "Unknown" : memoryUsage,
                    memoryBytes: parseMemoryBytes(memoryUsage),
                    status: fields[safe: 5],
                    userName: fields[safe: 6],
                    cpuTime: fields[safe: 7].isEmpty ? "Unknown" : fields[safe: 7],
                    windowTitle: fields[safe: 8]
                )
            }
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var isQuoted = false
        var iterator = line.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if isQuoted, let nextCharacter = iterator.next() {
                    if nextCharacter == "\"" {
                        current.append(nextCharacter)
                    } else {
                        isQuoted = false
                        if nextCharacter != "," {
                            current.append(nextCharacter)
                        } else {
                            fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                            current = ""
                        }
                    }
                } else {
                    isQuoted.toggle()
                }
            } else if character == ",", !isQuoted {
                fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(character)
            }
        }

        fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }

    private static func parseMemoryBytes(_ rawValue: String) -> Int64? {
        let digits = rawValue.filter(\.isNumber)
        guard let kilobytes = Int64(digits), kilobytes > 0 else {
            return nil
        }
        return kilobytes * 1_024
    }
}

private struct ProcessMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private extension Array where Element == String {
    subscript(safe index: Int) -> String {
        indices.contains(index) ? self[index] : ""
    }
}
