import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

enum VideoPickerError: LocalizedError {
    case unsupportedItem
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedItem:
            return "O item selecionado não é um vídeo suportado."
        case .loadFailed(let message):
            return "Falha ao importar o vídeo: \(message)"
        }
    }
}

/// Wraps PHPickerViewController directly instead of SwiftUI's PhotosPicker: the CoreTransferable
/// pipeline behind PhotosPicker.loadTransferable can fail or hang on large videos (tens of
/// minutes / multiple GB). PHPickerViewController + NSItemProvider.loadFileRepresentation is the
/// same native mechanism Photos itself uses to export files and is far more reliable at scale.
struct VideoPicker: UIViewControllerRepresentable {
    let onPicked: (Result<URL, Error>) -> Void

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
        let onPicked: (Result<URL, Error>) -> Void

        init(onPicked: @escaping (Result<URL, Error>) -> Void) {
            self.onPicked = onPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            let typeIdentifier = UTType.movie.identifier
            guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else {
                onPicked(.failure(VideoPickerError.unsupportedItem))
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [onPicked] url, error in
                if let error {
                    onPicked(.failure(VideoPickerError.loadFailed(error.localizedDescription)))
                    return
                }
                guard let url else {
                    onPicked(.failure(VideoPickerError.loadFailed("URL vazia")))
                    return
                }

                do {
                    let fileExtension = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                    let copy = FileManager.default.temporaryDirectory
                        .appendingPathComponent("import-\(UUID().uuidString)")
                        .appendingPathExtension(fileExtension)
                    try FileManager.default.copyItem(at: url, to: copy)
                    onPicked(.success(copy))
                } catch {
                    onPicked(.failure(VideoPickerError.loadFailed(error.localizedDescription)))
                }
            }
        }
    }
}
