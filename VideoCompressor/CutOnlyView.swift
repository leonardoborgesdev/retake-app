import SwiftUI
import PhotosUI
import AVKit

struct CutOnlyView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var importedMovie: Movie?
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

            PhotosPicker(selection: $selectedItem, matching: .videos) {
                Label("Importar vídeo", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Cortar silêncios e retakes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { editingPipeline.stage == .reviewingRetakes },
            set: { _ in }
        )) {
            if let importedMovie {
                RetakeReviewView(
                    editedVideoURL: importedMovie.url,
                    candidates: editingPipeline.retakeCandidates
                ) { keepFirstIDs in
                    Task { await resolveRetakes(keepFirstIDs: keepFirstIDs) }
                }
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task { await loadVideo(from: newItem) }
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

    private func loadVideo(from item: PhotosPickerItem?) async {
        guard let item else { return }
        resetState()
        do {
            guard let movie = try await item.loadTransferable(type: Movie.self) else {
                errorMessage = "Não foi possível carregar o vídeo selecionado."
                return
            }
            importedMovie = movie
            player = AVPlayer(url: movie.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runEditingPipeline() async {
        guard let importedMovie else { return }
        if let result = await editingPipeline.run(sourceURL: importedMovie.url) {
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
        importedMovie = nil
        player = nil
        didSave = false
        errorMessage = nil
    }
}

#Preview {
    NavigationStack { CutOnlyView() }
}
