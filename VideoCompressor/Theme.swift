import SwiftUI

enum Theme {
    static let ink = Color.adaptive(light: 0x0B0B0C, dark: 0xF2F2F3)
    static let paper = Color.adaptive(light: 0xFFFFFF, dark: 0x111113)
    static let surface2 = Color.adaptive(light: 0xF4F4F5, dark: 0x1B1B1E)
    static let surface3 = Color.adaptive(light: 0xECECED, dark: 0x222226)
    static let line = Color.adaptive(light: 0xDCDCE0, dark: 0x2D2D32)
    static let inkSoft = Color.adaptive(light: 0x77777C, dark: 0x94949A)
    static let accent = Color.adaptive(light: 0xE0982C, dark: 0xF0AB42)
    /// Only ever used as text sitting on top of Theme.accent itself (e.g. buttons) -
    /// safe to keep a single dark value since the accent stays bright in both themes.
    static let accentInk = Color(hex: 0x2B1A03)
    static let accentSoft = Color.adaptive(light: 0xF6E3C4, dark: 0x3A2A10)
    static let discard = Color(hex: 0xC65B42)
    /// Deliberately static near-black - the claquette "slate" used for the app mark,
    /// splash, and onboarding, independent of the viewer's light/dark setting.
    static let board = Color(hex: 0x0A0A0B)

    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12

    static var displayFont: Font { .system(.title3, design: .rounded).weight(.heavy) }
    static func displayFont(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static var monoCaption: Font { .system(.caption2, design: .monospaced) }
    static var mono: Font { .system(.footnote, design: .monospaced) }
}

extension View {
    /// The app's primary filled-button treatment: Apple's native Liquid Glass material
    /// on iOS 26+ (the real system effect, not a recreation), the existing solid
    /// Theme.board fill on earlier versions. Glass owns its own foreground/shape
    /// together rather than composing with separate .background/.clipShape calls.
    @ViewBuilder
    func primaryButtonSurface(cornerRadius: CGFloat = Theme.controlRadius) -> some View {
        if #available(iOS 26.0, *) {
            self
                .foregroundStyle(.white)
                .glassEffect(.regular.tint(Theme.accent).interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self
                .background(Theme.board)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    /// A second filled-CTA tone (e.g. "Start recording", "Cut silence") that already
    /// used Theme.accent + accentInk text pre-glass - kept as its own modifier rather
    /// than folded into primaryButtonSurface since the foreground stays accentInk
    /// (reads better on the lighter accent tint) instead of white.
    @ViewBuilder
    func accentButtonSurface<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self
                .foregroundStyle(Theme.accentInk)
                .glassEffect(.regular.tint(Theme.accent).interactive(), in: shape)
        } else {
            self
                .background(Theme.accent)
                .foregroundStyle(Theme.accentInk)
                .clipShape(shape)
        }
    }

    /// Destructive filled control (Stop recording, Delete selected/duplicates).
    @ViewBuilder
    func destructiveButtonSurface<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self
                .foregroundStyle(.white)
                .glassEffect(.regular.tint(Theme.discard).interactive(), in: shape)
        } else {
            self
                .background(Theme.discard)
                .foregroundStyle(.white)
                .clipShape(shape)
        }
    }

    /// Outlined secondary button (Record again, Compress another, Split another video).
    /// Glass replaces the hairline stroke on iOS 26+ since the material already carries
    /// its own edge highlight - a stroke drawn on top of it would double up.
    @ViewBuilder
    func outlinedButtonSurface<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.overlay(shape.stroke(Theme.line))
        }
    }

    /// A light/paper-toned filled pill, used where the surrounding view is already dark
    /// (e.g. onboarding's "Continue"/"Get started" button over Theme.board).
    @ViewBuilder
    func lightButtonSurface<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self
                .foregroundStyle(Theme.ink)
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            self
                .background(Theme.paper)
                .foregroundStyle(Theme.ink)
                .clipShape(shape)
        }
    }

    /// Elevated card container (feature rows, info cards, batch/result lists, stat
    /// tiles) - untinted glass on iOS 26+ so it reads as floating over the page rather
    /// than another flat fill stacked on Theme.paper.
    @ViewBuilder
    func cardGlassSurface(cornerRadius: CGFloat = Theme.cardRadius, fallbackFill: Color = Theme.surface2) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self
                .background(fallbackFill)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    /// Small chip/icon control that floats directly over dynamic content (camera
    /// preview, video playback) rather than over the app's own flat background - e.g.
    /// Record's REC status badge and the free-tier usage badge on Account.
    @ViewBuilder
    func floatingGlassSurface<S: Shape>(in shape: S, tint: Color? = nil, fallbackFill: Color = .black.opacity(0.55)) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(), in: shape)
            } else {
                self.glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            self
                .background(fallbackFill)
                .clipShape(shape)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// A color that switches between a light- and dark-appearance value automatically,
    /// following the system (or the artifact's own theme toggle, when embedded).
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32, opacity: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: opacity)
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
