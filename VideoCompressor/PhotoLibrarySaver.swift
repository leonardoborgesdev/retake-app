import Foundation
import Photos

enum PhotoLibrarySaveError: LocalizedError {
    case saveFailed(String)
    case deleteFailed(String)
    case assetNotFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Failed to save to Photos: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete the original: \(message)"
        case .assetNotFound:
            return "Could not find the original in Photos anymore."
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
                    continuation.resume(throwing: PhotoLibrarySaveError.saveFailed(error?.localizedDescription ?? "unknown error"))
                }
            })
        }
    }

    /// Deletes the original asset the user picked, identified by the `assetIdentifier` PHPicker
    /// hands back even under limited photo library access (no broader permission needed - this
    /// only works for assets the user just explicitly selected). Always opt-in, never automatic.
    static func deleteAsset(identifier: String) async throws {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            throw PhotoLibrarySaveError.assetNotFound
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }, completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoLibrarySaveError.deleteFailed(error?.localizedDescription ?? "unknown error"))
                }
            })
        }
    }
}
