import XCTest
@testable import VideoCompressor

final class FFmpegCommandBuilderTests: XCTestCase {
    func test_compressionArguments_includesInputAndOutputPaths() {
        let command = FFmpegCommandBuilder.compressionArguments(
            inputPath: "/tmp/input.mov",
            outputPath: "/tmp/output.mp4"
        )
        XCTAssertTrue(command.contains("-i \"/tmp/input.mov\""))
        XCTAssertTrue(command.hasSuffix("\"/tmp/output.mp4\""))
    }

    func test_compressionArguments_usesHardwareHEVCEncoder() {
        let command = FFmpegCommandBuilder.compressionArguments(
            inputPath: "/tmp/input.mov",
            outputPath: "/tmp/output.mp4"
        )
        XCTAssertTrue(command.contains("-c:v hevc_videotoolbox"))
        XCTAssertTrue(command.contains("-b:v"))
        XCTAssertTrue(command.contains("-c:a copy"))
        XCTAssertTrue(command.contains("-tag:v hvc1"))
    }
}
