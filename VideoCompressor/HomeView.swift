import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            NavigationLink {
                CompressOnlyView()
            } label: {
                FeatureCard(
                    systemImage: "arrow.down.right.and.arrow.up.left",
                    title: "Compress video",
                    subtitle: "Smaller file, sharper result — on-device, no upload. Any length, any size."
                )
            }

            // Cut silence & retakes is the app's real differentiator - retake detection
            // with manual take review doesn't exist in any other native iOS app, only in
            // desktop plugins/SaaS. Featured here, not hidden as a bonus.
            NavigationLink {
                CutOnlyView()
            } label: {
                FeatureCard(
                    systemImage: "waveform.badge.magnifyingglass",
                    title: "Cut silence & retakes",
                    subtitle: "Finds dead air and repeated lines. You pick the take.",
                    badge: "Unique to retake."
                )
            }

            // Find Duplicates: retake.'s own users generate exactly this clutter -
            // every Compress run leaves the original behind. Same-length, same-day
            // grouping, on-device, nothing deletes without explicit confirmation.
            NavigationLink {
                DuplicateFinderView()
            } label: {
                FeatureCard(
                    systemImage: "square.on.square",
                    title: "Find duplicates",
                    subtitle: "Groups same-length videos from the same day. You choose what to delete.",
                    badge: "Pro"
                )
            }

            // Split for Stories: fixed-length sequential clips, no AI - pairs with
            // Compress/Cut to cover the whole "record -> shrink -> post" chain.
            NavigationLink {
                StorySplitView()
            } label: {
                FeatureCard(
                    systemImage: "square.split.2x1",
                    title: "Split for Stories",
                    subtitle: "Cut one long take into ordered clips, ready to post.",
                    badge: "Pro"
                )
            }

            // Record with teleprompter stays bonus/unlinked for now - implemented,
            // documented in the README, not surfaced in Home yet.

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
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 30))
                .frame(width: 40, height: 40)
                .background(Theme.board)
                .foregroundStyle(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                // Text(String) doesn't auto-localize the way Text(literal) does - title/
                // subtitle/badge are String (set from literals at each call site), so
                // this wraps them back into LocalizedStringKey to actually hit
                // Localizable.xcstrings instead of always showing the English source.
                Text(LocalizedStringKey(title)).font(.headline)
                if let badge {
                    Text(LocalizedStringKey(badge))
                        .textCase(.uppercase)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.accentSoft)
                        .foregroundStyle(Theme.accent)
                        .clipShape(Capsule())
                }
                Text(LocalizedStringKey(subtitle)).font(.subheadline).foregroundStyle(Theme.inkSoft)
            }

            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft)
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
