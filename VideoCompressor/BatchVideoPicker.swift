import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Multi-select sibling of VideoPicker - lets the user pick several videos at once
/// for the batch/queue compress flow. Same underlying PHPickerViewController
/// mechanism, no selection cap and no size limit either.
struct BatchVideoPicker: UIViewControllerRepresentable {
    let onPicked: ([PickedVideo]) -> Void
    var onImportStart: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .videos
        configuration.selectionLimit = 0 // unlimited
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
        let onPicked: ([PickedVideo]) -> Void
        let onImportStart: (() -> Void)?

        init(onPicked: @escaping ([PickedVideo]) -> Void, onImportStart: (() -> Void)?) {
            self.onPicked = onPicked
            self.onImportStart = onImportStart
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }

            DispatchQueue.main.async { [onImportStart] in
                onImportStart?()
            }

            let typeIdentifier = UTType.movie.identifier
            var picked: [PickedVideo] = []
            let group = DispatchGroup()
            let lock = NSLock()

            for result in results {
                let provider = result.itemProvider
                let assetIdentifier = result.assetIdentifier
                guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else { continue }

                group.enter()
                provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _ in
                    defer { group.leave() }
                    guard let url else { return }
                    let fileExtension = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                    let copy = FileManager.default.temporaryDirectory
                        .appendingPathComponent("import-\(UUID().uuidString)")
                        .appendingPathExtension(fileExtension)
                    guard (try? FileManager.default.copyItem(at: url, to: copy)) != nil else { return }
                    lock.lock()
                    picked.append(PickedVideo(url: copy, assetIdentifier: assetIdentifier))
                    lock.unlock()
                }
            }

            group.notify(queue: .main) { [onPicked] in
                onPicked(picked)
            }
        }
    }
}
