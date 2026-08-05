import SwiftUI

struct HistoryDetailView: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(LinearGradient(colors: [Theme.surface3, Theme.board], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 140)
                .overlay(
                    Image(systemName: entry.kind == .compress ? "arrow.down.right.and.arrow.up.left" : "scissors")
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.accent)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.filename).font(.headline)
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            FeatureInfoCard(rows: infoRows)

            Spacer()

            NavigationLink {
                if entry.kind == .compress { CompressOnlyView() } else { CutOnlyView() }
            } label: {
                Text(entry.kind == .compress ? "Compress another video" : "Cut another video")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.board)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
            }
        }
        .padding()
        .background(Theme.paper)
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var infoRows: [FeatureInfoCard.Row] {
        var rows: [FeatureInfoCard.Row] = [
            .init(icon: "wrench.and.screwdriver", label: "Tool used", value: entry.kind == .compress ? "Compress" : "Cut silence & retakes"),
        ]
        if let original = entry.originalBytes, let result = entry.resultBytes {
            rows.append(.init(icon: "shippingbox", label: "Before", value: ByteFormatting.humanReadableSize(original)))
            rows.append(.init(icon: "shippingbox.fill", label: "After", value: ByteFormatting.humanReadableSize(result)))
        }
        rows.append(.init(icon: "tag", label: "Result", value: entry.resultTag))
        return rows
    }
}

#Preview {
    NavigationStack {
        HistoryDetailView(entry: HistoryEntry(filename: "IMG_4821.mov", kind: .compress, resultTag: "-77%", originalBytes: 250_000_000, resultBytes: 48_000_000))
    }
}
