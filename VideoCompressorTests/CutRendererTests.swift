import XCTest
@testable import VideoCompressor

final class CutRendererTests: XCTestCase {
    func test_buildKeepSegments_singleMidCut_producesTwoSegments() {
        let cuts = [CutRange(start: 1.0, end: 2.0)]
        let keep = CutRenderer.buildKeepSegments(duration: 5.0, cuts: cuts, fps: nil)
        XCTAssertEqual(keep, [KeepSegment(start: 0.0, end: 1.0), KeepSegment(start: 2.0, end: 5.0)])
    }

    func test_buildKeepSegments_cutAtStart_producesOneSegment() {
        let cuts = [CutRange(start: 0.0, end: 1.0)]
        let keep = CutRenderer.buildKeepSegments(duration: 5.0, cuts: cuts, fps: nil)
        XCTAssertEqual(keep, [KeepSegment(start: 1.0, end: 5.0)])
    }

    func test_buildKeepSegments_noCuts_returnsFullDuration() {
        let keep = CutRenderer.buildKeepSegments(duration: 5.0, cuts: [], fps: nil)
        XCTAssertEqual(keep, [KeepSegment(start: 0.0, end: 5.0)])
    }

    func test_snap_roundsToNearestFrame() {
        let snapped = CutRenderer.snap(1.005, fps: 30)
        XCTAssertEqual(snapped, 1.0, accuracy: 0.001)
    }

    func test_buildFilterGraph_producesTrimAndConcatForEachSegment() {
        let keep = [KeepSegment(start: 0.0, end: 1.0), KeepSegment(start: 2.0, end: 5.0)]
        let graph = CutRenderer.buildFilterGraph(keep: keep)
        XCTAssertTrue(graph.contains("[0:v]trim=start=0.000:end=1.000,setpts=PTS-STARTPTS[v0];"))
        XCTAssertTrue(graph.contains("[0:a]atrim=start=2.000:end=5.000,asetpts=PTS-STARTPTS[a1];"))
        XCTAssertTrue(graph.hasSuffix("[v0][a0][v1][a1]concat=n=2:v=1:a=1[outv][outa]"))
    }
}
