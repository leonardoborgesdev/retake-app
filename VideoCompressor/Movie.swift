import Foundation
import CoreTransferable
import UniformTypeIdentifiers

enum MovieImportError: LocalizedError {
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .copyFailed(let message):
            return "Falha ao importar o vídeo: \(message)"
        }
    }
}

struct Movie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let didStartAccess = received.file.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    received.file.stopAccessingSecurityScopedResource()
                }
            }

            let fileExtension = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("import-\(UUID().uuidString)")
                .appendingPathExtension(fileExtension)

            do {
                try FileManager.default.copyItem(at: received.file, to: copy)
            } catch {
                throw MovieImportError.copyFailed(error.localizedDescription)
            }

            return Self(url: copy)
        }
    }
}
