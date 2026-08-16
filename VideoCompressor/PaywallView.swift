import SwiftUI

/// Shown when a free user hits the daily Compress/Cut limit, or taps Find Duplicates /
/// Split for Stories (subscriber-only, no free allowance at all for those two).
struct PaywallView: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var reason: String = "You've used all 10 free videos today."

    var body: some View {
        VStack(spacing: 22) {
            Capsule().fill(Theme.line).frame(width: 36, height: 4).padding(.top, 8)

            AppMark(size: 48)

            VStack(spacing: 6) {
                Text("retake. Unlimited")
                    .font(Theme.displayFont(22))
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
                paywallRow(icon: "arrow.down.right.and.arrow.up.left", text: "Unlimited Compress & Cut, every day")
                paywallRow(icon: "square.on.square", text: "Find duplicates")
                paywallRow(icon: "square.split.2x1", text: "Split for Stories")
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

            Spacer()

            VStack(spacing: 10) {
                Button {
                    Task { await purchase() }
                } label: {
                    Group {
                        if subscriptionStore.isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            VStack(spacing: 2) {
                                Text("\(subscriptionStore.product?.displayPrice ?? "$3.99") / month")
                                    .font(.headline)
                                Text("Cancel anytime")
                                    .font(.caption2)
                                    .opacity(0.8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.board)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                }
                .disabled(subscriptionStore.isPurchasing)

                Button {
                    Task { await restore() }
                } label: {
                    Text("Restore purchases")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .padding(24)
        .background(Theme.paper)
        .alert("Could not continue", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .onChange(of: subscriptionStore.isSubscribed) { subscribed in
            if subscribed { dismiss() }
        }
    }

    private func paywallRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
        }
    }

    private func purchase() async {
        do {
            try await subscriptionStore.purchase()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore() async {
        do {
            try await subscriptionStore.restore()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    PaywallView().environmentObject(SubscriptionStore.shared)
}
