import XCTest
@testable import VideoCompressor

final class FFmpegCommandBuilderTests: XCTestCase {
    func test_compressionArguments_includesInputAndOutputPaths() {
        let command = FFmpegCommandBuilder.compressionArguments(
            inputPath: "/tmp/input.mov",
            outputPath: "/tmp/output.mp4",
            tier: .balanced
        )
        XCTAssertTrue(command.contains("-i \"/tmp/input.mov\""))
        XCTAssertTrue(command.hasSuffix("\"/tmp/output.mp4\""))
    }

    func test_compressionArguments_usesHardwareHEVCEncoder() {
        let command = FFmpegCommandBuilder.compressionArguments(
            inputPath: "/tmp/input.mov",
            outputPath: "/tmp/output.mp4",
            tier: .balanced
        )
        XCTAssertTrue(command.contains("-c:v hevc_videotoolbox"))
        XCTAssertTrue(command.contains("-b:v"))
        XCTAssertTrue(command.contains("-c:a copy"))
        XCTAssertTrue(command.contains("-tag:v hvc1"))
    }

    func test_compressionArguments_requestsFastestEncoderPath() {
        // -realtime is a videotoolbox encoder AVOption (compiled in, not a filter
        // module), unlike hqdn3d/unsharp/scale which crashed this app before.
        let command = FFmpegCommandBuilder.compressionArguments(
            inputPath: "/tmp/input.mov",
            outputPath: "/tmp/output.mp4",
            tier: .balanced
        )
        XCTAssertTrue(command.contains("-realtime 1"))
    }

    func test_compressionArguments_neverUsesFilterGraph() {
        // The ffmpeg-kit-spm "min" build has no libavfilter modules on device
        // (confirmed: "-vf hqdn3d..." and "-vf scale=..." both fail with
        // "No such filter").
        for tier in CompressionTier.allCases {
            let command = FFmpegCommandBuilder.compressionArguments(
                inputPath: "/tmp/input.mov",
                outputPath: "/tmp/output.mp4",
                tier: tier
            )
            XCTAssertFalse(command.contains("-vf"))
        }
    }

    func test_compressionArguments_tiersUseIncreasingBitrate() {
        let small = FFmpegCommandBuilder.compressionArguments(inputPath: "/tmp/i.mov", outputPath: "/tmp/o.mp4", tier: .small)
        let balanced = FFmpegCommandBuilder.compressionArguments(inputPath: "/tmp/i.mov", outputPath: "/tmp/o.mp4", tier: .balanced)
        let best = FFmpegCommandBuilder.compressionArguments(inputPath: "/tmp/i.mov", outputPath: "/tmp/o.mp4", tier: .best)
        XCTAssertTrue(small.contains("-b:v 2500k"))
        XCTAssertTrue(balanced.contains("-b:v 6000k"))
        XCTAssertTrue(best.contains("-b:v 10000k"))
    }

    func test_estimatedOutputBytes_scalesWithDurationAndTier() {
        let shortSmall = FFmpegCommandBuilder.estimatedOutputBytes(durationSeconds: 10, tier: .small)
        let longSmall = FFmpegCommandBuilder.estimatedOutputBytes(durationSeconds: 100, tier: .small)
        let shortBest = FFmpegCommandBuilder.estimatedOutputBytes(durationSeconds: 10, tier: .best)
        XCTAssertLessThan(shortSmall, longSmall)
        XCTAssertLessThan(shortSmall, shortBest)
    }
}
