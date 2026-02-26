//
//  VectorWineDownloadView.swift
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

struct VectorWineDownloadView: View {
    @State private var fractionProgress: Double = 0
    @State private var completedBytes: Int64 = 0
    @State private var totalBytes: Int64 = 0
    @State private var downloadSpeed: Double = 0
    @State private var downloadTask: URLSessionDownloadTask?
    @State private var observation: NSKeyValueObservation?
    @State private var startTime: Date?
    @State private var downloadError: String?

    @Binding var tarLocation: URL
    @Binding var runtimeManifest: VectorWineRuntimeManifest?
    @Binding var path: [SetupStage]

    var body: some View {
        VStack {
            VStack {
                Text("setup.vectorwine.download")
                    .font(.title)
                    .fontWeight(.bold)
                Text("setup.vectorwine.download.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                VStack {
                    ProgressView(value: fractionProgress, total: 1)
                    HStack {
                        HStack {
                            Text(verbatim: formattedProgressStatusText())
                            Spacer()
                        }
                        .font(.subheadline)
                        .monospacedDigit()
                    }

                    if let downloadError {
                        HStack {
                            Text(downloadError)
                                .font(.caption)
                                .foregroundStyle(.red)
                            Spacer()
                            Button("setup.retry") {
                                startDownload()
                            }
                        }
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            Spacer()
        }
        .frame(width: 400, height: 200)
        .onAppear {
            startDownload()
        }
        .onDisappear {
            observation?.invalidate()
            observation = nil
            downloadTask?.cancel()
            downloadTask = nil
        }
    }

    func formatBytes(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.zeroPadsFractionDigits = true
        return formatter.string(fromByteCount: bytes)
    }

    func shouldShowEstimate() -> Bool {
        let elapsedTime = Date().timeIntervalSince(startTime ?? Date())
        return Int(elapsedTime.rounded()) > 5 && completedBytes != 0 && downloadSpeed > 0
    }

    func formatRemainingTime(remainingBytes: Int64) -> String {
        guard downloadSpeed > 0 else { return "" }
        let remainingTimeInSeconds = Double(remainingBytes) / downloadSpeed

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        if shouldShowEstimate() {
            return formatter.string(from: TimeInterval(remainingTimeInSeconds)) ?? ""
        } else {
            return ""
        }
    }

    func formattedProgressStatusText() -> String {
        let progressText = String(
            format: String(localized: "setup.vectorwine.progress"),
            formatBytes(bytes: completedBytes),
            formatBytes(bytes: totalBytes)
        )
        guard shouldShowEstimate() else {
            return progressText
        }

        let etaText = String(
            format: String(localized: "setup.vectorwine.eta"),
            formatRemainingTime(remainingBytes: totalBytes - completedBytes)
        )
        return "\(progressText) \(etaText)"
    }

    func startDownload() {
        resetDownloadState()

        Task {
            await startRuntimeDownload()
        }
    }

    func proceed() {
        path.append(.vectorWineInstall)
    }

    @MainActor
    private func resetDownloadState() {
        observation?.invalidate()
        observation = nil
        downloadTask?.cancel()
        downloadTask = nil
        downloadError = nil
        completedBytes = 0
        totalBytes = 0
        fractionProgress = 0
        startTime = Date()
    }

    private func startRuntimeDownload() async {
        let manifest = await VectorWineInstaller.runtimeManifest()
        let task = createDownloadTask(for: manifest)

        await MainActor.run {
            runtimeManifest = manifest
            downloadTask = task
            observation = task.observe(\.countOfBytesReceived) { task, _ in
                Task { @MainActor in
                    updateDownloadProgress(from: task)
                }
            }
            task.resume()
        }
    }

    private func createDownloadTask(for manifest: VectorWineRuntimeManifest) -> URLSessionDownloadTask {
        URLSession(configuration: .ephemeral).downloadTask(with: manifest.archiveURL) { url, _, error in
            Task {
                await handleDownloadCompletion(url: url, error: error, manifest: manifest)
            }
        }
    }

    private func handleDownloadCompletion(url: URL?, error: Error?, manifest: VectorWineRuntimeManifest) async {
        if let error {
            await MainActor.run {
                downloadError = error.localizedDescription
            }
            return
        }

        guard let url else {
            await MainActor.run {
                downloadError = "Download finished without a file URL"
            }
            return
        }

        do {
            try VectorWineInstaller.verifyArchive(at: url, expectedSHA256: manifest.archiveSHA256)
            await MainActor.run {
                tarLocation = url
                runtimeManifest = manifest
                proceed()
            }
        } catch {
            try? FileManager.default.removeItem(at: url)
            await MainActor.run {
                downloadError = "Runtime checksum verification failed. Please retry."
            }
        }
    }

    @MainActor
    private func updateDownloadProgress(from task: URLSessionDownloadTask) {
        let currentTime = Date()
        let elapsedTime = currentTime.timeIntervalSince(startTime ?? currentTime)
        if completedBytes > 0 {
            downloadSpeed = Double(completedBytes) / elapsedTime
        }

        totalBytes = task.countOfBytesExpectedToReceive
        completedBytes = task.countOfBytesReceived

        if totalBytes > 0 {
            fractionProgress = Double(completedBytes) / Double(totalBytes)
        } else {
            fractionProgress = 0
        }
    }
}
