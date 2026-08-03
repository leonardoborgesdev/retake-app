import Foundation

struct KeepSegment: Equatable {
    let start: Double
    let end: Double
}

enum CutRenderer {
    /// Rounds a timestamp to the nearest exact frame boundary at `fps`. ffmpeg's `trim`
    /// filter snaps video cuts to the nearest frame while `atrim` cuts audio sample-accurately;
    /// snapping every cut boundary first keeps them in sync and avoids A/V drift.
    static func snap(_ time: Double, fps: Double) -> Double {
        (time * fps).rounded() / fps
    }

    static func buildKeepSegments(duration: Double, cuts: [CutRange], fps: Double?) -> [KeepSegment] {
        var keep: [KeepSegment] = []
        var prev = 0.0
        for cut in cuts.sorted(by: { $0.start < $1.start }) {
            var cs = cut.start
            var ce = cut.end
            if let fps {
                cs = snap(cs, fps: fps)
                ce = snap(ce, fps: fps)
            }
            if cs > prev {
                keep.append(KeepSegment(start: prev, end: cs))
            }
            prev = max(prev, ce)
        }
        if prev < duration {
            keep.append(KeepSegment(start: prev, end: duration))
        }
        return keep
    }

    static func buildFilterGraph(keep: [KeepSegment]) -> String {
        var lines: [String] = []
        var concatInputs = ""
        for (i, segment) in keep.enumerated() {
            lines.append(String(format: "[0:v]trim=start=%.3f:end=%.3f,setpts=PTS-STARTPTS[v%d];", segment.start, segment.end, i))
            lines.append(String(format: "[0:a]atrim=start=%.3f:end=%.3f,asetpts=PTS-STARTPTS[a%d];", segment.start, segment.end, i))
            concatInputs += "[v\(i)][a\(i)]"
        }
        lines.append("\(concatInputs)concat=n=\(keep.count):v=1:a=1[outv][outa]")
        return lines.joined(separator: "\n")
    }
}
