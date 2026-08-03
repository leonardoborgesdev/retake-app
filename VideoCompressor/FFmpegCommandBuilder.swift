import Foundation

enum FFmpegCommandBuilder {
    /// Uses the iPhone's hardware HEVC encoder (VideoToolbox) instead of libx265: the
    /// ffmpeg-kit-spm build we ship is the GPL-free "min" variant, which does not include
    /// libx264/libx265. hevc_videotoolbox is also faster and more battery-efficient.
    static func compressionArguments(inputPath: String, outputPath: String) -> String {
        "-y -i \"\(inputPath)\" -c:v hevc_videotoolbox -b:v 6000k -c:a copy -tag:v hvc1 \"\(outputPath)\""
    }
}
