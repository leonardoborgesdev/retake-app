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
                    Text("Compress or cut a video and it shows up here.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List(historyStore.entries) { entry in
                    NavigationLink {
                        HistoryDetailView(entry: entry)
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(colors: [Theme.surface3, Theme.board], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: entry.kind == .compress ? "arrow.down.right.and.arrow.up.left" : "scissors")
                                        .font(.caption)
                                        .foregroundStyle(Theme.accent)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.filename).font(.subheadline.weight(.semibold))
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
                    .listRowBackground(Theme.surface2)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.paper)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { HistoryView() }.environmentObject(HistoryStore.shared)
}
