import XCTest
@testable import VideoCompressor

final class FFmpegCommandBuilderTests: XCTestCase {
    func test_compressionArguments_includesInputAndOutputPaths() {
        let command = FFmpegCommandBuilder.compressionArguments(
            inputPath: "/tmp/input.mov",
            outputPath: "/tmp/output.mp4",
            enhanceQuality: false
        )
        XCTAssertTrue(command.contains("-i \"/tmp/input.mov\""))
        XCTAssertTrue(command.hasSuffix("\"/tmp/output.mp4\""))
    }

    func test_compressionArguments_usesHardwareHEVCEncoder() {
        let command = FFmpegCommandBuilder.compressionArguments(
            inputPath: "/tmp/input.mov",
            outputPath: "/tmp/output.mp4",
            enhanceQuality: false
        )
        XCTAssertTrue(command.contains("-c:v hevc_videotoolbox"))
        XCTAssertTrue(command.contains("-b:v"))
        XCTAssertTrue(command.contains("-c:a copy"))
        XCTAssertTrue(command.contains("-tag:v hvc1"))
    }

    func test_compressionArguments_neverUsesFilterGraph() {
        // The ffmpeg-kit-spm "min" build has no libavfilter modules on device
        // (confirmed: "-vf hqdn3d..." fails with "No such filter: 'hqdn3d'").
        for enhanceQuality in [true, false] {
            let command = FFmpegCommandBuilder.compressionArguments(
                inputPath: "/tmp/input.mov",
                outputPath: "/tmp/output.mp4",
                enhanceQuality: enhanceQuality
            )
            XCTAssertFalse(command.contains("-vf"))
        }
    }

    func test_compressionArguments_withEnhance_usesHigherBitrate() {
        let plain = FFmpegCommandBuilder.compressionArguments(
            inputPath: "/tmp/input.mov",
            outputPath: "/tmp/output.mp4",
            enhanceQuality: false
        )
        let enhanced = FFmpegCommandBuilder.compressionArguments(
            inputPath: "/tmp/input.mov",
            outputPath: "/tmp/output.mp4",
            enhanceQuality: true
        )
        XCTAssertTrue(plain.contains("-b:v 6000k"))
        XCTAssertTrue(enhanced.contains("-b:v 10000k"))
    }
}
