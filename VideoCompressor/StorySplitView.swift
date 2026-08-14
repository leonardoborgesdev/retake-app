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

    @State private var showPicker = false
    @State private var isImporting = false
    @State private var importedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var sourceDurationSeconds: Double?
    @State private var segmentDuration: StorySegmentDuration = .sixty
    @State private var isSplitting = false
    @State private var splitProgress: Double = 0
    @State private var resultURLs: [URL] = []
    @State private var savedCount = 0
    @State private var didFinish = false
    @State private var errorMessage: String?

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
                        Text("Split into \(expectedCount) clips")
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
        .onAppear {
            guard player == nil, let initialURL else { return }
            load(url: initialURL)
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
                Text("Will produce \(expectedCount) clip\(expectedCount == 1 ? "" : "s"), in order")
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
            Label("\(resultURLs.count) clips saved to Photos", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent)
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 0) {
                ForEach(Array(resultURLs.enumerated()), id: \.offset) { index, url in
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
                    if index < resultURLs.count - 1 {
                        Divider().overlay(Theme.line)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

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

        let startedAt = Date()
        do {
            try await runFFmpeg(command: command, totalDuration: sourceDurationSeconds)

            let files = (try? FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil)) ?? []
            let clips = files.filter { $0.pathExtension == "mp4" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard !clips.isEmpty else {
                throw StorySplitError.ffmpegFailed("no clips were produced")
            }

            for clip in clips {
                try await PhotoLibrarySaver.save(videoURL: clip)
                savedCount += 1
            }
            resultURLs = clips
            didFinish = true

            let elapsed = Date().timeIntervalSince(startedAt)
            historyStore.record(HistoryEntry(
                filename: importedVideoURL.lastPathComponent,
                kind: .split,
                resultTag: "\(clips.count) clip\(clips.count == 1 ? "" : "s")",
                sourceDurationSeconds: sourceDurationSeconds,
                processingSeconds: elapsed
            ))
        } catch {
            errorMessage = error.localizedDescription
        }
        try? FileManager.default.removeItem(at: outputDir)
    }

    private func runFFmpeg(command: String, totalDuration: Double) async throws {
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
                        let trace = session.getFailStackTrace() ?? "unknown error"
                        continuation.resume(throwing: StorySplitError.ffmpegFailed(trace))
                    }
                }
            }, withLogCallback: nil, withStatisticsCallback: { statistics in
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
        importedVideoURL = nil
        player = nil
        sourceDurationSeconds = nil
        resultURLs = []
        savedCount = 0
        didFinish = false
        errorMessage = nil
    }
}

#Preview {
    NavigationStack { StorySplitView() }.environmentObject(HistoryStore.shared)
}
