import SwiftUI
import AVKit

struct CompressOnlyView: View {
    @State private var showPicker = false
    @State private var importedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var originalSizeBytes: Int64?
    @State private var compressedSizeBytes: Int64?
    @State private var isCompressing = false
    @State private var didSave = false
    @State private var errorMessage: String?

    @StateObject private var compressionService = VideoCompressionService()

    var body: some View {
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
                } else if didSave, let compressedSizeBytes, let originalSizeBytes {
                    VStack(spacing: 8) {
                        Label("Salvo na galeria", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Novo tamanho: \(ByteFormatting.humanReadableSize(compressedSizeBytes))")
                        Text("Economia: \(ByteFormatting.savingsPercentage(originalBytes: originalSizeBytes, compressedBytes: compressedSizeBytes))%")
                            .font(.headline)
                    }
                } else {
                    Button("Comprimir") {
                        Task { await compress() }
                    }
                    .buttonStyle(.borderedProminent)
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

            Button {
                showPicker = true
            } label: {
                Label("Importar vídeo", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Comprimir vídeo")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            VideoPicker { result in
                handlePicked(result)
            }
            .ignoresSafeArea()
        }
        .alert("Erro", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private func handlePicked(_ result: Result<URL, Error>) {
        resetState()
        switch result {
        case .success(let url):
            importedVideoURL = url
            player = AVPlayer(url: url)
            originalSizeBytes = fileSize(at: url)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func compress() async {
        guard let importedVideoURL else { return }
        isCompressing = true
        defer { isCompressing = false }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("compressed-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        do {
            try await compressionService.compress(inputURL: importedVideoURL, outputURL: outputURL)
            compressedSizeBytes = fileSize(at: outputURL)
            try await PhotoLibrarySaver.save(videoURL: outputURL)
            didSave = true
            try? FileManager.default.removeItem(at: outputURL)
        } catch {
            errorMessage = error.localizedDescription
            try? FileManager.default.removeItem(at: outputURL)
        }
    }

    private func resetState() {
        importedVideoURL = nil
        player = nil
        originalSizeBytes = nil
        compressedSizeBytes = nil
        didSave = false
        errorMessage = nil
    }

    private func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
}

#Preview {
    NavigationStack { CompressOnlyView() }
}
