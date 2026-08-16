import SwiftUI
import AVKit
import ffmpegkit

enum StorySplitError: LocalizedError {
    case ffmpegFailed(String)

    var errorDescription: String? {
        switch self {
        case .ffmpegFailed(let message):
            return "Failed to split the video: \(message)"
        }
    }
}

/// Splits one long recording into sequential fixed-length clips, in order - the shape
/// a Stories/Reels posting queue wants. No AI, no scene detection: a straight ffmpeg
/// segment cut. Pairs naturally with Compress (compress first, then split the result,
/// or split first then compress each piece from History).
struct StorySplitView: View {
    var initialURL: URL? = nil

    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @State private var showPaywall = false
    @State private var pendingHistoryID: UUID?

    @State private var showPicker = false
    @State private var isImporting = false
    @State private var importedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var sourceDurationSeconds: Double?
    @State private var segmentDuration: StorySegmentDuration = .thirty
    @State private var isSplitting = false
    @State private var splitProgress: Double = 0
    @State private var resultURLs: [URL] = []
    @State private var savedCount = 0
    @State private var didFinish = false
    @State private var errorMessage: String?
    // Splitting itself is free for everyone - it's local and fast. Only saving the
    // result to Photos is gated, so a free user gets to see real clips (count, names)
    // before deciding whether to subscribe, instead of hitting a paywall on a button
    // they haven't gotten any value from yet.
    @State private var pendingClipURLs: [URL] = []
    @State private var pendingOutputDir: URL?
    @State private var isSavingClips = false
    @State private var savedToPhotos = false

    var body: some View {
        VStack(spacing: 20) {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

                if isSplitting {
                    splittingView
                } else if didFinish {
                    finishedView
                } else {
                    segmentPicker
                    Button {
                        Task { await split() }
                    } label: {
                        // A ternary here would make the whole expression a plain String,
                        // which Text() does not auto-localize the way a literal does -
                        // branch instead so each side stays a real literal/concatenation.
                        Group {
                            if sourceDurationSeconds == nil {
                                Text("Reading video…")
                            } else {
                                Text("Split into ") + Text("\(expectedCount) ") + Text("clips")
                            }
                        }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.board)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                    }
                    .disabled(sourceDurationSeconds == nil)
                }
            } else if isImporting {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("Preparing video…")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.top, 60)
                Spacer()
            } else {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        Image(systemName: "square.split.2x1")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.inkSoft)
                        Text("No video selected")
                            .font(.headline)
                        Text("Import a long recording to slice it into ordered Stories-length clips.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    FeatureInfoCard(rows: [
                        .init(icon: "scissors", label: "What it does", value: "Cuts into fixed-length pieces, in order"),
                        .init(icon: "clock", label: "Takes about", value: "A few seconds, no re-encode"),
                        .init(icon: "checkmark.seal", label: "Benefit", value: "Ready-made Stories/Reels queue"),
                        .init(icon: "infinity", label: "Size limit", value: "None"),
                    ])
                }
                .padding(.top, 32)
                Spacer()
            }

            if player == nil && !isImporting {
                Button {
                    showPicker = true
                } label: {
                    Label("Import video", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.line))
                }
            }
        }
        .padding()
        .background(Theme.paper)
        .navigationTitle("Split for Stories")
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
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: "Split for Stories is part of retake. Unlimited.")
        }
        .onAppear {
            guard player == nil, let initialURL else { return }
            load(url: initialURL)
#if DEBUG
            if UserDefaults.standard.bool(forKey: "debugAutoRun") {
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await split()
                }
            }
#endif
        }
    }

    private var expectedCount: Int {
        guard let sourceDurationSeconds else { return 1 }
        return FFmpegCommandBuilder.expectedSegmentCount(durationSeconds: sourceDurationSeconds, segmentSeconds: segmentDuration.rawValue)
    }

    private var segmentPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clip length").font(.caption).foregroundStyle(Theme.inkSoft)
            Picker("Clip length", selection: $segmentDuration) {
                ForEach(StorySegmentDuration.allCases) { duration in
                    Text(duration.label).tag(duration)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up").font(.caption2).foregroundStyle(Theme.inkSoft)
                (Text("Will produce ") + Text("\(expectedCount) ") + Text("clips, in order"))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var splittingView: some View {
        VStack(spacing: 10) {
            Text("Splitting…").font(.subheadline).foregroundStyle(Theme.inkSoft)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface2)
                    Capsule().fill(Theme.accent).frame(width: geo.size.width * splitProgress)
                }
            }
            .frame(height: 6)
        }
    }

    private var finishedView: some View {
        VStack(spacing: 14) {
            if savedToPhotos {
                Label {
                    Text("\(resultURLs.count) ") + Text("clips saved to Photos")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                    .foregroundStyle(Theme.accent)
                    .font(.subheadline.weight(.semibold))
            } else {
                Label {
                    Text("\(pendingClipURLs.count) ") + Text("clips ready")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                    .foregroundStyle(Theme.accent)
                    .font(.subheadline.weight(.semibold))
            }

            VStack(spacing: 0) {
                let clips = savedToPhotos ? resultURLs : pendingClipURLs
                ForEach(Array(clips.enumerated()), id: \.offset) { index, url in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 20)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    if index < clips.count - 1 {
                        Divider().overlay(Theme.line)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

            if !savedToPhotos {
                Button {
                    Task { await saveClipsToPhotos() }
                } label: {
                    if isSavingClips {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.board)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                    } else {
                        HStack(spacing: 6) {
                            if !subscriptionStore.isSubscribed {
                                Image(systemName: "lock.fill")
                            }
                            Text("Save to Photos")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.board)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                    }
                }
                .disabled(isSavingClips)
            }

            Button {
                resetState()
            } label: {
                Text("Split another video")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.line))
            }
        }
    }

    private func handlePicked(_ result: Result<PickedVideo, Error>) {
        resetState()
        isImporting = false
        switch result {
        case .success(let picked):
            load(url: picked.url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func load(url: URL) {
        importedVideoURL = url
        player = AVPlayer(url: url)
        Task {
            let asset = AVURLAsset(url: url)
            sourceDurationSeconds = try? CMTimeGetSeconds(await asset.load(.duration))
        }
    }

    private func split() async {
        guard let importedVideoURL, let sourceDurationSeconds else { return }
        isSplitting = true
        splitProgress = 0
        defer { isSplitting = false }

        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("split-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let outputPattern = outputDir.appendingPathComponent("clip-%03d.mp4").path

        let command = FFmpegCommandBuilder.segmentArguments(
            inputPath: importedVideoURL.path,
            outputPattern: outputPattern,
            segmentSeconds: segmentDuration.rawValue
        )

        do {
            try await runFFmpeg(command: command, totalDuration: sourceDurationSeconds)

            let files = (try? FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)) ?? []
            let clips = files.filter { $0.pathExtension == "mp4" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard !clips.isEmpty else {
                throw StorySplitError.ffmpegFailed("no clips were produced")
            }

            // Splitting itself is free and done at this point - nothing is saved to
            // Photos yet, so the result is just a local preview until saveClipsToPhotos.
            pendingClipURLs = clips
            pendingOutputDir = outputDir
            didFinish = true
        } catch {
            errorMessage = error.localizedDescription
            try? FileManager.default.removeItem(at: outputDir)
        }
    }

    private func saveClipsToPhotos() async {
        guard !pendingClipURLs.isEmpty else { return }
        guard subscriptionStore.isSubscribed else {
            showPaywall = true
            return
        }
        isSavingClips = true
        defer { isSavingClips = false }
        NotificationManager.requestAuthorizationIfNeeded()

        let pendingHistoryID = historyStore.recordPending(
            filename: importedVideoURL?.lastPathComponent ?? "video.mov",
            kind: .split,
            sourceDurationSeconds: sourceDurationSeconds
        )
        self.pendingHistoryID = pendingHistoryID

        let startedAt = Date()
        do {
            var firstAssetIdentifier: String?
            for clip in pendingClipURLs {
                let identifier = try await PhotoLibrarySaver.save(videoURL: clip)
                if firstAssetIdentifier == nil { firstAssetIdentifier = identifier }
                savedCount += 1
            }
            resultURLs = pendingClipURLs
            savedToPhotos = true
            NotificationManager.notifyJobFinished(
                title: "Split for Stories finished",
                body: "\(pendingClipURLs.count) clip\(pendingClipURLs.count == 1 ? "" : "s") ready in Photos."
            )

            let elapsed = Date().timeIntervalSince(startedAt)
            historyStore.markCompleted(
                id: pendingHistoryID,
                resultTag: "\(resultURLs.count) clip\(resultURLs.count == 1 ? "" : "s")",
                processingSeconds: elapsed,
                resultAssetIdentifier: firstAssetIdentifier
            )
            self.pendingHistoryID = nil
        } catch {
            errorMessage = error.localizedDescription
            historyStore.discardPending(id: pendingHistoryID)
            self.pendingHistoryID = nil
        }
        if let pendingOutputDir {
            try? FileManager.default.removeItem(at: pendingOutputDir)
        }
        pendingOutputDir = nil
    }

    private func runFFmpeg(command: String, totalDuration: Double) async throws {
        let buffer = FFmpegLogBuffer()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            FFmpegKit.executeAsync(command, withCompleteCallback: { session in
                Task { @MainActor in
                    guard let session else {
                        continuation.resume(throwing: StorySplitError.ffmpegFailed("invalid session"))
                        return
                    }
                    let returnCode = session.getReturnCode()
                    if ReturnCode.isSuccess(returnCode) {
                        continuation.resume()
                    } else {
                        let trace = session.getFailStackTrace() ?? buffer.lastLines(5) ?? "unknown error"
                        continuation.resume(throwing: StorySplitError.ffmpegFailed(trace))
                    }
                }
            }, withLogCallback: { log in
                if let message = log?.getMessage() {
                    buffer.append(message)
                }
            }, withStatisticsCallback: { statistics in
                guard let statistics, totalDuration > 0 else { return }
                let processedSeconds = Double(statistics.getTime()) / 1000.0
                let fraction = min(max(processedSeconds / totalDuration, 0), 1)
                Task { @MainActor in
                    splitProgress = fraction
                }
            })
        }
    }

    private func resetState() {
        if let pendingHistoryID {
            historyStore.discardPending(id: pendingHistoryID)
            self.pendingHistoryID = nil
        }
        if let pendingOutputDir {
            try? FileManager.default.removeItem(at: pendingOutputDir)
            self.pendingOutputDir = nil
        }
        importedVideoURL = nil
        player = nil
        sourceDurationSeconds = nil
        resultURLs = []
        pendingClipURLs = []
        savedToPhotos = false
        savedCount = 0
        didFinish = false
        errorMessage = nil
    }
}

#Preview {
    NavigationStack { StorySplitView() }.environmentObject(HistoryStore.shared)
}
