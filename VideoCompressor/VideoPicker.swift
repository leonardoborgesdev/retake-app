import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

enum VideoPickerError: LocalizedError {
    case unsupportedItem
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedItem:
            return "The selected item is not a supported video."
        case .loadFailed(let message):
            return "Failed to import the video: \(message)"
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
struct VideoPicker: UIViewControllerRepresentable {
    let onPicked: (Result<PickedVideo, Error>) -> Void

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
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: (Result<PickedVideo, Error>) -> Void

        init(onPicked: @escaping (Result<PickedVideo, Error>) -> Void) {
            self.onPicked = onPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let result = results.first else { return }
            let provider = result.itemProvider
            let assetIdentifier = result.assetIdentifier

            let typeIdentifier = UTType.movie.identifier
            guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else {
                deliver(.failure(VideoPickerError.unsupportedItem))
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
                if let error {
                    self?.deliver(.failure(VideoPickerError.loadFailed(error.localizedDescription)))
                    return
                }
                guard let url else {
                    self?.deliver(.failure(VideoPickerError.loadFailed("empty URL")))
                    return
                }

                do {
                    let fileExtension = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                    let copy = FileManager.default.temporaryDirectory
                        .appendingPathComponent("import-\(UUID().uuidString)")
                        .appendingPathExtension(fileExtension)
                    try FileManager.default.copyItem(at: url, to: copy)
                    self?.deliver(.success(PickedVideo(url: copy, assetIdentifier: assetIdentifier)))
                } catch {
                    self?.deliver(.failure(VideoPickerError.loadFailed(error.localizedDescription)))
                }
            }
        }

        /// loadFileRepresentation's completion handler fires on a background queue, but
        /// onPicked drives @State in a SwiftUI view - mutating that off the main thread
        /// causes half-applied UI updates (e.g. a label appearing with its value missing).
        private func deliver(_ result: Result<PickedVideo, Error>) {
            DispatchQueue.main.async { [onPicked] in
                onPicked(result)
            }
        }
    }
}
