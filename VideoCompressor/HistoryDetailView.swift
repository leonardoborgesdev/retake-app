import SwiftUI

struct HistoryDetailView: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(spacing: 20) {
            GeometryReader { geo in
                HistoryThumbnail(
                    assetIdentifier: entry.resultAssetIdentifier,
                    fallbackIcon: kindIcon,
                    width: geo.size.width,
                    height: 180,
                    cornerRadius: Theme.cardRadius
                )
            }
            .frame(height: 180)

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
                destinationView
            } label: {
                Text(actionLabel)
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

    private var kindIcon: String {
        switch entry.kind {
        case .compress: return "arrow.down.right.and.arrow.up.left"
        case .cut: return "scissors"
        case .split: return "square.split.2x1"
        }
    }

    private var kindLabel: String {
        switch entry.kind {
        case .compress: return "Compress"
        case .cut: return "Cut silence & retakes"
        case .split: return "Split for Stories"
        }
    }

    private var actionLabel: String {
        switch entry.kind {
        case .compress: return "Compress another video"
        case .cut: return "Cut another video"
        case .split: return "Split another video"
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch entry.kind {
        case .compress: CompressOnlyView()
        case .cut: CutOnlyView()
        case .split: StorySplitView()
        }
    }

    private var infoRows: [FeatureInfoCard.Row] {
        var rows: [FeatureInfoCard.Row] = [
            .init(icon: "wrench.and.screwdriver", label: "Tool used", value: kindLabel),
        ]
        if let duration = entry.sourceDurationSeconds {
            rows.append(.init(icon: "timeline.selection", label: "Video length", value: Self.formatDuration(duration)))
        }
        if let original = entry.originalBytes, let result = entry.resultBytes {
            rows.append(.init(icon: "shippingbox", label: "Before", value: ByteFormatting.humanReadableSize(original)))
            rows.append(.init(icon: "shippingbox.fill", label: "After", value: ByteFormatting.humanReadableSize(result)))
            let saved = max(0, original - result)
            if saved > 0 {
                rows.append(.init(icon: "arrow.down.circle", label: "Space saved", value: ByteFormatting.humanReadableSize(saved)))
            }
        }
        rows.append(.init(icon: "tag", label: "Result", value: entry.resultTag))
        if let processing = entry.processingSeconds {
            rows.append(.init(icon: "clock", label: "Processing time", value: Self.formatDuration(processing)))
        }
        return rows
    }

    private static func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds.rounded())
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return minutes > 0 ? "\(minutes)m \(secs)s" : "\(secs)s"
    }
}

#Preview {
    NavigationStack {
        HistoryDetailView(entry: HistoryEntry(filename: "IMG_4821.mov", kind: .compress, resultTag: "-77%", originalBytes: 250_000_000, resultBytes: 48_000_000))
    }
}
