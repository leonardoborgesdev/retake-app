import AVFoundation
import SwiftUI
import UIKit

/// Wraps AVCaptureSession + AVCaptureMovieFileOutput for the teleprompter recorder.
/// Records straight to a local file - no upload, no chunking (the GSA web version
/// needed that because it runs in a browser talking to a remote server; here the
/// file is already on-device and feeds straight into Compress/Cut).
@MainActor
final class CameraRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published var errorMessage: String?

    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var onFinished: ((URL) -> Void)?
    private var configured = false

    func requestAccessAndConfigure() async -> Bool {
        let cameraOK = await AVCaptureDevice.requestAccess(for: .video)
        let micOK = await AVCaptureDevice.requestAccess(for: .audio)
        guard cameraOK, micOK else {
            errorMessage = "Camera and microphone access are required to record."
            return false
        }
        configure()
        return true
    }

    private func configure() {
        guard !configured else { return }
        configured = true

        session.beginConfiguration()
        session.sessionPreset = .high

        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) {
            session.addInput(input)
        }
        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic), session.canAddInput(micInput) {
            session.addInput(micInput)
        }
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
            if connection.isVideoMirroringSupported { connection.isVideoMirrored = true }
        }

        session.commitConfiguration()
    }

    /// AVCaptureSession.startRunning() blocks until the session is actually running -
    /// but it was previously fired from a detached Task without being awaited, so the
    /// UI advanced to the camera-ready stage before the camera had actually started.
    /// That race is what showed up as "black screen, Stop does nothing": recording was
    /// started on a session that was not running yet.
    func startSession() async {
        guard !session.isRunning else { return }
        await Task.detached(priority: .userInitiated) { [session] in
            session.startRunning()
        }.value
    }

    func stopSession() {
        guard session.isRunning else { return }
        Task.detached(priority: .userInitiated) { [session] in
            session.stopRunning()
        }
    }

    func startRecording(onFinished: @escaping (URL) -> Void) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(UUID().uuidString)")
            .appendingPathExtension("mov")
        self.onFinished = onFinished
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        isPaused = false
    }

    /// Pause/resume of an in-progress recording is iOS 18+ only. On older systems the
    /// Pause button is hidden (see RecordView) and only Start/Stop are offered.
    var canPauseResume: Bool {
        if #available(iOS 18.0, *) { return true }
        return false
    }

    func pause() {
        guard movieOutput.isRecording else { return }
        if #available(iOS 18.0, *) {
            movieOutput.pauseRecording()
            isPaused = true
        }
    }

    func resume() {
        if #available(iOS 18.0, *) {
            movieOutput.resumeRecording()
            isPaused = false
        }
    }

    func stop() {
        movieOutput.stopRecording()
    }
}

extension CameraRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            isRecording = false
            isPaused = false
            if let error {
                errorMessage = error.localizedDescription
            } else {
                onFinished?(outputFileURL)
            }
        }
    }
}

/// UIKit bridge for the live camera preview layer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
