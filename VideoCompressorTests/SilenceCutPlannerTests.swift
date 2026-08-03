import XCTest
@testable import VideoCompressor

final class SilenceCutPlannerTests: XCTestCase {
    func test_buildCuts_ignoresGapsShorterThanThreshold() {
        let words = [
            TranscriptWord(text: "oi", start: 0.5, end: 0.8),
            TranscriptWord(text: "tudo", start: 1.0, end: 1.3),
        ]
        let intervals = [SilenceInterval(start: 0.0, end: 0.5)]
        let cuts = SilenceCutPlanner.buildCuts(words: words, duration: 2.0, intervals: intervals, thresh: 0.4, tailSafe: 0.07, lead: 0.18)
        XCTAssertTrue(cuts.allSatisfy { !($0.start >= 0.8 && $0.end <= 1.0) })
    }

    func test_buildCuts_cutsLeadingSilenceBeforeFirstWord() {
        let words = [TranscriptWord(text: "oi", start: 1.0, end: 1.3)]
        let intervals = [SilenceInterval(start: 0.0, end: 1.0)]
        let cuts = SilenceCutPlanner.buildCuts(words: words, duration: 2.0, intervals: intervals)
        XCTAssertEqual(cuts.first?.start, 0.0)
        XCTAssertEqual(cuts.first?.end ?? 0, 0.82, accuracy: 0.001)
    }

    func test_buildCuts_cutsMidGapLongerThanThreshold() {
        let words = [
            TranscriptWord(text: "oi", start: 0.0, end: 0.3),
            TranscriptWord(text: "tudo", start: 1.5, end: 1.8),
        ]
        let intervals = [SilenceInterval(start: 0.3, end: 1.5)]
        let cuts = SilenceCutPlanner.buildCuts(words: words, duration: 2.0, intervals: intervals, thresh: 0.4, tailSafe: 0.07, lead: 0.18)
        XCTAssertEqual(cuts, [CutRange(start: 0.37, end: 1.32)])
    }

    func test_buildCuts_cutsTrailingSilenceAfterLastWord() {
        let words = [TranscriptWord(text: "fim", start: 0.0, end: 0.5)]
        let intervals = [SilenceInterval(start: 0.5, end: 3.0)]
        let cuts = SilenceCutPlanner.buildCuts(words: words, duration: 3.0, intervals: intervals)
        XCTAssertEqual(cuts, [CutRange(start: 0.7, end: 3.0)])
    }

    func test_buildCuts_emptyWords_returnsEmpty() {
        let cuts = SilenceCutPlanner.buildCuts(words: [], duration: 3.0, intervals: [])
        XCTAssertTrue(cuts.isEmpty)
    }
}
