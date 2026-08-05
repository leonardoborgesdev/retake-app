import SwiftUI
import AVKit

struct CutOnlyView: View {
    var initialURL: URL? = nil

    @EnvironmentObject private var historyStore: HistoryStore

    @State private var showPicker = false
    @State private var importedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var didSave = false
    @State private var isSaving = false
    @State private var errorMessage: String?

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
                }
            } else {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        Image(systemName: "scissors")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.inkSoft)
                        Text("No video selected")
                            .font(.headline)
                        Text("Import a video to cut silence and repeated lines.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    FeatureInfoCard(rows: [
                        .init(icon: "waveform.badge.magnifyingglass", label: "What it does", value: "Transcribes, finds gaps & retakes"),
                        .init(icon: "clock", label: "Takes about", value: "~1 min per minute of video"),
                        .init(icon: "checkmark.seal", label: "Benefit", value: "No desktop edit, you pick the take"),
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
            VideoPicker { result in
                handlePicked(result)
            }
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
        .onAppear {
            guard player == nil, let initialURL else { return }
            importedVideoURL = initialURL
            player = AVPlayer(url: initialURL)
        }
    }

    private func handlePicked(_ result: Result<PickedVideo, Error>) {
        resetState()
        switch result {
        case .success(let picked):
            importedVideoURL = picked.url
            player = AVPlayer(url: picked.url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func runEditingPipeline() async {
        guard let importedVideoURL else { return }
        if let result = await editingPipeline.run(sourceURL: importedVideoURL) {
            await save(url: result, sourceName: importedVideoURL.lastPathComponent)
        } else if let message = editingPipeline.errorMessage {
            errorMessage = message
        }
    }

    private func resolveRetakes(keepFirstIDs: Set<Int>) async {
        let sourceName = importedVideoURL?.lastPathComponent ?? "video.mov"
        if let result = await editingPipeline.resolveRetakes(keepingFirst: keepFirstIDs) {
            await save(url: result, sourceName: sourceName)
        } else if let message = editingPipeline.errorMessage {
            errorMessage = message
        }
    }

    private func save(url: URL, sourceName: String) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await PhotoLibrarySaver.save(videoURL: url)
            didSave = true
            let cutCount = editingPipeline.cutCount
            historyStore.record(HistoryEntry(
                filename: sourceName,
                kind: .cut,
                resultTag: "\(cutCount) cut\(cutCount == 1 ? "" : "s")"
            ))
            try? FileManager.default.removeItem(at: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetState() {
        importedVideoURL = nil
        player = nil
        didSave = false
        errorMessage = nil
    }
}

#Preview {
    NavigationStack { CutOnlyView() }.environmentObject(HistoryStore.shared)
}
