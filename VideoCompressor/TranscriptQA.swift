import Foundation

struct QAIssue: Equatable {
    enum Kind: Equatable {
        case truncationMarker
        case anomalousDuration
        case adjacentDuplicate
        case closeRepeatedNGram
    }

    let kind: Kind
    let message: String
}

enum TranscriptQA {
    static func cleanWords(_ words: [TranscriptWord]) -> [String] {
        words.compactMap { word -> String? in
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "%-"))
            let cleaned = word.text.lowercased().unicodeScalars.filter { allowed.contains($0) }
            let result = String(String.UnicodeScalarView(cleaned))
            return result.isEmpty ? nil : result
        }
    }

    static func findIssues(
        words: [TranscriptWord],
        proximity: Int = 30,
        durationThreshold: Double = 1.5,
        shortDurationThreshold: Double = 0.9,
        shortWordLength: Int = 5
    ) -> [QAIssue] {
        var issues: [QAIssue] = []

        for word in words where word.text.contains("...") {
            issues.append(QAIssue(
                kind: .truncationMarker,
                message: "\(formatted(word.start))s  \"\(word.text)\""
            ))
        }

        for word in words {
            let dur = word.end - word.start
            let core = word.text.filter { $0.isLetter }
            let isShortAlpha = !core.isEmpty && core.count <= shortWordLength
            if dur > durationThreshold || (isShortAlpha && dur > shortDurationThreshold) {
                issues.append(QAIssue(
                    kind: .anomalousDuration,
                    message: "\(formatted(word.start))s-\(formatted(word.end))s (\(formatted(dur))s)  \"\(word.text)\" — provável retake embutido nesse timing"
                ))
            }
        }

        let cleaned = cleanWords(words)

        if cleaned.count > 1 {
            for i in 0..<(cleaned.count - 1) where cleaned[i] == cleaned[i + 1] {
                issues.append(QAIssue(kind: .adjacentDuplicate, message: "palavra \(i): \"\(cleaned[i])\""))
            }
        }

        for n in [3, 4, 5] where cleaned.count >= n {
            var seen: [String: [Int]] = [:]
            for i in 0...(cleaned.count - n) {
                let gram = cleaned[i..<(i + n)].joined(separator: "\u{0}")
                seen[gram, default: []].append(i)
            }
            for (gram, indices) in seen {
                for (a, b) in zip(indices, indices.dropFirst()) where b - a < proximity {
                    let readable = gram.replacingOccurrences(of: "\u{0}", with: " ")
                    issues.append(QAIssue(
                        kind: .closeRepeatedNGram,
                        message: "\(readable) nos índices \(a),\(b) (distância \(b - a))"
                    ))
                }
            }
        }

        return issues
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
