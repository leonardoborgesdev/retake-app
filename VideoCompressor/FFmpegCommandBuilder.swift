import Foundation

enum CompressionTier: String, CaseIterable, Identifiable {
    case small
    case balanced
    case best

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: return "Small"
        case .balanced: return "Balanced"
        case .best: return "Best quality"
        }
    }

    /// The ffmpeg-kit-spm "min" build has no libavfilter modules on device (confirmed:
    /// "-vf scale=..." and "-vf hqdn3d..." both fail with "No such filter"), so real
    /// resolution downscaling (720p/1080p) is not reliably available here. Bitrate is
    /// the one lever that is guaranteed to work - encoder-level flags, no filtergraph.
    var bitrateKbps: Int {
        switch self {
        case .small: return 2500
        case .balanced: return 6000
        case .best: return 10000
        }
    }
}

enum FFmpegCommandBuilder {
    /// Uses the iPhone hardware HEVC encoder (VideoToolbox) instead of libx265: the
    /// ffmpeg-kit-spm build we ship is the GPL-free "min" variant, which does not include
    /// libx264/libx265. hevc_videotoolbox is also faster and more battery-efficient.
    static func compressionArguments(inputPath: String, outputPath: String, tier: CompressionTier) -> String {
        "-y -i \"\(inputPath)\" -c:v hevc_videotoolbox -b:v \(tier.bitrateKbps)k -c:a copy -tag:v hvc1 \"\(outputPath)\""
    }

    /// Rough size estimate shown before compressing: video bitrate over the source
    /// duration, plus a fixed allowance for the untouched audio track and container
    /// overhead. It is an estimate, not a guarantee - actual VBR output varies.
    static func estimatedOutputBytes(durationSeconds: Double, tier: CompressionTier) -> Int64 {
        let videoBytes = Double(tier.bitrateKbps) * 1000 / 8 * durationSeconds
        let audioAndOverheadBytes = 128.0 * 1000 / 8 * durationSeconds + 200_000
        return Int64(videoBytes + audioAndOverheadBytes)
    }
}
