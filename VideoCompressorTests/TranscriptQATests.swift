import XCTest
@testable import VideoCompressor

final class TranscriptQATests: XCTestCase {
    func test_findIssues_flagsTruncationMarker() {
        let words = [TranscriptWord(text: "pal...", start: 1.0, end: 1.2)]
        let issues = TranscriptQA.findIssues(words: words)
        XCTAssertTrue(issues.contains { $0.kind == .truncationMarker })
    }

    func test_findIssues_flagsAdjacentDuplicateWords() {
        let words = [
            TranscriptWord(text: "muito", start: 0.0, end: 0.3),
            TranscriptWord(text: "muito", start: 0.3, end: 0.6),
            TranscriptWord(text: "bem", start: 0.6, end: 0.9),
        ]
        let issues = TranscriptQA.findIssues(words: words)
        XCTAssertTrue(issues.contains { $0.kind == .adjacentDuplicate })
    }

    func test_findIssues_flagsAnomalousLongShortWord() {
        let words = [TranscriptWord(text: "de", start: 0.0, end: 1.6)]
        let issues = TranscriptQA.findIssues(words: words)
        XCTAssertTrue(issues.contains { $0.kind == .anomalousDuration })
    }

    func test_findIssues_flagsCloseRepeatedNGram() {
        let phrase = ["eu", "acho", "que", "sim"]
        var words: [TranscriptWord] = []
        var t = 0.0
        for _ in 0..<2 {
            for token in phrase {
                words.append(TranscriptWord(text: token, start: t, end: t + 0.2))
                t += 0.3
            }
        }
        let issues = TranscriptQA.findIssues(words: words, proximity: 30)
        XCTAssertTrue(issues.contains { $0.kind == .closeRepeatedNGram })
    }

    func test_findIssues_cleanTranscript_returnsNoIssues() {
        let words = [
            TranscriptWord(text: "hoje", start: 0.0, end: 0.3),
            TranscriptWord(text: "vamos", start: 0.3, end: 0.6),
            TranscriptWord(text: "falar", start: 0.6, end: 0.9),
        ]
        let issues = TranscriptQA.findIssues(words: words)
        XCTAssertTrue(issues.isEmpty)
    }
}
