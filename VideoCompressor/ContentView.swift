import SwiftUI
import PhotosUI
import AVKit

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var importedMovie: Movie?
    @State private var player: AVPlayer?
    @State private var originalSizeBytes: Int64?
    @State private var compressedSizeBytes: Int64?
    @State private var isCompressing = false
    @State private var didSave = false
    @State private var errorMessage: String?
    @State private var showSettings = false

    /// URL to compress: the silence/retake-edited video if the cut step ran, otherwise the
    /// original import.
    @State private var editedURL: URL?

    @StateObject private var compressionService = VideoCompressionService()
    @StateObject private var editingPipeline = EditingPipeline()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let player {
                    VideoPlayer(player: player)
                        .frame(height: 220)

                    if let originalSizeBytes {
                        Text("Original: \(ByteFormatting.humanReadableSize(originalSizeBytes))")
                            .font(.subheadline)
                    }

                    if isCompressing {
                        ProgressView(value: compressionService.progress)
                            .padding(.horizontal)
                        Button("Cancelar", role: .destructive) {
                            compressionService.cancel()
                        }
                    } else if editingPipeline.stage != .idle && editingPipeline.stage != .done {
                        editingProgressView
                    } else if didSave, let compressedSizeBytes, let originalSizeBytes {
                        VStack(spacing: 8) {
                            Label("Salvo na galeria", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Novo tamanho: \(ByteFormatting.humanReadableSize(compressedSizeBytes))")
                            Text("Economia: \(ByteFormatting.savingsPercentage(originalBytes: originalSizeBytes, compressedBytes: compressedSizeBytes))%")
                                .font(.headline)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Button("1. Cortar silêncios e retakes") {
                                Task { await runEditingPipeline() }
                            }
                            .buttonStyle(.bordered)
                            .disabled(editedURL != nil)

                            Button("2. Comprimir") {
                                Task { await compress() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Nenhum vídeo selecionado")
                            .font(.headline)
                        Text("Importe um vídeo da galeria para comprimir.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                PhotosPicker(selection: $selectedItem, matching: .videos) {
                    Label("Importar vídeo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("VideoCompressor")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: Binding(
                get: { editingPipeline.stage == .reviewingRetakes },
                set: { _ in }
            )) {
                if let currentEditedURL = editedURL {
                    RetakeReviewView(
                        editedVideoURL: currentEditedURL,
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
            originalSizeBytes = fileSize(at: movie.url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runEditingPipeline() async {
        guard let importedMovie else { return }
        if let result = await editingPipeline.run(sourceURL: importedMovie.url) {
            applyEditedResult(result)
        } else if let message = editingPipeline.errorMessage {
            errorMessage = message
        }
    }

    private func resolveRetakes(keepFirstIDs: Set<Int>) async {
        if let result = await editingPipeline.resolveRetakes(keepingFirst: keepFirstIDs) {
            applyEditedResult(result)
        } else if let message = editingPipeline.errorMessage {
            errorMessage = message
        }
    }

    private func applyEditedResult(_ url: URL) {
        editedURL = url
        player = AVPlayer(url: url)
    }

    private func compress() async {
        guard let importedMovie else { return }
        let inputURL = editedURL ?? importedMovie.url
        isCompressing = true
        defer { isCompressing = false }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("compressed-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        do {
            try await compressionService.compress(inputURL: inputURL, outputURL: outputURL)
            compressedSizeBytes = fileSize(at: outputURL)
            try await PhotoLibrarySaver.save(videoURL: outputURL)
            didSave = true
            try? FileManager.default.removeItem(at: outputURL)
            if let editedURL {
                try? FileManager.default.removeItem(at: editedURL)
            }
        } catch {
            errorMessage = error.localizedDescription
            try? FileManager.default.removeItem(at: outputURL)
        }
    }

    private func resetState() {
        importedMovie = nil
        player = nil
        originalSizeBytes = nil
        compressedSizeBytes = nil
        didSave = false
        errorMessage = nil
        editedURL = nil
    }

    private func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
}

#Preview {
    ContentView()
}
