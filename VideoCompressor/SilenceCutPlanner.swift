import Foundation

struct TranscriptWord: Equatable {
    let text: String
    let start: Double
    let end: Double
}

struct SilenceInterval: Equatable {
    let start: Double
    let end: Double
}

struct CutRange: Equatable {
    let start: Double
    let end: Double
}

enum SilenceCutPlanner {
    static func findIntervalForGap(
        _ intervals: [SilenceInterval],
        gapStart: Double,
        gapEnd: Double,
        tolerance: Double = 0.3
    ) -> SilenceInterval? {
        let matched = intervals.filter { $0.start < gapEnd + tolerance && $0.end > gapStart - tolerance }
        guard !matched.isEmpty else { return nil }
        return SilenceInterval(start: matched.map(\.start).min()!, end: matched.map(\.end).max()!)
    }

    static func buildCuts(
        words: [TranscriptWord],
        duration: Double,
        intervals: [SilenceInterval],
        thresh: Double = 0.4,
        tailSafe: Double = 0.07,
        lead: Double = 0.18
    ) -> [CutRange] {
        guard !words.isEmpty else { return [] }
        var cuts: [CutRange] = []

        let firstWordStart = words[0].start
        if let leadIv = findIntervalForGap(intervals, gapStart: 0, gapEnd: firstWordStart) {
            let cutEnd = min(leadIv.end, firstWordStart) - lead
            if cutEnd > 0.2 {
                cuts.append(CutRange(start: 0.0, end: cutEnd))
            }
        }

        if words.count > 1 {
            for i in 0..<(words.count - 1) {
                let gs = words[i].end
                let ge = words[i + 1].start
                guard ge - gs > thresh else { continue }
                guard let iv = findIntervalForGap(intervals, gapStart: gs, gapEnd: ge) else { continue }
                let cutStart = iv.start + tailSafe
                let cutEnd = iv.end - lead
                if cutEnd - cutStart > 0.05 {
                    cuts.append(CutRange(start: cutStart, end: cutEnd))
                }
            }
        }

        let lastEnd = words[words.count - 1].end
        if let trailIv = findIntervalForGap(intervals, gapStart: lastEnd, gapEnd: duration) {
            let cutStart = max(trailIv.start + tailSafe, lastEnd + 0.2)
            if duration - cutStart > 0.1 {
                cuts.append(CutRange(start: cutStart, end: duration))
            }
        }

        return cuts.sorted { $0.start < $1.start }
    }
}
