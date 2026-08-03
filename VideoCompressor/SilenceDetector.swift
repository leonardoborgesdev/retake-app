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

enum SilenceDetector {
    static func parseLog(_ log: String) -> [SilenceInterval] {
        let starts = matches(in: log, pattern: #"silence_start:\s*([\d.]+)"#)
        let ends = matches(in: log, pattern: #"silence_end:\s*([\d.]+)"#)
        return zip(starts, ends).map { SilenceInterval(start: $0, end: $1) }
    }

    static func detectSilence(inputURL: URL, noiseDB: Int = -30, minDuration: Double = 0.15) async throws -> [SilenceInterval] {
        let command = "-i \"\(inputURL.path)\" -af silencedetect=noise=\(noiseDB)dB:d=\(minDuration) -f null -"
        let buffer = FFmpegLogBuffer()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[SilenceInterval], Error>) in
            FFmpegKit.executeAsync(command, withCompleteCallback: { session in
                guard let session else {
                    continuation.resume(throwing: SilenceDetectionError.ffmpegFailed("sessão inválida"))
                    return
                }
                if ReturnCode.isSuccess(session.getReturnCode()) {
                    continuation.resume(returning: parseLog(buffer.joinedText()))
                } else {
                    let trace = session.getFailStackTrace() ?? buffer.lastLines(5) ?? "erro desconhecido"
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
