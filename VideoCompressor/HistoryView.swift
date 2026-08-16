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
            Text(label).font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack { HistoryView() }.environmentObject(HistoryStore.shared)
}
