import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: HistoryStore

    var body: some View {
        Group {
            if historyStore.entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.inkSoft)
                    Text("No videos yet")
                        .font(.headline)
                    Text("Compress, cut, or split a video and it shows up here.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    Section {
                        HStack {
                            summaryStat(value: "\(historyStore.entries.count)", label: "total")
                            summaryStat(value: ByteFormatting.humanReadableSize(historyStore.totalBytesSaved), label: "space saved")
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    Section {
                        ForEach(historyStore.entries) { entry in
                            NavigationLink {
                                HistoryDetailView(entry: entry)
                            } label: {
                                row(for: entry)
                            }
                            .listRowBackground(Theme.surface2)
                        }
                        .onDelete { offsets in
                            historyStore.delete(at: offsets)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.paper)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for entry: HistoryEntry) -> some View {
        HStack(spacing: 12) {
            HistoryThumbnail(assetIdentifier: entry.resultAssetIdentifier, fallbackIcon: icon(for: entry.kind), size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.filename).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            tag(for: entry)
        }
    }

    @ViewBuilder
    private func tag(for entry: HistoryEntry) -> some View {
        switch entry.status {
        case .pending:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Processing…")
            }
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Theme.surface3)
            .foregroundStyle(Theme.inkSoft)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        case .interrupted:
            Text("Interrupted")
                .font(.caption2.monospaced().weight(.bold))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Theme.discard.opacity(0.15))
                .foregroundStyle(Theme.discard)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        case .completed:
            Text(entry.resultTag)
                .font(.caption2.monospaced().weight(.bold))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Theme.accentSoft)
                .foregroundStyle(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func icon(for kind: HistoryEntry.Kind) -> String {
        switch kind {
        case .compress: return "arrow.down.right.and.arrow.up.left"
        case .cut: return "scissors"
        case .split: return "square.split.2x1"
        }
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.heavy)).monospacedDigit()
            // Text(String) doesn't auto-localize the way Text(literal) does.
            Text(LocalizedStringKey(label)).font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .cardGlassSurface(cornerRadius: 12)
    }
}

#Preview {
    NavigationStack { HistoryView() }.environmentObject(HistoryStore.shared)
}
