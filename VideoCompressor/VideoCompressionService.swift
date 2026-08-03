import Foundation
import AVFoundation
import ffmpegkit

enum VideoCompressionError: LocalizedError {
    case ffmpegFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .ffmpegFailed(let message):
            return "Falha ao comprimir o vídeo: \(message)"
        case .cancelled:
            return "Compressão cancelada."
        }
    }
}

@MainActor
final class VideoCompressionService: ObservableObject {
    @Published private(set) var progress: Double = 0

    private var currentSession: FFmpegSession?

    func compress(inputURL: URL, outputURL: URL) async throws {
        progress = 0
        let durationSeconds = try await videoDurationSeconds(url: inputURL)
        let command = FFmpegCommandBuilder.compressionArguments(
            inputPath: inputURL.path,
            outputPath: outputURL.path
        )

        let buffer = FFmpegLogBuffer()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = FFmpegKit.executeAsync(command, withCompleteCallback: { [weak self] session in
                Task { @MainActor in
                    self?.currentSession = nil
                    guard let session else {
                        continuation.resume(throwing: VideoCompressionError.ffmpegFailed("sessão inválida"))
                        return
                    }
                    let returnCode = session.getReturnCode()
                    if ReturnCode.isSuccess(returnCode) {
                        continuation.resume()
                    } else if ReturnCode.isCancel(returnCode) {
                        continuation.resume(throwing: VideoCompressionError.cancelled)
                    } else {
                        let trace = session.getFailStackTrace() ?? buffer.lastLines(5) ?? "erro desconhecido"
                        continuation.resume(throwing: VideoCompressionError.ffmpegFailed(trace))
                    }
                }
            }, withLogCallback: { log in
                if let message = log?.getMessage() {
                    buffer.append(message)
                }
            }, withStatisticsCallback: { [weak self] statistics in
                guard let statistics, durationSeconds > 0 else { return }
                let processedSeconds = Double(statistics.getTime()) / 1000.0
                let fraction = min(max(processedSeconds / durationSeconds, 0), 1)
                Task { @MainActor in
                    self?.progress = fraction
                }
            })
            currentSession = session
        }
    }

    func cancel() {
        currentSession?.cancel()
    }

    private func videoDurationSeconds(url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
}
