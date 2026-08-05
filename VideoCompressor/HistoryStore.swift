import Foundation

struct HistoryEntry: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case compress
        case cut
    }

    let id: UUID
    let filename: String
    let date: Date
    let kind: Kind
    /// Compress: "-77%". Cut: "3 cuts".
    let resultTag: String
    let originalBytes: Int64?
    let resultBytes: Int64?

    init(filename: String, kind: Kind, resultTag: String, originalBytes: Int64? = nil, resultBytes: Int64? = nil) {
        self.id = UUID()
        self.filename = filename
        self.date = Date()
        self.kind = kind
        self.resultTag = resultTag
        self.originalBytes = originalBytes
        self.resultBytes = resultBytes
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [HistoryEntry] = []

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("history.json")
    }

    private init() {
        load()
    }

    func record(_ entry: HistoryEntry) {
        entries.insert(entry, at: 0)
        save()
    }

    var totalBytesSaved: Int64 {
        entries.reduce(0) { partial, entry in
            guard let original = entry.originalBytes, let result = entry.resultBytes else { return partial }
            return partial + max(0, original - result)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
