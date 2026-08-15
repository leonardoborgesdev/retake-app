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
        try await deleteAssets(identifiers: [identifier])
    }

    /// Batch delete, used by Find Duplicates so removing several videos the user selected is
    /// one system confirmation instead of one per video.
    static func deleteAssets(identifiers: [String]) async throws {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard fetchResult.count > 0 else {
            throw PhotoLibrarySaveError.assetNotFound
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(fetchResult)
            }, completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoLibrarySaveError.deleteFailed(error?.localizedDescription ?? "unknown error"))
                }
            })
        }
    }

    /// Full-library read access, needed only by Find Duplicates - Compress/Cut/Split never
    /// need this since PHPickerViewController works with zero Photos permission at all.
    static func requestReadWriteAuthorization() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status == .authorized || status == .limited)
            }
        }
    }
}
