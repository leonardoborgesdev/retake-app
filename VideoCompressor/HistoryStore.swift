import Foundation

struct HistoryEntry: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case compress
        case cut
        case split
    }

    /// .pending is written the moment a job starts, before any real work happens - if
    /// the app is killed mid-job (backgrounded too long, crashed) and never gets to
    /// resolve it, HistoryStore.load() finds it still .pending on the next launch and
    /// flips it to .interrupted, so the job doesn't just silently vanish.
    enum Status: String, Codable {
        case pending
        case completed
        case interrupted
    }

    let id: UUID
    let filename: String
    let date: Date
    let kind: Kind
    var status: Status
    /// Compress: "-77%". Cut: "3 cuts".
    var resultTag: String
    var originalBytes: Int64?
    var resultBytes: Int64?
    /// Length of the source video, in seconds - independent of how long processing took.
    let sourceDurationSeconds: Double?
    /// Wall-clock time the compress/cut operation itself took, in seconds.
    var processingSeconds: Double?
    /// Local identifier of the resulting Photos asset (the first clip's, for Split),
    /// used to fetch a real thumbnail. Nil for entries recorded before this existed, or
    /// if the save didn't return one - the UI falls back to a per-kind icon either way.
    var resultAssetIdentifier: String?

    init(
        filename: String,
        kind: Kind,
        resultTag: String,
        originalBytes: Int64? = nil,
        resultBytes: Int64? = nil,
        sourceDurationSeconds: Double? = nil,
        processingSeconds: Double? = nil,
        resultAssetIdentifier: String? = nil,
        status: Status = .completed
    ) {
        self.id = UUID()
        self.filename = filename
        self.date = Date()
        self.kind = kind
        self.status = status
        self.resultTag = resultTag
        self.originalBytes = originalBytes
        self.resultBytes = resultBytes
        self.sourceDurationSeconds = sourceDurationSeconds
        self.processingSeconds = processingSeconds
        self.resultAssetIdentifier = resultAssetIdentifier
    }

    private enum CodingKeys: String, CodingKey {
        case id, filename, date, kind, status, resultTag, originalBytes, resultBytes, sourceDurationSeconds, processingSeconds, resultAssetIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        filename = try container.decode(String.self, forKey: .filename)
        date = try container.decode(Date.self, forKey: .date)
        kind = try container.decode(Kind.self, forKey: .kind)
        // Entries saved before .status existed have no such key - treat them as
        // completed, since that's the only kind of entry that used to get recorded.
        status = (try container.decodeIfPresent(Status.self, forKey: .status)) ?? .completed
        resultTag = try container.decode(String.self, forKey: .resultTag)
        originalBytes = try container.decodeIfPresent(Int64.self, forKey: .originalBytes)
        resultBytes = try container.decodeIfPresent(Int64.self, forKey: .resultBytes)
        sourceDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .sourceDurationSeconds)
        processingSeconds = try container.decodeIfPresent(Double.self, forKey: .processingSeconds)
        resultAssetIdentifier = try container.decodeIfPresent(String.self, forKey: .resultAssetIdentifier)
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

    /// Call the moment a job starts, before any real work happens - gives the job a
    /// History row immediately (shown as "Processing…") instead of only appearing once
    /// it succeeds. Follow up with markCompleted or discardPending.
    @discardableResult
    func recordPending(filename: String, kind: HistoryEntry.Kind, sourceDurationSeconds: Double?) -> UUID {
        let entry = HistoryEntry(
            filename: filename,
            kind: kind,
            resultTag: "Processing…",
            sourceDurationSeconds: sourceDurationSeconds,
            status: .pending
        )
        entries.insert(entry, at: 0)
        save()
        return entry.id
    }

    func markCompleted(
        id: UUID,
        resultTag: String,
        originalBytes: Int64? = nil,
        resultBytes: Int64? = nil,
        processingSeconds: Double? = nil,
        resultAssetIdentifier: String? = nil
    ) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].status = .completed
        entries[index].resultTag = resultTag
        entries[index].originalBytes = originalBytes
        entries[index].resultBytes = resultBytes
        entries[index].processingSeconds = processingSeconds
        entries[index].resultAssetIdentifier = resultAssetIdentifier
        save()
    }

    /// Removes a pending entry outright - used when a job fails or is cancelled inside
    /// the same session (a real error already surfaces its own alert; an interrupted
    /// row is only useful for jobs that vanished without either).
    func discardPending(id: UUID) {
        entries.removeAll { $0.id == id && $0.status == .pending }
        save()
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    func delete(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
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
              var decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        // A .pending entry that survives to a fresh launch means the app never got to
        // resolve it last time (killed while backgrounded, crashed) - flag it instead
        // of leaving it stuck reading "Processing…" forever.
        var changed = false
        for index in decoded.indices where decoded[index].status == .pending {
            decoded[index].status = .interrupted
            changed = true
        }
        entries = decoded
        if changed { save() }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
