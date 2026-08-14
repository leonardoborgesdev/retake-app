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

/// Segment length options offered on the Stories-split screen - kept to values that
/// map cleanly onto real Stories/Reels formats instead of an arbitrary free-typed number.
enum StorySegmentDuration: Int, CaseIterable, Identifiable {
    case fifteen = 15
    case thirty = 30
    case sixty = 60
    case ninety = 90

    var id: Int { rawValue }
    var label: String { "\(rawValue)s" }
}

enum FFmpegCommandBuilder {
    /// Uses the iPhone hardware HEVC encoder (VideoToolbox) instead of libx265: the
    /// ffmpeg-kit-spm build we ship is the GPL-free "min" variant, which does not include
    /// libx264/libx265. hevc_videotoolbox is also faster and more battery-efficient.
    static func compressionArguments(inputPath: String, outputPath: String, tier: CompressionTier) -> String {
        // -realtime is an AVOption compiled into the videotoolbox encoder itself (unlike
        // -vf filters, which are separate libavfilter modules this "min" build strips) -
        // it tells VideoToolbox to prefer the fastest path the iPhone's hardware media
        // engine has over its default balanced mode.
        "-y -i \"\(inputPath)\" -c:v hevc_videotoolbox -b:v \(tier.bitrateKbps)k -realtime 1 -c:a copy -tag:v hvc1 \"\(outputPath)\""
    }

    /// Rough size estimate shown before compressing: video bitrate over the source
    /// duration, plus a fixed allowance for the untouched audio track and container
    /// overhead. It is an estimate, not a guarantee - actual VBR output varies.
    static func estimatedOutputBytes(durationSeconds: Double, tier: CompressionTier) -> Int64 {
        let videoBytes = Double(tier.bitrateKbps) * 1000 / 8 * durationSeconds
        let audioAndOverheadBytes = 128.0 * 1000 / 8 * durationSeconds + 200_000
        return Int64(videoBytes + audioAndOverheadBytes)
    }

    /// Splits a video into fixed-length sequential pieces (e.g. one long take into a
    /// run of 60s Stories clips, in order) using ffmpeg's segment muxer. Stream-copies
    /// (`-c copy`) rather than re-encoding - much faster, and quality is untouched -
    /// so cuts land on the nearest keyframe rather than the exact second; fine for this
    /// use case, not frame-accurate like the retake cutter.
    static func segmentArguments(inputPath: String, outputPattern: String, segmentSeconds: Int) -> String {
        "-y -i \"\(inputPath)\" -c copy -map 0 -f segment -segment_time \(segmentSeconds) -reset_timestamps 1 \"\(outputPattern)\""
    }

    static func expectedSegmentCount(durationSeconds: Double, segmentSeconds: Int) -> Int {
        guard segmentSeconds > 0 else { return 0 }
        return max(1, Int((durationSeconds / Double(segmentSeconds)).rounded(.up)))
    }
}
