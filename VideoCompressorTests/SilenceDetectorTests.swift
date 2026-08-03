import XCTest
@testable import VideoCompressor

final class SilenceDetectorTests: XCTestCase {
    func test_parseLog_extractsStartEndPairsInOrder() {
        let log = """
        [silencedetect @ 0x1] silence_start: 1.234
        [silencedetect @ 0x1] silence_end: 2.345 | silence_duration: 1.111
        [silencedetect @ 0x1] silence_start: 5.0
        [silencedetect @ 0x1] silence_end: 5.5 | silence_duration: 0.5
        """
        let intervals = SilenceDetector.parseLog(log)
        XCTAssertEqual(intervals, [
            SilenceInterval(start: 1.234, end: 2.345),
            SilenceInterval(start: 5.0, end: 5.5),
        ])
    }

    func test_parseLog_noMatches_returnsEmpty() {
        XCTAssertTrue(SilenceDetector.parseLog("nothing here").isEmpty)
    }
}
