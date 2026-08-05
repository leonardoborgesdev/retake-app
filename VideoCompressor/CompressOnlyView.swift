import SwiftUI
import AVKit

struct CompressOnlyView: View {
    var initialURL: URL? = nil

    @EnvironmentObject private var historyStore: HistoryStore

    @State private var showPicker = false
    @State private var importedVideoURL: URL?
    @State private var importedAssetIdentifier: String?
    @State private var player: AVPlayer?
    @State private var originalSizeBytes: Int64?
    @State private var compressedSizeBytes: Int64?
    @State private var isCompressing = false
    @State private var didSave = false
    @State private var didDeleteOriginal = false
    @State private var isDeletingOriginal = false
    @State private var errorMessage: String?
    @AppStorage("enhanceQuality") private var enhanceQuality = true

    @StateObject private var compressionService = VideoCompressionService()

    var body: some View {
        VStack(spacing: 20) {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

                if isCompressing {
                    VStack(spacing: 10) {
                        ProgressView(value: compressionService.progress)
                            .tint(Theme.accent)
                        Button("Cancel", role: .destructive) {
                            compressionService.cancel()
                        }
                        .font(.subheadline)
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

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enhance quality").font(.subheadline.weight(.semibold))
                            Text("Higher-bitrate encode").font(.caption2).foregroundStyle(Theme.inkSoft)
                        }
                        Spacer()
                        Toggle("", isOn: $enhanceQuality).labelsHidden().tint(Theme.accent)
                    }
                    .padding(12)
                    .background(Theme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

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
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.inkSoft)
                    Text("No video selected")
                        .font(.headline)
                    Text("Import a video from your library to compress it.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 48)
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
            VideoPicker { result in
                handlePicked(result)
            }
            .ignoresSafeArea()
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
            originalSizeBytes = fileSize(at: initialURL)
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
        switch result {
        case .success(let picked):
            importedVideoURL = picked.url
            importedAssetIdentifier = picked.assetIdentifier
            player = AVPlayer(url: picked.url)
            originalSizeBytes = fileSize(at: picked.url)
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
            try await compressionService.compress(inputURL: importedVideoURL, outputURL: outputURL, enhanceQuality: enhanceQuality)
            let resultBytes = fileSize(at: outputURL)
            compressedSizeBytes = resultBytes
            try await PhotoLibrarySaver.save(videoURL: outputURL)
            didSave = true
            if let originalSizeBytes, let resultBytes {
                let savings = ByteFormatting.savingsPercentage(originalBytes: originalSizeBytes, compressedBytes: resultBytes)
                historyStore.record(HistoryEntry(
                    filename: importedVideoURL.lastPathComponent,
                    kind: .compress,
                    resultTag: "-\(savings)%",
                    originalBytes: originalSizeBytes,
                    resultBytes: resultBytes
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

#Preview {
    NavigationStack { CompressOnlyView() }.environmentObject(HistoryStore.shared)
}
