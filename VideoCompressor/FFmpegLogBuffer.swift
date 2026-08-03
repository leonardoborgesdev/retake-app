import Foundation

/// Thread-safe accumulator for ffmpeg log lines. FFmpegKit's log callback can be invoked
/// from a background queue for every log line while the complete callback fires once at
/// the end; both must be able to touch this buffer safely.
final class FFmpegLogBuffer: @unchecked Sendable {
    private var lines: [String] = []
    private let lock = NSLock()

    func append(_ line: String) {
        lock.lock()
        lines.append(line)
        lock.unlock()
    }

    func joinedText() -> String {
        lock.lock()
        defer { lock.unlock() }
        return lines.joined(separator: "\n")
    }

    func lastLines(_ count: Int) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard !lines.isEmpty else { return nil }
        return lines.suffix(count).joined(separator: "\n")
    }
}
