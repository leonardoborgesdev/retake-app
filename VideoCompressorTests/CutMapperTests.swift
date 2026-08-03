import XCTest
@testable import VideoCompressor

final class CutMapperTests: XCTestCase {
    func test_editedToOriginal_mapsTimeAfterACut() throws {
        let keep = [KeepSegment(start: 0.0, end: 1.0), KeepSegment(start: 2.0, end: 5.0)]
        let segments = CutMapper.buildMapping(keep: keep)
        let original = try CutMapper.editedToOriginal(segments, time: 1.5)
        XCTAssertEqual(original, 2.5, accuracy: 0.001)
    }

    func test_editedToOriginal_outOfRange_throws() {
        let keep = [KeepSegment(start: 0.0, end: 1.0)]
        let segments = CutMapper.buildMapping(keep: keep)
        XCTAssertThrowsError(try CutMapper.editedToOriginal(segments, time: 5.0))
    }

    func test_mergeCuts_appliesMarginAndSorts() {
        let existing = [CutRange(start: 10.0, end: 12.0)]
        let merged = CutMapper.mergeCuts(existing: existing, newCuts: [(start: 1.0, end: 2.0)], margin: 0.1)
        XCTAssertEqual(merged, [CutRange(start: 1.1, end: 1.9), CutRange(start: 10.0, end: 12.0)])
    }
}
