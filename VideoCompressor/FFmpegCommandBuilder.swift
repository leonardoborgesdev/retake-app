import Foundation

enum FFmpegCommandBuilder {
    /// Uses the iPhone hardware HEVC encoder (VideoToolbox) instead of libx265: the
    /// ffmpeg-kit-spm build we ship is the GPL-free "min" variant, which does not include
    /// libx264/libx265. hevc_videotoolbox is also faster and more battery-efficient.
    ///
    /// This same "min" build also excludes most libavfilter modules (confirmed on-device:
    /// "-vf hqdn3d..." fails with "No such filter: 'hqdn3d'" and aborts the whole encode).
    /// So `enhanceQuality` cannot use a denoise/sharpen filter pass - instead it raises the
    /// target bitrate, which only touches encoder flags this build already supports.
    static func compressionArguments(inputPath: String, outputPath: String, enhanceQuality: Bool) -> String {
        let bitrate = enhanceQuality ? "10000k" : "6000k"
        return "-y -i \"\(inputPath)\" -c:v hevc_videotoolbox -b:v \(bitrate) -c:a copy -tag:v hvc1 \"\(outputPath)\""
    }
}
