import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            NavigationLink {
                RecordView()
            } label: {
                FeatureCard(
                    systemImage: "doc.text.viewfinder",
                    title: "Record with teleprompter",
                    subtitle: "Paste a script, read it while filming, then compress or cut."
                )
            }

            NavigationLink {
                CompressOnlyView()
            } label: {
                FeatureCard(
                    systemImage: "arrow.down.right.and.arrow.up.left",
                    title: "Compress video",
                    subtitle: "Smaller file, sharper result — on-device, no upload."
                )
            }

            NavigationLink {
                CutOnlyView()
            } label: {
                FeatureCard(
                    systemImage: "scissors",
                    title: "Cut silence & retakes",
                    subtitle: "Finds dead air and repeated lines. You pick the take."
                )
            }

            Spacer()
            Spacer()
        }
        .padding()
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Wordmark(size: 17, color: Theme.ink) }
        }
    }
}

private struct FeatureCard: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 30))
                .frame(width: 40, height: 40)
                .background(Theme.board)
                .foregroundStyle(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.inkSoft)
        }
        .padding()
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .foregroundStyle(Theme.ink)
    }
}

#Preview {
    NavigationStack { HomeView() }.environmentObject(HistoryStore.shared).environmentObject(AccountStore.shared)
}
