import SwiftUI
import AVKit

struct CutOnlyView: View {
    @State private var showPicker = false
    @State private var importedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var didSave = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    @StateObject private var editingPipeline = EditingPipeline()

    var body: some View {
        VStack(spacing: 24) {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 220)

                if editingPipeline.stage != .idle && editingPipeline.stage != .done {
                    editingProgressView
                } else if isSaving {
                    ProgressView()
                    Text("Salvando na galeria…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if didSave {
                    Label("Salvo na galeria", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)
                } else {
                    Button("Cortar silêncios e retakes") {
                        Task { await runEditingPipeline() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "scissors")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Nenhum vídeo selecionado")
                        .font(.headline)
                    Text("Importe um vídeo pra cortar silêncios e repetições de fala.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }

            Button {
                showPicker = true
            } label: {
                Label("Importar vídeo", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Cortar silêncios e retakes")
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
        .alert("Erro", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private var editingProgressView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text(stageDescription(editingPipeline.stage))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func stageDescription(_ stage: EditingStage) -> String {
        switch stage {
        case .idle, .done: return ""
        case .transcribingOriginal: return "Transcrevendo áudio original…"
        case .detectingSilence: return "Detectando silêncios…"
        case .renderingCuts: return "Cortando vídeo…"
        case .extractingAudioForQA: return "Extraindo áudio pra conferência…"
        case .transcribingEdited: return "Re-transcrevendo pra checar repetições…"
        case .reviewingRetakes: return "Aguardando sua revisão…"
        }
    }

    private func handlePicked(_ result: Result<URL, Error>) {
        resetState()
        switch result {
        case .success(let url):
            importedVideoURL = url
            player = AVPlayer(url: url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func runEditingPipeline() async {
        guard let importedVideoURL else { return }
        if let result = await editingPipeline.run(sourceURL: importedVideoURL) {
            await save(url: result)
        } else if let message = editingPipeline.errorMessage {
            errorMessage = message
        }
    }

    private func resolveRetakes(keepFirstIDs: Set<Int>) async {
        if let result = await editingPipeline.resolveRetakes(keepingFirst: keepFirstIDs) {
            await save(url: result)
        } else if let message = editingPipeline.errorMessage {
            errorMessage = message
        }
    }

    private func save(url: URL) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await PhotoLibrarySaver.save(videoURL: url)
            didSave = true
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
    NavigationStack { CutOnlyView() }
}
