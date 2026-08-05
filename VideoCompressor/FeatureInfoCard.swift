import SwiftUI

/// The "what this does / how long / why" card shown on each tool's empty state,
/// so picking a video isn't the first thing the user has to decide blind.
struct FeatureInfoCard: View {
    struct Row {
        let icon: String
        let label: String
        let value: String
    }

    let rows: [Row]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 10) {
                    Image(systemName: row.icon)
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 18)
                    Text(row.label)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                    Spacer()
                    Text(row.value)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 10)
                if index < rows.count - 1 {
                    Divider().overlay(Theme.line)
                }
            }
        }
        .padding(.horizontal, 14)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}
