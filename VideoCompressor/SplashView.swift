import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void

    @State private var spin = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            AppMark(size: 64)
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 34, height: 34)
                .rotationEffect(.degrees(spin ? 360 : 0))
            VStack(spacing: 6) {
                Wordmark(size: 18)
                Text("WARMING UP FFMPEG...")
                    .font(Theme.monoCaption)
                    .foregroundStyle(Theme.inkSoft)
                    .tracking(1.2)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper)
        .onAppear {
            if !UIAccessibility.isReduceMotionEnabled {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    spin = true
                }
            }
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                onFinished()
            }
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
