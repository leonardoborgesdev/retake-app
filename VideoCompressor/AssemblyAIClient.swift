import Foundation

struct AssemblyAITranscript {
    let words: [TranscriptWord]
    let duration: Double
}

enum AssemblyAIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Set your AssemblyAI API key in Settings before continuing."
        case .invalidResponse:
            return "Invalid response from AssemblyAI."
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}

final class AssemblyAIClient {
    private let apiKey: String
    private let session: URLSession
    private let pollIntervalNanoseconds: UInt64

    init(apiKey: String, session: URLSession = .shared, pollIntervalNanoseconds: UInt64 = 3_000_000_000) {
        self.apiKey = apiKey
        self.session = session
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
    }

    func transcribe(audioFileURL: URL) async throws -> AssemblyAITranscript {
        let uploadURL = try await upload(fileURL: audioFileURL)
        let transcriptID = try await requestTranscript(audioURL: uploadURL)
        return try await pollTranscript(id: transcriptID)
    }

    private func upload(fileURL: URL) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/upload")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        let audioData = try Data(contentsOf: fileURL)
        let (data, response) = try await session.upload(for: request, from: audioData)
        try Self.validate(response)
        return try JSONDecoder().decode(UploadResponse.self, from: data).uploadURL
    }

    private func requestTranscript(audioURL: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/transcript")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(TranscriptRequest(audioURL: audioURL))
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        return try JSONDecoder().decode(TranscriptCreateResponse.self, from: data).id
    }

    private func pollTranscript(id: String) async throws -> AssemblyAITranscript {
        let url = URL(string: "https://api.assemblyai.com/v2/transcript/\(id)")!
        while true {
            var request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            let (data, response) = try await session.data(for: request)
            try Self.validate(response)
            let decoded = try JSONDecoder().decode(TranscriptPollResponse.self, from: data)

            switch decoded.status {
            case "completed":
                guard let words = decoded.words, let durationSeconds = decoded.audioDuration else {
                    throw AssemblyAIError.invalidResponse
                }
                let mapped = words.map {
                    TranscriptWord(text: $0.text, start: Double($0.start) / 1000, end: Double($0.end) / 1000)
                }
                return AssemblyAITranscript(words: mapped, duration: Double(durationSeconds))
            case "error":
                throw AssemblyAIError.transcriptionFailed(decoded.error ?? "erro desconhecido")
            default:
                try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            }
        }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw AssemblyAIError.invalidResponse
        }
    }

    private struct UploadResponse: Decodable {
        let uploadURL: String
        enum CodingKeys: String, CodingKey { case uploadURL = "upload_url" }
    }

    private struct TranscriptRequest: Encodable {
        let audioURL: String
        /// Fixed to Portuguese instead of relying on automatic language detection: AssemblyAI
        /// can't run detection on clips shorter than ~50 seconds, which fails short test videos.
        let languageCode = "pt"
        enum CodingKeys: String, CodingKey {
            case audioURL = "audio_url"
            case languageCode = "language_code"
        }
    }

    private struct TranscriptCreateResponse: Decodable {
        let id: String
    }

    private struct TranscriptPollResponse: Decodable {
        let status: String
        let words: [WordDTO]?
        let audioDuration: Int?
        let error: String?
        enum CodingKeys: String, CodingKey {
            case status, words, error
            case audioDuration = "audio_duration"
        }
    }

    private struct WordDTO: Decodable {
        let text: String
        let start: Int
        let end: Int
    }
}
