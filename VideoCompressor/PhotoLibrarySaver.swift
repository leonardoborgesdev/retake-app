import Foundation
import Photos

enum PhotoLibrarySaveError: LocalizedError {
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Falha ao salvar na galeria: \(message)"
        }
    }
}

enum PhotoLibrarySaver {
    static func save(videoURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }, completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoLibrarySaveError.saveFailed(error?.localizedDescription ?? "erro desconhecido"))
                }
            })
        }
    }
}
