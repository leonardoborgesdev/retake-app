import SwiftUI
import AVKit

/// Camera + teleprompter recorder. Ported from the GSA web teleprompter
/// (mobile-upload page) to a native flow: no QR code, no chunked upload -
/// record straight into Compress or Cut silence & retakes.
struct RecordView: View {
    private enum Stage { case setup, ready, recording, reviewing }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = CameraRecorder()
    @State private var stage: Stage = .setup
    @State private var isStartingCamera = false
    @State private var script = ""
    @State private var fontSize: CGFloat = 22
    @State private var scrollSpeed: Double = 8
    @State private var elapsed = 0
    @State private var elapsedTimer: Timer?
    @State private var recordedURL: URL?
    @State private var player: AVPlayer?
    @State private var goToCompress = false
    @State private var goToCut = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                cameraOrPlayback
                if stage == .recording {
                    Teleprompter(script: script, fontSize: fontSize, scrollSpeed: scrollSpeed, isPaused: recorder.isPaused)
                        .padding(.horizontal, 18)
                        .padding(.top, 70)
                }
                if isStartingCamera {
                    ProgressView().tint(.white)
                }
                VStack {
                    HStack {
                        statusBadge
                        Spacer()
                        Button {
                            forceClose()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white, .black.opacity(0.4))
                        }
                    }
                    Spacer()
                    if stage == .recording {
                        recordingControls
                    }
                }
                .padding(14)
            }
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .background(Theme.board)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))

            if stage == .setup || stage == .ready {
                setupControls
            }

            if stage == .reviewing {
                reviewControls
            }

            Spacer()
        }
        .padding()
        .background(Theme.paper)
        .navigationTitle("Record")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToCompress) {
            if let recordedURL { CompressOnlyView(initialURL: recordedURL) }
        }
        .navigationDestination(isPresented: $goToCut) {
            if let recordedURL { CutOnlyView(initialURL: recordedURL) }
        }
        .alert("Error", isPresented: .constant(recorder.errorMessage != nil), actions: {
            Button("OK") { recorder.errorMessage = nil }
        }, message: {
            Text(recorder.errorMessage ?? "")
        })
        .onDisappear {
            if recorder.isRecording { recorder.stop() }
            recorder.stopSession()
        }
    }

    @ViewBuilder
    private var cameraOrPlayback: some View {
        if stage == .reviewing, let player {
            VideoPlayer(player: player)
        } else if stage == .ready || stage == .recording {
            CameraPreview(session: recorder.session)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "text.below.photo")
                    .font(.system(size: 34))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Paste your script, then allow the camera.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }

    private var statusBadge: some View {
        Text(stage == .recording ? (recorder.isPaused ? "PAUSED" : "REC") + " · \(formatted(elapsed)) " : "")
            .font(.caption2.monospaced().weight(.bold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.black.opacity(0.55))
            .foregroundStyle(recorder.isPaused ? .white : Theme.discard)
            .clipShape(Capsule())
            .opacity(stage == .recording ? 1 : 0)
    }

    private var recordingControls: some View {
        HStack(spacing: 10) {
            if recorder.canPauseResume {
                Button {
                    if recorder.isPaused { resume() } else { pause() }
                } label: {
                    Text(recorder.isPaused ? "Resume" : "Pause")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Theme.accent)
                        .foregroundStyle(Theme.accentInk)
                        .clipShape(Capsule())
                }
            }
            Button {
                stopRecording()
            } label: {
                Text("Stop")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Theme.discard)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var setupControls: some View {
        VStack(spacing: 12) {
            if stage == .setup {
                FeatureInfoCard(rows: [
                    .init(icon: "text.viewfinder", label: "What it does", value: "Scrolls your script over the camera"),
                    .init(icon: "clock", label: "Takes about", value: "As long as your script needs"),
                    .init(icon: "checkmark.seal", label: "Benefit", value: "No cue cards, no memorizing"),
                ])
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("SCRIPT").font(.caption2.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                TextEditor(text: $script)
                    .frame(height: 90)
                    .padding(6)
                    .background(Theme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Text size").font(.caption2).foregroundStyle(Theme.inkSoft)
                    Slider(value: $fontSize, in: 16...34).tint(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Speed").font(.caption2).foregroundStyle(Theme.inkSoft)
                    Slider(value: $scrollSpeed, in: 2...20).tint(Theme.accent)
                }
            }

            if stage == .setup {
                Button {
                    Task { await allowCamera() }
                } label: {
                    Text("Allow camera & microphone")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.board)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                }
            } else {
                Button {
                    startRecording()
                } label: {
                    Text("Start recording")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent)
                        .foregroundStyle(Theme.accentInk)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                }
            }
        }
    }

    private var reviewControls: some View {
        VStack(spacing: 10) {
            Button {
                recordAgain()
            } label: {
                Text("Record again")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.line))
            }
            HStack(spacing: 10) {
                Button {
                    goToCompress = true
                } label: {
                    Text("Compress")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.board)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                }
                Button {
                    goToCut = true
                } label: {
                    Text("Cut silence")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent)
                        .foregroundStyle(Theme.accentInk)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
                }
            }
        }
    }

    private func allowCamera() async {
        let granted = await recorder.requestAccessAndConfigure()
        guard granted else { return }
        isStartingCamera = true
        await recorder.startSession()
        isStartingCamera = false
        stage = .ready
    }

    private func forceClose() {
        if recorder.isRecording { recorder.stop() }
        Task { await recorder.stopSession() }
        dismiss()
    }

    private func startRecording() {
        stage = .recording
        elapsed = 0
        startElapsedTimer()
        recorder.startRecording { url in
            self.recordedURL = url
            self.player = AVPlayer(url: url)
            self.stage = .reviewing
            self.elapsedTimer?.invalidate()
        }
    }

    private func pause() {
        recorder.pause()
        elapsedTimer?.invalidate()
    }

    private func resume() {
        recorder.resume()
        startElapsedTimer()
    }

    private func stopRecording() {
        recorder.stop()
    }

    private func recordAgain() {
        recordedURL = nil
        player = nil
        Task {
            isStartingCamera = true
            await recorder.startSession()
            isStartingCamera = false
            stage = .ready
        }
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in elapsed += 1 }
        }
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct Teleprompter: View {
    let script: String
    let fontSize: CGFloat
    let scrollSpeed: Double
    let isPaused: Bool

    @State private var offset: CGFloat = 0
    @State private var timer: Timer?

    var body: some View {
        GeometryReader { geo in
            VStack {
                Text(script.isEmpty ? "No script." : script)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, geo.size.height)
                    .offset(y: -offset)
            }
            .frame(width: geo.size.width, height: geo.size.height * 0.5, alignment: .top)
            .clipped()
            .padding(10)
            .background(.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.2)))
        }
        .frame(height: 220)
        .onAppear { offset = 0; startTimer() }
        .onDisappear { timer?.invalidate() }
        .onChange(of: isPaused) { paused in
            if paused { timer?.invalidate() } else { startTimer() }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        guard !isPaused else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            Task { @MainActor in offset += CGFloat(scrollSpeed) * 0.5 }
        }
    }
}

#Preview {
    NavigationStack { RecordView() }.environmentObject(HistoryStore.shared)
}
