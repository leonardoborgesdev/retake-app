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

    func test_compressionArguments_usesHEVCWithConstantQuality() {
        let command = FFmpegCommandBuilder.compressionArguments(
            inputPath: "/tmp/input.mov",
            outputPath: "/tmp/output.mp4"
        )
        XCTAssertTrue(command.contains("-c:v libx265"))
        XCTAssertTrue(command.contains("-crf 23"))
        XCTAssertTrue(command.contains("-c:a copy"))
        XCTAssertTrue(command.contains("-tag:v hvc1"))
    }
}
