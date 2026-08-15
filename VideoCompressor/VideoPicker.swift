import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

enum VideoPickerError: LocalizedError {
    case unsupportedItem
    case loadFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unsupportedItem:
            return "The selected item is not a supported video."
        case .loadFailed(let message):
            return "Failed to import the video: \(message)"
        case .cancelled:
            return "Import was cancelled."
        }
    }
}

struct PickedVideo {
    let url: URL
    /// PHPicker still hands this back under limited library access, scoped to the item the
    /// user just selected - it is what lets "delete the original" work without asking for
    /// broader Photos permission.
    let assetIdentifier: String?
}

/// Wraps PHPickerViewController directly instead of SwiftUI's PhotosPicker: the CoreTransferable
/// pipeline behind PhotosPicker.loadTransferable can fail or hang on large videos (tens of
/// minutes / multiple GB). PHPickerViewController + NSItemProvider.loadFileRepresentation is the
/// same native mechanism Photos itself uses to export files and is far more reliable at scale.
/// No file size or duration limit is imposed here - large/4K/iCloud-only videos work the same
/// way, just slower to export; onImportStart lets the caller show progress for that wait.
struct VideoPicker: UIViewControllerRepresentable {
    let onPicked: (Result<PickedVideo, Error>) -> Void
    var onImportStart: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .videos
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, onImportStart: onImportStart)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: (Result<PickedVideo, Error>) -> Void
        let onImportStart: (() -> Void)?

        init(onPicked: @escaping (Result<PickedVideo, Error>) -> Void, onImportStart: (() -> Void)?) {
            self.onPicked = onPicked
            self.onImportStart = onImportStart
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            // Capture the closures as local values (not through self) so delivery never
            // depends on this Coordinator still being alive when the async load finishes -
            // previously used [weak self] here, and if SwiftUI tore the coordinator down
            // mid-load (large/iCloud video, slow network), self?.deliver(...) silently
            // became a no-op: onPicked never fired, and the screen stayed on "Preparing
            // video..." forever with no way out.
            let onPicked = self.onPicked
            let onImportStart = self.onImportStart

            func deliver(_ result: Result<PickedVideo, Error>) {
                DispatchQueue.main.async {
                    onPicked(result)
                }
            }

            guard let result = results.first else {
                deliver(.failure(VideoPickerError.cancelled))
                return
            }
            let provider = result.itemProvider
            let assetIdentifier = result.assetIdentifier

            let typeIdentifier = UTType.movie.identifier
            guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else {
                deliver(.failure(VideoPickerError.unsupportedItem))
                return
            }

            // Large or iCloud-only videos can take a while to export - signal "started"
            // now, before the (possibly long) load, so the caller can show a spinner
            // instead of the screen looking frozen with nothing selected.
            DispatchQueue.main.async {
                onImportStart?()
            }

            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    deliver(.failure(VideoPickerError.loadFailed(error.localizedDescription)))
                    return
                }
                guard let url else {
                    deliver(.failure(VideoPickerError.loadFailed("empty URL")))
                    return
                }

                do {
                    let fileExtension = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                    let copy = FileManager.default.temporaryDirectory
                        .appendingPathComponent("import-\(UUID().uuidString)")
                        .appendingPathExtension(fileExtension)
                    try FileManager.default.copyItem(at: url, to: copy)
                    deliver(.success(PickedVideo(url: copy, assetIdentifier: assetIdentifier)))
                } catch {
                    deliver(.failure(VideoPickerError.loadFailed(error.localizedDescription)))
                }
            }
        }
    }
}
