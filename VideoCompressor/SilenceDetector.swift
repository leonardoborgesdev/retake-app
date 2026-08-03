import Foundation
import ffmpegkit

enum SilenceDetectionError: LocalizedError {
    case ffmpegFailed(String)

    var errorDescription: String? {
        switch self {
        case .ffmpegFailed(let message):
            return "Falha ao detectar silêncio: \(message)"
        }
    }
}

/// Thread-safe accumulator for ffmpeg log lines. FFmpegKit's log callback can be invoked
/// from a background queue for every log line while the complete callback fires once at
/// the end; both must be able to touch this buffer safely.
private final class LogBuffer: @unchecked Sendable {
    private var lines: [String] = []
    private let lock = NSLock()

    func append(_ line: String) {
        lock.lock()
        lines.append(line)
        lock.unlock()
    }

    func joinedText() -> String {
        lock.lock()
        defer { lock.unlock() }
        return lines.joined(separator: "\n")
    }
}

enum SilenceDetector {
    static func parseLog(_ log: String) -> [SilenceInterval] {
        let starts = matches(in: log, pattern: #"silence_start:\s*([\d.]+)"#)
        let ends = matches(in: log, pattern: #"silence_end:\s*([\d.]+)"#)
        return zip(starts, ends).map { SilenceInterval(start: $0, end: $1) }
    }

    static func detectSilence(inputURL: URL, noiseDB: Int = -30, minDuration: Double = 0.15) async throws -> [SilenceInterval] {
        let command = "-i \"\(inputURL.path)\" -af silencedetect=noise=\(noiseDB)dB:d=\(minDuration) -f null -"
        let buffer = LogBuffer()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[SilenceInterval], Error>) in
            FFmpegKit.executeAsync(command, withCompleteCallback: { session in
                guard let session else {
                    continuation.resume(throwing: SilenceDetectionError.ffmpegFailed("sessão inválida"))
                    return
                }
                if ReturnCode.isSuccess(session.getReturnCode()) {
                    continuation.resume(returning: parseLog(buffer.joinedText()))
                } else {
                    let trace = session.getFailStackTrace() ?? "erro desconhecido"
                    continuation.resume(throwing: SilenceDetectionError.ffmpegFailed(trace))
                }
            }, withLogCallback: { log in
                if let message = log?.getMessage() {
                    buffer.append(message)
                }
            }, withStatisticsCallback: nil)
        }
    }

    private static func matches(in text: String, pattern: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match -> Double? in
            guard let matchRange = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[matchRange])
        }
    }
}
