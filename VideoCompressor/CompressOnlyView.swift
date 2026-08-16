import SwiftUI
import AVKit
import UIKit

struct CompressOnlyView: View {
    var initialURL: URL? = nil

    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var usageLimiter: UsageLimiter
    @State private var showPaywall = false
    @State private var paywallReason = "You've used all 10 free videos today."
    @State private var pendingHistoryID: UUID?

    @State private var showPicker = false
    @State private var isImporting = false
    @State private var importedVideoURL: URL?
    @State private var importedAssetIdentifier: String?
    @State private var player: AVPlayer?
    @State private var originalSizeBytes: Int64?
    @State private var sourceDurationSeconds: Double?
    @State private var compressedSizeBytes: Int64?
    @State private var isCompressing = false
    @State private var isSaving = false
    @State private var pendingOutputURL: URL?
    @State private var pendingElapsedSeconds: Double?
    @State private var didSave = false
    @State private var didDeleteOriginal = false
    @State private var isDeletingOriginal = false
    @State private var deleteOriginalAfterSave = false
    @State private var errorMessage: String?
    @AppStorage("compressionTier") private var tierRawValue = CompressionTier.balanced.rawValue

    // Batch/queue compress: pick several videos, they compress one after another
    // at the current quality tier, each saved to Photos and logged to History as
    // it finishes - no manual "compress" tap per file.
    @State private var showBatchPicker = false
    @State private var batchQueue: [PickedVideo] = []
    @State private var showBatchReview = false
    @State private var isBatchProcessing = false
    @State private var batchIndex = 0
    @State private var batchResults: [(filename: String, before: Int64, after: Int64)] = []
    @State private var batchDone = false
    @State private var deleteOriginalsAfterBatch = false

    @StateObject private var compressionService = VideoCompressionService()

    private var tier: CompressionTier { CompressionTier(rawValue: tierRawValue) ?? .balanced }

    var body: some View {
        ScrollView {
        VStack(spacing: 20) {
            if showBatchReview {
                batchReviewView
            } else if isBatchProcessing || batchDone {
                batchProgressView
            } else if let player {
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
                    Button {
                        resetState()
                    } label: {
                        Text("Compress another")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.line))
                    }
                } else if let compressedSizeBytes, let originalSizeBytes {
                    // Encoded but not saved yet - the user confirms before it touches Photos.
                    sizeCompareBars(before: originalSizeBytes, after: compressedSizeBytes)
                    if isSaving {
                        ProgressView()
                    } else {
                        Button {
                            Task { await saveResult() }
                        } label: {
                            Text("Save to Photos")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.board)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                        }
                    }
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

                    if importedAssetIdentifier != nil {
                        Toggle(isOn: $deleteOriginalAfterSave) {
                            Label("Delete original after saving", systemImage: "trash")
                                .font(.caption)
                        }
                        .tint(Theme.discard)
                    }

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

                    if !subscriptionStore.isSubscribed {
                        Text("\(usageLimiter.remainingToday) of \(UsageLimiter.dailyFreeLimit) free videos left today")
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft)
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

            if !showBatchReview && !isBatchProcessing && !batchDone {
                Button {
                    showPicker = true
                } label: {
                    Label("Import video", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.line))
                }

                if player == nil {
                    Button {
                        showBatchPicker = true
                    } label: {
                        Label("Import multiple (batch)", systemImage: "square.stack.3d.up")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.line))
                    }
                }
            }
        }
        .padding()
        }
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
        .sheet(isPresented: $showBatchPicker) {
            BatchVideoPicker(onPicked: { picked in
                batchQueue = picked
                if !picked.isEmpty {
                    showBatchReview = true
                }
            })
            .ignoresSafeArea()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: paywallReason)
        }
        .onAppear {
            guard player == nil, let initialURL else { return }
            load(url: initialURL)
#if DEBUG
            if UserDefaults.standard.bool(forKey: "debugAutoRun") {
                Task {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    await compress()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await saveResult()
                }
            }
#endif
        }
    }

    // Shown after picking a batch of videos, before compressing - mirrors what the
    // single-video screen shows before its Compress tap (size, quality, delete toggle),
    // so batch mode isn't a black box that just starts running the moment files are
    // picked.
    private var batchReviewView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(batchQueue.count) video\(batchQueue.count == 1 ? "" : "s") selected")
                    .font(.headline)
                let totalSize = batchQueue.reduce(Int64(0)) { $0 + (fileSize(at: $1.url) ?? 0) }
                Text("Total: \(ByteFormatting.humanReadableSize(totalSize))")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }

            VStack(spacing: 0) {
                ForEach(Array(batchQueue.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 20)
                        Text(item.url.lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(ByteFormatting.humanReadableSize(fileSize(at: item.url) ?? 0))
                            .font(.caption.monospaced())
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.vertical, 6)
                    if index < batchQueue.count - 1 {
                        Divider().overlay(Theme.line)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

            VStack(alignment: .leading, spacing: 8) {
                Text("Quality").font(.caption).foregroundStyle(Theme.inkSoft)
                Picker("Quality", selection: $tierRawValue) {
                    ForEach(CompressionTier.allCases) { tier in
                        Text(tier.label).tag(tier.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Toggle(isOn: $deleteOriginalsAfterBatch) {
                Label("Delete originals after saving", systemImage: "trash")
                    .font(.caption)
            }
            .tint(Theme.discard)

            Button {
                showBatchReview = false
                Task { await processBatch() }
            } label: {
                Text("Compress \(batchQueue.count) video\(batchQueue.count == 1 ? "" : "s")")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.board)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
            }

            Button {
                batchQueue = []
                showBatchReview = false
            } label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var batchProgressView: some View {
        VStack(spacing: 16) {
            if isBatchProcessing {
                VStack(spacing: 10) {
                    Text("Compressing \(batchIndex + 1) of \(batchQueue.count)")
                        .font(.headline)
                    Text(batchQueue.indices.contains(batchIndex) ? batchQueue[batchIndex].url.lastPathComponent : "")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.surface2)
                            Capsule().fill(Theme.accent)
                                .frame(width: geo.size.width * compressionService.progress)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.top, 20)
            } else if batchDone {
                VStack(spacing: 14) {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.accent)
                        Text("\(batchResults.count) video\(batchResults.count == 1 ? "" : "s") compressed")
                            .font(.headline)
                    }

                    let totalBefore = batchResults.reduce(Int64(0)) { $0 + $1.before }
                    let totalAfter = batchResults.reduce(Int64(0)) { $0 + $1.after }
                    if totalBefore > 0 {
                        sizeCompareBars(before: totalBefore, after: totalAfter)
                    }
                }
                .padding(.top, 20)
            }

            if !batchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(batchResults.enumerated()), id: \.offset) { index, result in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(result.filename)
                                    .font(.caption)
                                    .lineLimit(1)
                                Text("\(ByteFormatting.humanReadableSize(result.before)) → \(ByteFormatting.humanReadableSize(result.after))")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            Spacer()
                            Text("-\(ByteFormatting.savingsPercentage(originalBytes: result.before, compressedBytes: result.after))%")
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                        .padding(.vertical, 8)
                        if index < batchResults.count - 1 {
                            Divider().overlay(Theme.line)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            }

            Spacer()

            if batchDone {
                Button {
                    batchQueue = []
                    batchResults = []
                    batchDone = false
                    batchIndex = 0
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.board)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                }
            }
        }
    }

    private func processBatch() async {
        guard subscriptionStore.isSubscribed || usageLimiter.canUse(count: batchQueue.count) else {
            paywallReason = "This batch needs \(batchQueue.count) of your free videos today, but only \(usageLimiter.remainingToday) are left."
            showPaywall = true
            return
        }
        isBatchProcessing = true
        batchResults = []
        defer { isBatchProcessing = false; batchDone = true }
        NotificationManager.requestAuthorizationIfNeeded()

        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "batch-compress")
        defer { UIApplication.shared.endBackgroundTask(backgroundTask) }

        for (index, item) in batchQueue.enumerated() {
            batchIndex = index
            let before = fileSize(at: item.url) ?? 0
            let duration = try? await compressionService.videoDurationSeconds(url: item.url)
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("compressed-\(UUID().uuidString)")
                .appendingPathExtension("mp4")
            let startedAt = Date()
            do {
                try await compressionService.compress(inputURL: item.url, outputURL: outputURL, tier: tier)
                let after = fileSize(at: outputURL) ?? 0
                let resultAssetIdentifier = try await PhotoLibrarySaver.save(videoURL: outputURL)
                if deleteOriginalsAfterBatch, let assetIdentifier = item.assetIdentifier {
                    try? await PhotoLibrarySaver.deleteAsset(identifier: assetIdentifier)
                }
                let elapsed = Date().timeIntervalSince(startedAt)
                let savings = ByteFormatting.savingsPercentage(originalBytes: before, compressedBytes: after)
                historyStore.record(HistoryEntry(
                    filename: item.url.lastPathComponent,
                    kind: .compress,
                    resultTag: "-\(savings)%",
                    originalBytes: before,
                    resultBytes: after,
                    sourceDurationSeconds: duration,
                    processingSeconds: elapsed,
                    resultAssetIdentifier: resultAssetIdentifier
                ))
                batchResults.append((filename: item.url.lastPathComponent, before: before, after: after))
                if !subscriptionStore.isSubscribed { usageLimiter.recordUsage() }
            } catch {
                // Skip this file, keep processing the rest of the queue instead of
                // aborting the whole batch over one bad file.
            }
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: item.url)
        }

        NotificationManager.notifyJobFinished(
            title: "Batch compress finished",
            body: "\(batchResults.count) video\(batchResults.count == 1 ? "" : "s") compressed and saved to Photos."
        )
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
                    if let originalSizeBytes, originalSizeBytes > 0 {
                        let estimatedSavings = ByteFormatting.savingsPercentage(originalBytes: originalSizeBytes, compressedBytes: estimate)
                        Text("(~\(estimatedSavings)% smaller)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    private func sizeCompare(before: Int64, after: Int64) -> some View {
        sizeCompareBars(before: before, after: after)
    }

    private func sizeCompareBars(before: Int64, after: Int64) -> some View {
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
        guard subscriptionStore.isSubscribed || usageLimiter.canUse() else {
            paywallReason = "You've used all 10 free videos today."
            showPaywall = true
            return
        }
        isCompressing = true
        defer { isCompressing = false }
        NotificationManager.requestAuthorizationIfNeeded()

        // Recorded before any real work happens - if the app gets killed mid-job (e.g.
        // backgrounded through a very long encode) this shows up as "Interrupted" in
        // History next launch instead of just vanishing.
        pendingHistoryID = historyStore.recordPending(
            filename: importedVideoURL.lastPathComponent,
            kind: .compress,
            sourceDurationSeconds: sourceDurationSeconds
        )

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
            compressedSizeBytes = fileSize(at: outputURL)
            pendingOutputURL = outputURL
            pendingElapsedSeconds = Date().timeIntervalSince(startedAt)
            // Encoding is done, but nothing touches Photos until the user taps Save.
        } catch {
            errorMessage = error.localizedDescription
            try? FileManager.default.removeItem(at: outputURL)
            if let pendingHistoryID {
                historyStore.discardPending(id: pendingHistoryID)
                self.pendingHistoryID = nil
            }
        }
    }

    private func saveResult() async {
        guard let pendingOutputURL, let importedVideoURL else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let assetIdentifier = try await PhotoLibrarySaver.save(videoURL: pendingOutputURL)
            didSave = true
            if !subscriptionStore.isSubscribed { usageLimiter.recordUsage() }
            NotificationManager.notifyJobFinished(
                title: "Compress finished",
                body: "\(importedVideoURL.lastPathComponent) is ready in Photos."
            )
            if let originalSizeBytes, let compressedSizeBytes, let pendingHistoryID {
                let savings = ByteFormatting.savingsPercentage(originalBytes: originalSizeBytes, compressedBytes: compressedSizeBytes)
                historyStore.markCompleted(
                    id: pendingHistoryID,
                    resultTag: "-\(savings)%",
                    originalBytes: originalSizeBytes,
                    resultBytes: compressedSizeBytes,
                    processingSeconds: pendingElapsedSeconds,
                    resultAssetIdentifier: assetIdentifier
                )
                self.pendingHistoryID = nil
            }
            try? FileManager.default.removeItem(at: pendingOutputURL)
            self.pendingOutputURL = nil

            if deleteOriginalAfterSave, let importedAssetIdentifier {
                try? await PhotoLibrarySaver.deleteAsset(identifier: importedAssetIdentifier)
                didDeleteOriginal = true
            }
        } catch {
            errorMessage = error.localizedDescription
            if let pendingHistoryID {
                historyStore.discardPending(id: pendingHistoryID)
                self.pendingHistoryID = nil
            }
        }
    }

    private func resetState() {
        if let pendingOutputURL {
            try? FileManager.default.removeItem(at: pendingOutputURL)
        }
        if let pendingHistoryID {
            historyStore.discardPending(id: pendingHistoryID)
            self.pendingHistoryID = nil
        }
        importedVideoURL = nil
        importedAssetIdentifier = nil
        player = nil
        originalSizeBytes = nil
        sourceDurationSeconds = nil
        compressedSizeBytes = nil
        pendingOutputURL = nil
        pendingElapsedSeconds = nil
        didSave = false
        didDeleteOriginal = false
        deleteOriginalAfterSave = false
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
                        // Text(String) doesn't auto-localize the way Text(literal) does.
                        Text(LocalizedStringKey(step.title))
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
