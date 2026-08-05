import SwiftUI

/// The 5 steps shown to the user, in order. Several EditingStage cases map
/// onto "Finding retakes" because that step covers both re-transcribing and
/// diffing the edited audio against the original.
private let processingSteps = [
    "Transcribing audio",
    "Detecting silence",
    "Cutting scenes",
    "Finding retakes",
    "Rendering final video",
]

private func stepIndex(for stage: EditingStage) -> Int? {
    switch stage {
    case .idle, .reviewingRetakes, .done: return nil
    case .transcribingOriginal: return 0
    case .detectingSilence: return 1
    case .renderingCuts: return 2
    case .extractingAudioForQA, .transcribingEdited: return 3
    }
}

struct ProcessingView: View {
    let stage: EditingStage

    @State private var spinDegrees = 0.0

    private var activeIndex: Int { stepIndex(for: stage) ?? processingSteps.count }
    private var fraction: Double {
        Double(activeIndex) / Double(processingSteps.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(fraction * 100))%")
                    .font(Theme.displayFont(20))
                    .foregroundStyle(Theme.accent)
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface2)
                    Capsule().fill(Theme.accent).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(processingSteps.enumerated()), id: \.offset) { index, title in
                    stepRow(title: title, index: index)
                }
            }
        }
        .padding(16)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .onAppear { startSpin() }
    }

    private func stepRow(title: String, index: Int) -> some View {
        HStack(spacing: 10) {
            ZStack {
                if index < activeIndex {
                    Circle().fill(Theme.accent)
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.accentInk)
                } else if index == activeIndex {
                    Circle().stroke(Theme.surface3, lineWidth: 2)
                    Circle().trim(from: 0, to: 0.7).stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(spinDegrees))
                } else {
                    Circle().fill(Theme.paper).overlay(Circle().stroke(Theme.line))
                }
            }
            .frame(width: 18, height: 18)

            Text(title)
                .font(.caption)
                .foregroundStyle(index <= activeIndex ? Theme.ink : Theme.inkSoft)
                .fontWeight(index <= activeIndex ? .semibold : .regular)
        }
    }

    private func startSpin() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
            spinDegrees = 360
        }
    }
}

#Preview {
    ProcessingView(stage: .detectingSilence).padding()
}
