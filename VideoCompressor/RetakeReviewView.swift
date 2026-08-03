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
            VStack {
                VideoPlayer(player: player)
                    .frame(height: 200)

                List(candidates) { candidate in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\"\(candidate.phrase)\"")
                            .font(.headline)

                        HStack {
                            Button("Ouvir 1ª vez") { play(range: candidate.firstRange) }
                            Spacer()
                            Button("Ouvir 2ª vez") { play(range: candidate.secondRange) }
                        }
                        .buttonStyle(.bordered)

                        Picker("Manter", selection: Binding(
                            get: { selections[candidate.id] ?? true },
                            set: { selections[candidate.id] = $0 }
                        )) {
                            Text("Manter 1ª vez").tag(true)
                            Text("Manter 2ª vez").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Revisar repetições")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluir") {
                        player.pause()
                        let keepFirstIDs = Set(candidates.compactMap { selections[$0.id] ?? true ? $0.id : nil })
                        onResolve(keepFirstIDs)
                    }
                }
            }
        }
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
