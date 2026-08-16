import SwiftUI
import AVKit

struct CutOnlyView: View {
    var initialURL: URL? = nil

    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @EnvironmentObject private var usageLimiter: UsageLimiter
    @State private var showPaywall = false
    @State private var pendingHistoryID: UUID?

    @State private var showPicker = false
    @State private var isImporting = false
    @State private var importedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var didSave = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var sourceDurationSeconds: Double?
    @State private var pipelineStartedAt: Date?

    @StateObject private var editingPipeline = EditingPipeline()

    var body: some View {
        VStack(spacing: 20) {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

                if editingPipeline.stage != .idle && editingPipeline.stage != .done {
                    ProcessingView(stage: editingPipeline.stage)
                } else if isSaving {
                    ProgressView()
                    Text("Saving to Photos...")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                } else if didSave {
                    Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                        .font(.headline)
                } else {
                    Button {
                        Task { await runEditingPipeline() }
                    } label: {
                        Text("Cut silence & retakes")
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
                        Image(systemName: "scissors")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.inkSoft)
                        Text("No video selected")
                            .font(.headline)
                        Text("Import a video to cut silence and repeated lines. Any length, any file size.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    FeatureInfoCard(rows: [
                        .init(icon: "waveform.badge.magnifyingglass", label: "What it does", value: "Transcribes, finds gaps & retakes"),
                        .init(icon: "clock", label: "Takes about", value: "~1 min per minute of video"),
                        .init(icon: "checkmark.seal", label: "Benefit", value: "No desktop edit, you pick the take"),
                        .init(icon: "infinity", label: "Size limit", value: "None - long recordings are fine"),
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
        .navigationTitle("Cut silence & retakes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            VideoPicker(onPicked: { result in
                handlePicked(result)
            }, onImportStart: {
                isImporting = true
            })
            .ignoresSafeArea()
        }
        .sheet(isPresented: Binding(
            get: { editingPipeline.stage == .reviewingRetakes },
            set: { _ in }
        )) {
            if let importedVideoURL {
                RetakeReviewView(
                    editedVideoURL: importedVideoURL,
                    candidates: editingPipeline.retakeCandidates
                ) { keepFirstIDs in
                    Task { await resolveRetakes(keepFirstIDs: keepFirstIDs) }
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onAppear {
            guard player == nil, let initialURL else { return }
            importedVideoURL = initialURL
            player = AVPlayer(url: initialURL)
            loadDuration(url: initialURL)
#if DEBUG
            if UserDefaults.standard.bool(forKey: "debugAutoRun") {
                Task {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    await runEditingPipeline()
                }
            }
#endif
        }
    }

    private func handlePicked(_ result: Result<PickedVideo, Error>) {
        resetState()
        isImporting = false
        switch result {
        case .success(let picked):
            importedVideoURL = picked.url
            player = AVPlayer(url: picked.url)
            loadDuration(url: picked.url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func loadDuration(url: URL) {
        Task {
            let asset = AVURLAsset(url: url)
            sourceDurationSeconds = try? CMTimeGetSeconds(await asset.load(.duration))
        }
    }

    private func runEditingPipeline() async {
        guard let importedVideoURL else { return }
        guard subscriptionStore.isSubscribed || usageLimiter.canUse() else {
            showPaywall = true
            return
        }
        pipelineStartedAt = Date()
        pendingHistoryID = historyStore.recordPending(
            filename: importedVideoURL.lastPathComponent,
            kind: .cut,
            sourceDurationSeconds: sourceDurationSeconds
        )
        NotificationManager.requestAuthorizationIfNeeded()
        if let result = await editingPipeline.run(sourceURL: importedVideoURL) {
            await save(url: result, sourceName: importedVideoURL.lastPathComponent)
        } else if let message = editingPipeline.errorMessage {
            errorMessage = message
            if let pendingHistoryID {
                historyStore.discardPending(id: pendingHistoryID)
                self.pendingHistoryID = nil
            }
        }
    }

    private func resolveRetakes(keepFirstIDs: Set<Int>) async {
        let sourceName = importedVideoURL?.lastPathComponent ?? "video.mov"
        if let result = await editingPipeline.resolveRetakes(keepingFirst: keepFirstIDs) {
            await save(url: result, sourceName: sourceName)
        } else if let message = editingPipeline.errorMessage {
            errorMessage = message
            if let pendingHistoryID {
                historyStore.discardPending(id: pendingHistoryID)
                self.pendingHistoryID = nil
            }
        }
    }

    private func save(url: URL, sourceName: String) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let assetIdentifier = try await PhotoLibrarySaver.save(videoURL: url)
            didSave = true
            if !subscriptionStore.isSubscribed { usageLimiter.recordUsage() }
            NotificationManager.notifyJobFinished(
                title: "Cut silence & retakes finished",
                body: "\(sourceName) is ready in Photos."
            )
            let cutCount = editingPipeline.cutCount
            let elapsed = pipelineStartedAt.map { Date().timeIntervalSince($0) }
            if let pendingHistoryID {
                historyStore.markCompleted(
                    id: pendingHistoryID,
                    resultTag: "\(cutCount) cut\(cutCount == 1 ? "" : "s")",
                    processingSeconds: elapsed,
                    resultAssetIdentifier: assetIdentifier
                )
                self.pendingHistoryID = nil
            }
            try? FileManager.default.removeItem(at: url)
        } catch {
            errorMessage = error.localizedDescription
            if let pendingHistoryID {
                historyStore.discardPending(id: pendingHistoryID)
                self.pendingHistoryID = nil
            }
        }
    }

    private func resetState() {
        if let pendingHistoryID {
            historyStore.discardPending(id: pendingHistoryID)
            self.pendingHistoryID = nil
        }
        importedVideoURL = nil
        player = nil
        didSave = false
        errorMessage = nil
        sourceDurationSeconds = nil
        pipelineStartedAt = nil
    }
}

#Preview {
    NavigationStack { CutOnlyView() }.environmentObject(HistoryStore.shared)
}
