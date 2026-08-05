import SwiftUI

enum Theme {
    static let ink = Color(hex: 0x0B0B0C)
    static let paper = Color(white: 1.0)
    static let surface2 = Color(hex: 0xF4F4F5)
    static let surface3 = Color(hex: 0xECECED)
    static let line = Color(hex: 0xDCDCE0)
    static let inkSoft = Color(hex: 0x77777C)
    static let accent = Color(hex: 0xE0982C)
    static let accentInk = Color(hex: 0x2B1A03)
    static let accentSoft = Color(hex: 0xF6E3C4)
    static let discard = Color(hex: 0xC65B42)
    static let board = Color(hex: 0x0A0A0B)

    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12

    static var displayFont: Font { .system(.title3, design: .rounded).weight(.heavy) }
    static func displayFont(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static var monoCaption: Font { .system(.caption2, design: .monospaced) }
    static var mono: Font { .system(.footnote, design: .monospaced) }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

/// The wordmark "retake." with the trailing dot in the accent color.
struct Wordmark: View {
    var size: CGFloat = 22
    var color: Color = .primary

    var body: some View {
        (Text("retake").foregroundColor(color) + Text(".").foregroundColor(Theme.accent))
            .font(Theme.displayFont(size))
    }
}

/// The clapperboard + cut-waveform app mark, used on the splash screen.
struct AppMark: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(Theme.board)
            VStack(spacing: 0) {
                ClapperStripe()
                    .frame(height: size * 0.16)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            HStack(spacing: size * 0.05) {
                CutWaveform(color: .white)
                Image(systemName: "pencil.tip")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: size * 0.16, weight: .bold))
                CutWaveform(color: .white)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct ClapperStripe: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, csize in
                let stripeWidth: CGFloat = csize.height * 0.9
                var x: CGFloat = -stripeWidth
                var toggle = false
                while x < csize.width + stripeWidth {
                    if toggle {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + stripeWidth, y: 0))
                        path.addLine(to: CGPoint(x: x + stripeWidth - csize.height, y: csize.height))
                        path.addLine(to: CGPoint(x: x - csize.height, y: csize.height))
                        path.closeSubpath()
                        context.fill(path, with: .color(.white))
                    }
                    toggle.toggle()
                    x += stripeWidth
                }
            }
        }
        .background(Color.black)
    }
}

private struct CutWaveform: View {
    var color: Color
    var body: some View {
        HStack(spacing: 2) {
            ForEach([0.4, 0.9, 0.3, 0.7], id: \.self) { h in
                Capsule()
                    .fill(color)
                    .frame(width: 2.4, height: 14 * h)
            }
        }
    }
}
