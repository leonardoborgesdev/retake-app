import Foundation

enum EditingStage: Equatable {
    case idle
    case transcribingOriginal
    case detectingSilence
    case renderingCuts
    case extractingAudioForQA
    case transcribingEdited
    case reviewingRetakes
    case done
}

@MainActor
final class EditingPipeline: ObservableObject {
    @Published private(set) var stage: EditingStage = .idle
    @Published private(set) var retakeCandidates: [RetakeCandidate] = []
    @Published var errorMessage: String?

    private var sourceURL: URL?
    private var sourceDuration: Double = 0
    private var cuts: [CutRange] = []
    private var lastEditedURL: URL?
    private var client: AssemblyAIClient?

    func run(sourceURL: URL) async -> URL? {
        self.sourceURL = sourceURL
        do {
            guard let apiKey = APIKeyStore.load(), !apiKey.isEmpty else {
                throw AssemblyAIError.missingAPIKey
            }
            let client = AssemblyAIClient(apiKey: apiKey)
            self.client = client

            stage = .transcribingOriginal
            let originalAudioURL = try await AudioExtractor.extractAudio(from: sourceURL)
            let originalTranscript = try await client.transcribe(audioFileURL: originalAudioURL)
            try? FileManager.default.removeItem(at: originalAudioURL)
            sourceDuration = originalTranscript.duration

            stage = .detectingSilence
            let intervals = try await SilenceDetector.detectSilence(inputURL: sourceURL)
            cuts = SilenceCutPlanner.buildCuts(words: originalTranscript.words, duration: sourceDuration, intervals: intervals)

            return try await renderAndCheckForRetakes(client: client)
        } catch {
            errorMessage = error.localizedDescription
            stage = .idle
            return nil
        }
    }

    func resolveRetakes(keepingFirst keepFirstIDs: Set<Int>) async -> URL? {
        guard let sourceURL, let lastEditedURL, let client else { return nil }
        do {
            let keep = CutRenderer.buildKeepSegments(duration: sourceDuration, cuts: cuts, fps: nil)
            let mapping = CutMapper.buildMapping(keep: keep)

            var newOriginalCuts: [(start: Double, end: Double)] = []
            for candidate in retakeCandidates {
                let removedRange = keepFirstIDs.contains(candidate.id) ? candidate.secondRange : candidate.firstRange
                let originalStart = try CutMapper.editedToOriginal(mapping, time: removedRange.lowerBound)
                let originalEnd = try CutMapper.editedToOriginal(mapping, time: removedRange.upperBound)
                newOriginalCuts.append((start: originalStart, end: originalEnd))
            }

            cuts = CutMapper.mergeCuts(existing: cuts, newCuts: newOriginalCuts)
            try? FileManager.default.removeItem(at: lastEditedURL)
            retakeCandidates = []

            _ = sourceURL
            return try await renderAndCheckForRetakes(client: client)
        } catch {
            errorMessage = error.localizedDescription
            stage = .idle
            return nil
        }
    }

    private func renderAndCheckForRetakes(client: AssemblyAIClient) async throws -> URL? {
        guard let sourceURL else { return nil }

        stage = .renderingCuts
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("edited-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        try await CutRenderExecutor.render(sourceURL: sourceURL, duration: sourceDuration, cuts: cuts, outputURL: outputURL)
        lastEditedURL = outputURL

        stage = .extractingAudioForQA
        let editedAudioURL = try await AudioExtractor.extractAudio(from: outputURL)

        stage = .transcribingEdited
        let editedTranscript = try await client.transcribe(audioFileURL: editedAudioURL)
        try? FileManager.default.removeItem(at: editedAudioURL)

        let candidates = RetakeCandidateFinder.find(words: editedTranscript.words)
        if candidates.isEmpty {
            stage = .done
            return outputURL
        }

        retakeCandidates = candidates
        stage = .reviewingRetakes
        return nil
    }
}
