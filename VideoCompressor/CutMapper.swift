import Foundation

enum CutMapper {
    struct TimelineSegment: Equatable {
        let editedStart: Double
        let editedEnd: Double
        let originalStart: Double
    }

    enum MappingError: Error {
        case outOfRange(Double)
    }

    static func buildMapping(keep: [KeepSegment]) -> [TimelineSegment] {
        var segments: [TimelineSegment] = []
        var outTime = 0.0
        for segment in keep {
            let length = segment.end - segment.start
            segments.append(TimelineSegment(editedStart: outTime, editedEnd: outTime + length, originalStart: segment.start))
            outTime += length
        }
        return segments
    }

    static func editedToOriginal(_ segments: [TimelineSegment], time: Double) throws -> Double {
        for segment in segments where segment.editedStart - 1e-6 <= time && time <= segment.editedEnd + 1e-6 {
            return segment.originalStart + (time - segment.editedStart)
        }
        throw MappingError.outOfRange(time)
    }

    /// Merges new cut ranges (already in ORIGINAL-source time, e.g. found by re-transcription
    /// QA after mapping back with `editedToOriginal`) into an existing cut plan. `margin` shrinks
    /// each new cut inward so a slightly-early/late boundary doesn't clip a word worth keeping.
    static func mergeCuts(existing: [CutRange], newCuts: [(start: Double, end: Double)], margin: Double = 0.06) -> [CutRange] {
        let adjustedNew = newCuts.map { CutRange(start: $0.start + margin, end: $0.end - margin) }
        return (existing + adjustedNew).sorted { $0.start < $1.start }
    }
}
