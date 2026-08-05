import SwiftUI

struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var page = 0
    private let pageCount = 2

    var body: some View {
        ZStack {
            Theme.board.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 5) {
                        ForEach(0..<pageCount, id: \.self) { i in
                            Capsule()
                                .fill(i == page ? Color.white : Color.white.opacity(0.25))
                                .frame(width: i == page ? 18 : 6, height: 6)
                        }
                    }
                    Spacer()
                    Button("Skip") { onFinished() }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                TabView(selection: $page) {
                    OnboardingPage(
                        headline: "Detect every\nsilent gap",
                        cardTitle: "Hear the problem",
                        cardSubtitle: "Amber segments are dead air — the same audio that would sit untouched in a plain edit."
                    ) {
                        WaveformDemo(style: .original)
                    }
                    .tag(0)

                    OnboardingPage(
                        headline: "Cut silence\nin one tap",
                        cardTitle: "Silence removed",
                        cardSubtitle: "Only the sound stays. Tighter, faster, ready to share."
                    ) {
                        WaveformDemo(style: .trimmed)
                    }
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Button {
                    if page < pageCount - 1 {
                        withAnimation { page += 1 }
                    } else {
                        onFinished()
                    }
                } label: {
                    Text(page < pageCount - 1 ? "Continue" : "Get started")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.paper)
                        .foregroundStyle(Theme.ink)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}

private struct OnboardingPage<Demo: View>: View {
    let headline: String
    let cardTitle: String
    let cardSubtitle: String
    @ViewBuilder var demo: Demo

    var body: some View {
        VStack(spacing: 28) {
            Text(headline)
                .font(Theme.displayFont(32))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 28)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 16) {
                Text(cardTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(cardSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                demo

                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.caption)
                    Text("Playing…")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(20)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
    }
}

private struct WaveformDemo: View {
    enum Style { case original, trimmed }
    let style: Style

    private var bars: [CGFloat] {
        switch style {
        case .original: return [0.9, 0.6, 0.3, 0.7, 0.4, 0, 0, 0.5, 0.8, 0.9, 0.3, 0, 0, 0.6, 0.9, 0.5]
        case .trimmed: return [0.9, 0.6, 0.3, 0.7, 0.4, 0.5, 0.8, 0.9, 0.3, 0.6, 0.9, 0.5]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, h in
                    Capsule()
                        .fill(h == 0 ? Theme.discard.opacity(0.5) : .white)
                        .frame(width: 5, height: max(4, 34 * h))
                }
            }
            .frame(height: 34, alignment: .center)

            HStack {
                switch style {
                case .original:
                    Label("Original · 3.5s", systemImage: "circle.fill")
                        .labelStyle(.dotLabel(color: .white.opacity(0.5)))
                    Spacer()
                    Label("silence", systemImage: "circle.fill")
                        .labelStyle(.dotLabel(color: Theme.discard))
                case .trimmed:
                    Label("Trimmed · 1.8s", systemImage: "circle.fill")
                        .labelStyle(.dotLabel(color: .white.opacity(0.5)))
                    Spacer()
                    Text("−1.7s saved")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.accent)
                        .foregroundStyle(Theme.accentInk)
                        .clipShape(Capsule())
                }
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding(14)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct DotLabelStyle: LabelStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.foregroundStyle(color).font(.system(size: 6))
            configuration.title
        }
    }
}

private extension LabelStyle where Self == DotLabelStyle {
    static func dotLabel(color: Color) -> DotLabelStyle { DotLabelStyle(color: color) }
}

#Preview {
    OnboardingView(onFinished: {})
}
