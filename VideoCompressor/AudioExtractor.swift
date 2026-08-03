import Foundation
import AVFoundation

enum AudioExtractionError: LocalizedError {
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .exportFailed(let message):
            return "Falha ao extrair áudio: \(message)"
        }
    }
}

enum AudioExtractor {
    static func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioExtractionError.exportFailed("não foi possível criar sessão de exportação")
        }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    let message = exportSession.error?.localizedDescription ?? "erro desconhecido"
                    continuation.resume(throwing: AudioExtractionError.exportFailed(message))
                default:
                    continuation.resume(throwing: AudioExtractionError.exportFailed("status inesperado"))
                }
            }
        }

        return outputURL
    }
}
