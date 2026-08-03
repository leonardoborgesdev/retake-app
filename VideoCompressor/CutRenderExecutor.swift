import Foundation
import AVFoundation
import ffmpegkit

enum CutRenderError: LocalizedError {
    case ffmpegFailed(String)

    var errorDescription: String? {
        switch self {
        case .ffmpegFailed(let message):
            return "Falha ao renderizar cortes: \(message)"
        }
    }
}

enum CutRenderExecutor {
    /// Uses the iPhone's hardware HEVC encoder (VideoToolbox) instead of libx264: the
    /// ffmpeg-kit-spm build we ship is the GPL-free "min" variant, which does not include
    /// libx264/libx265.
    static func render(sourceURL: URL, duration: Double, cuts: [CutRange], outputURL: URL) async throws {
        let fps = try await frameRate(url: sourceURL)
        let keep = CutRenderer.buildKeepSegments(duration: duration, cuts: cuts, fps: fps)
        let filterGraph = CutRenderer.buildFilterGraph(keep: keep)

        let filterScriptURL = outputURL.deletingPathExtension().appendingPathExtension("filtergraph.txt")
        try filterGraph.write(to: filterScriptURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: filterScriptURL) }

        let command = "-y -i \"\(sourceURL.path)\" -filter_complex_script \"\(filterScriptURL.path)\" "
            + "-map \"[outv]\" -map \"[outa]\" -c:v hevc_videotoolbox -b:v 10000k -tag:v hvc1 -c:a aac -b:a 192k \"\(outputURL.path)\""

        let buffer = FFmpegLogBuffer()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            FFmpegKit.executeAsync(command, withCompleteCallback: { session in
                guard let session else {
                    continuation.resume(throwing: CutRenderError.ffmpegFailed("sessão inválida"))
                    return
                }
                if ReturnCode.isSuccess(session.getReturnCode()) {
                    continuation.resume()
                } else {
                    let trace = session.getFailStackTrace() ?? buffer.lastLines(5) ?? "erro desconhecido"
                    continuation.resume(throwing: CutRenderError.ffmpegFailed(trace))
                }
            }, withLogCallback: { log in
                if let message = log?.getMessage() {
                    buffer.append(message)
                }
            }, withStatisticsCallback: nil)
        }
    }

    private static func frameRate(url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            return 30
        }
        let fps = try await track.load(.nominalFrameRate)
        return fps > 0 ? Double(fps) : 30
    }
}
