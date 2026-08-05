import SwiftUI
import AVKit

struct RetakeReviewView: View {
    let editedVideoURL: URL
    let candidates: [RetakeCandidate]
    let onResolve: (Set<Int>) -> Void

    @State private var selections: [Int: Bool] = [:]
    @State private var player: AVPlayer

    init(editedVideoURL: URL, candidates: [RetakeCandidate], onResolve: @escaping (Set<Int>) -> Void) {
        self.editedVideoURL = editedVideoURL
        self.candidates = candidates
        self.onResolve = onResolve
        _player = State(initialValue: AVPlayer(url: editedVideoURL))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VideoPlayer(player: player)
                    .frame(height: 200)

                List(candidates) { candidate in
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\"\(candidate.phrase)\"")
                            .font(.subheadline.weight(.semibold))

                        let keepFirst = selections[candidate.id] ?? true

                        takeRow(label: "Take 1", isKept: keepFirst) { play(range: candidate.firstRange) }
                        takeRow(label: "Take 2", isKept: !keepFirst) { play(range: candidate.secondRange) }

                        Picker("Keep", selection: Binding(
                            get: { selections[candidate.id] ?? true },
                            set: { selections[candidate.id] = $0 }
                        )) {
                            Text("Keep take 1").tag(true)
                            Text("Keep take 2").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Theme.surface2)
                }
                .scrollContentBackground(.hidden)
                .background(Theme.paper)
            }
            .background(Theme.paper)
            .navigationTitle("Choose the take")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        player.pause()
                        let keepFirstIDs = Set(candidates.compactMap { selections[$0.id] ?? true ? $0.id : nil })
                        onResolve(keepFirstIDs)
                    }
                }
            }
        }
    }

    private func takeRow(label: String, isKept: Bool, onPlay: @escaping () -> Void) -> some View {
        HStack {
            Text(label).font(.caption.monospaced()).foregroundStyle(Theme.inkSoft)
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(isKept ? Theme.ink : Theme.inkSoft)
            }
            Spacer()
            if isKept {
                Text("keep")
                    .font(.caption2.monospaced().weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.accentSoft)
                    .foregroundStyle(Theme.accent)
                    .clipShape(Capsule())
            } else {
                Label("REMOVED", systemImage: "arrow.uturn.backward")
                    .font(.caption2.monospaced().weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.discard.opacity(0.15))
                    .foregroundStyle(Theme.discard)
                    .clipShape(Capsule())
            }
        }
        .padding(8)
        .background(isKept ? Color.clear : Theme.surface3.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(isKept ? 1 : 0.6)
    }

    private func play(range: ClosedRange<Double>) {
        player.seek(to: CMTime(seconds: range.lowerBound, preferredTimescale: 600))
        player.play()
        let clipDuration = range.upperBound - range.lowerBound
        DispatchQueue.main.asyncAfter(deadline: .now() + clipDuration) {
            player.pause()
        }
    }
}
