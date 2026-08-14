import SwiftUI
import AVKit
import UIKit

struct CompressOnlyView: View {
    var initialURL: URL? = nil

    @EnvironmentObject private var historyStore: HistoryStore

    @State private var showPicker = false
    @State private var isImporting = false
    @State private var importedVideoURL: URL?
    @State private var importedAssetIdentifier: String?
    @State private var player: AVPlayer?
    @State private var originalSizeBytes: Int64?
    @State private var sourceDurationSeconds: Double?
    @State private var compressedSizeBytes: Int64?
    @State private var isCompressing = false
    @State private var didSave = false
    @State private var didDeleteOriginal = false
    @State private var isDeletingOriginal = false
    @State private var errorMessage: String?
    @AppStorage("compressionTier") private var tierRawValue = CompressionTier.balanced.rawValue

    @StateObject private var compressionService = VideoCompressionService()

    private var tier: CompressionTier { CompressionTier(rawValue: tierRawValue) ?? .balanced }

    var body: some View {
        VStack(spacing: 20) {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

                if isCompressing {
                    CompressProgressView(progress: compressionService.progress) {
                        compressionService.cancel()
                    }
                } else if didSave, let compressedSizeBytes, let originalSizeBytes {
                    sizeCompare(before: originalSizeBytes, after: compressedSizeBytes)
                    Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                        .font(.subheadline.weight(.semibold))
                    deleteOriginalRow
                } else {
                    if let originalSizeBytes {
                        HStack {
                            Text("Source")
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                            Spacer()
                            Text(ByteFormatting.humanReadableSize(originalSizeBytes))
                                .font(Theme.mono)
                        }
                    }

                    qualityPicker

                    Button {
                        Task { await compress() }
                    } label: {
                        Text("Compress")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.board)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                    }
                }
            } else if isImporting {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("Preparing video…")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                    Text("Large or iCloud videos can take a moment to download - no size limit, just hang tight.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 60)
                Spacer()
            } else {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.inkSoft)
                        Text("No video selected")
                            .font(.headline)
                        Text("Import a video from your library to compress it. Any length, any file size.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    FeatureInfoCard(rows: [
                        .init(icon: "wand.and.stars", label: "What it does", value: "Re-encodes to HEVC on-device"),
                        .init(icon: "clock", label: "Takes about", value: "10–90s, depends on length"),
                        .init(icon: "checkmark.seal", label: "Benefit", value: "Up to 80% smaller, same look"),
                        .init(icon: "infinity", label: "Size limit", value: "None - 4K, long takes, all fine"),
                    ])
                }
                .padding(.top, 32)
                Spacer()
            }

            Button {
                showPicker = true
            } label: {
                Label("Import video", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.line))
            }
        }
        .padding()
        .background(Theme.paper)
        .navigationTitle("Compress")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            VideoPicker(onPicked: { result in
                handlePicked(result)
            }, onImportStart: {
                isImporting = true
            })
            .ignoresSafeArea()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .onAppear {
            guard player == nil, let initialURL else { return }
            load(url: initialURL)
        }
    }

    private var qualityPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Quality", selection: $tierRawValue) {
                ForEach(CompressionTier.allCases) { tier in
                    Text(tier.label).tag(tier.rawValue)
                }
            }
            .pickerStyle(.segmented)

            if let sourceDurationSeconds {
                let estimate = FFmpegCommandBuilder.estimatedOutputBytes(durationSeconds: sourceDurationSeconds, tier: tier)
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox").font(.caption2).foregroundStyle(Theme.inkSoft)
                    Text("Estimated size: ~\(ByteFormatting.humanReadableSize(estimate))")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }

    private func sizeCompare(before: Int64, after: Int64) -> some View {
        let savings = ByteFormatting.savingsPercentage(originalBytes: before, compressedBytes: after)
        let maxHeight: CGFloat = 70
        let minHeight: CGFloat = 14
        let largest = max(before, after, 1)
        let beforeHeight = max(minHeight, maxHeight * CGFloat(before) / CGFloat(largest))
        let afterHeight = max(minHeight, maxHeight * CGFloat(after) / CGFloat(largest))
        return VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 18) {
                barColumn(label: "source", value: ByteFormatting.humanReadableSize(before), height: beforeHeight, color: Theme.surface3)
                barColumn(label: "result", value: ByteFormatting.humanReadableSize(after), height: afterHeight, color: Theme.accent)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

            Text(savings >= 0 ? "-\(savings)% size" : "+\(-savings)% size, higher quality")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)

            Button {
                resetState()
            } label: {
                Text("Compress another")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.line))
            }
        }
    }

    @ViewBuilder
    private var deleteOriginalRow: some View {
        if let importedAssetIdentifier {
            if didDeleteOriginal {
                Label("Original deleted", systemImage: "trash.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.discard)
            } else if isDeletingOriginal {
                ProgressView().tint(Theme.discard)
            } else {
                Button(role: .destructive) {
                    Task { await deleteOriginal(identifier: importedAssetIdentifier) }
                } label: {
                    Label("Delete original from Photos", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.discard)
                }
            }
        }
    }

    private func deleteOriginal(identifier: String) async {
        isDeletingOriginal = true
        defer { isDeletingOriginal = false }
        do {
            try await PhotoLibrarySaver.deleteAsset(identifier: identifier)
            didDeleteOriginal = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func barColumn(label: String, value: String, height: CGFloat, color: Color) -> some View {
        VStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 6)
                .fill(color)
                .frame(width: 34, height: height)
            Text(label).font(.caption2.monospaced()).foregroundStyle(Theme.inkSoft)
            Text(value).font(.caption.monospaced().weight(.bold))
        }
    }

    private func handlePicked(_ result: Result<PickedVideo, Error>) {
        resetState()
        isImporting = false
        switch result {
        case .success(let picked):
            importedAssetIdentifier = picked.assetIdentifier
            load(url: picked.url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func load(url: URL) {
        importedVideoURL = url
        player = AVPlayer(url: url)
        originalSizeBytes = fileSize(at: url)
        Task {
            sourceDurationSeconds = try? await compressionService.videoDurationSeconds(url: url)
        }
    }

    private func compress() async {
        guard let importedVideoURL else { return }
        isCompressing = true
        defer { isCompressing = false }

        // Best-effort: ask iOS for extra time so compression keeps going if the user
        // backgrounds the app mid-encode, instead of being suspended immediately.
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "compress-video")
        defer { UIApplication.shared.endBackgroundTask(backgroundTask) }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("compressed-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        let startedAt = Date()
        do {
            try await compressionService.compress(inputURL: importedVideoURL, outputURL: outputURL, tier: tier)
            let resultBytes = fileSize(at: outputURL)
            compressedSizeBytes = resultBytes
            try await PhotoLibrarySaver.save(videoURL: outputURL)
            didSave = true
            let elapsed = Date().timeIntervalSince(startedAt)
            if let originalSizeBytes, let resultBytes {
                let savings = ByteFormatting.savingsPercentage(originalBytes: originalSizeBytes, compressedBytes: resultBytes)
                historyStore.record(HistoryEntry(
                    filename: importedVideoURL.lastPathComponent,
                    kind: .compress,
                    resultTag: "-\(savings)%",
                    originalBytes: originalSizeBytes,
                    resultBytes: resultBytes,
                    sourceDurationSeconds: sourceDurationSeconds,
                    processingSeconds: elapsed
                ))
            }
            try? FileManager.default.removeItem(at: outputURL)
        } catch {
            errorMessage = error.localizedDescription
            try? FileManager.default.removeItem(at: outputURL)
        }
    }

    private func resetState() {
        importedVideoURL = nil
        importedAssetIdentifier = nil
        player = nil
        originalSizeBytes = nil
        sourceDurationSeconds = nil
        compressedSizeBytes = nil
        didSave = false
        didDeleteOriginal = false
        errorMessage = nil
    }

    private func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
}

/// Mirrors the visual language of ProcessingView (Cut silence & retakes) so both
/// long-running tools feel consistent, even though Compress is a single ffmpeg pass
/// rather than a multi-stage pipeline - the steps here are progress bands, not real
/// separate phases.
private struct CompressProgressView: View {
    let progress: Double
    let onCancel: () -> Void

    private var steps: [(title: String, threshold: Double)] {
        [("Preparing video", 0.05), ("Encoding to HEVC", 0.9), ("Finishing up", 1.0)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(progress * 100))%")
                    .font(Theme.displayFont(20))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Button("Cancel", role: .destructive, action: onCancel)
                    .font(.caption)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface2)
                    Capsule().fill(Theme.accent).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    let previousThreshold = index == 0 ? 0 : steps[index - 1].threshold
                    let isDone = progress >= step.threshold
                    let isActive = progress >= previousThreshold && !isDone
                    HStack(spacing: 10) {
                        ZStack {
                            if isDone {
                                Circle().fill(Theme.accent)
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.accentInk)
                            } else if isActive {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Circle().fill(Theme.paper).overlay(Circle().stroke(Theme.line))
                            }
                        }
                        .frame(width: 18, height: 18)
                        Text(step.title)
                            .font(.caption)
                            .foregroundStyle(isDone || isActive ? Theme.ink : Theme.inkSoft)
                            .fontWeight(isDone || isActive ? .semibold : .regular)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

#Preview {
    NavigationStack { CompressOnlyView() }.environmentObject(HistoryStore.shared)
}
