import SwiftUI

/// Shown when a free user hits the daily Compress/Cut limit, taps "Delete selected" in
/// Find Duplicates, or taps "Save to Photos" after a Split - all three tools stay usable
/// for free up to that point, so this is reached only once there's real value on screen
/// to point back to, not as a cold wall before anything has happened.
struct PaywallView: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var reason: String = "You've used all 10 free videos today."

    private var productIsMissing: Bool {
        subscriptionStore.didAttemptLoad && subscriptionStore.product == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .padding(.top, 4)

            AppMark(size: 52)
                .padding(.top, 8)

            VStack(spacing: 6) {
                Text("retake. Unlimited")
                    .font(Theme.displayFont(24))
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 14)

            VStack(spacing: 0) {
                benefitRow(
                    icon: "arrow.down.right.and.arrow.up.left",
                    title: "Compress & Cut without the daily cap",
                    detail: "No more counting down to 10 a day"
                )
                Divider().overlay(Theme.line).padding(.leading, 54)
                benefitRow(
                    icon: "square.on.square",
                    title: "Find Duplicates",
                    detail: "Clean up the copies Compress leaves behind"
                )
                Divider().overlay(Theme.line).padding(.leading, 54)
                benefitRow(
                    icon: "square.split.2x1",
                    title: "Split for Stories",
                    detail: "Ready-to-post clips, cut in seconds"
                )
            }
            .padding(.vertical, 6)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .padding(.top, 20)

            Spacer(minLength: 20)

            VStack(spacing: 4) {
                Text(subscriptionStore.product?.displayPrice ?? "$3.99")
                    .font(Theme.displayFont(30))
                    .foregroundStyle(Theme.accent)
                Text("per month, cancel anytime")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.bottom, 14)

            VStack(spacing: 10) {
                Button {
                    Task { await purchase() }
                } label: {
                    Group {
                        if subscriptionStore.isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text("Get Unlimited")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .primaryButtonSurface()
                }
                .disabled(subscriptionStore.isPurchasing)

                if productIsMissing {
                    Text("Not available on the App Store yet. Try again shortly.")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }

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
        .task {
            if subscriptionStore.product == nil {
                await subscriptionStore.loadProduct()
            }
        }
        .alert("Could not continue", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .onChange(of: subscriptionStore.isSubscribed) { subscribed in
            if subscribed { dismiss() }
        }
    }

    private func benefitRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 30, height: 30)
                .background(Theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
