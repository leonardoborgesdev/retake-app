import Foundation

struct RetakeCandidate: Identifiable, Equatable {
    let id: Int
    let phrase: String
    /// Time range (seconds, in the EDITED video) of the first occurrence of the phrase.
    let firstRange: ClosedRange<Double>
    /// Time range (seconds, in the EDITED video) of the second, later occurrence.
    let secondRange: ClosedRange<Double>
}

enum RetakeCandidateFinder {
    /// Finds close repeated n-grams (3-5 words) in the edited transcript and reports the
    /// two candidate time windows so the user can pick which occurrence to keep. Only the
    /// first occurrence of each distinct phrase pairing is reported to avoid duplicate
    /// candidates when the same phrase repeats across multiple n-gram sizes.
    static func find(words: [TranscriptWord], proximity: Int = 30) -> [RetakeCandidate] {
        var cleanedTokens: [String] = []
        var sourceIndices: [Int] = []
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "%-"))
        for (index, word) in words.enumerated() {
            let cleaned = word.text.lowercased().unicodeScalars.filter { allowed.contains($0) }
            let result = String(String.UnicodeScalarView(cleaned))
            guard !result.isEmpty else { continue }
            cleanedTokens.append(result)
            sourceIndices.append(index)
        }

        var candidates: [RetakeCandidate] = []
        var reportedPairs = Set<String>()

        for n in [5, 4, 3] where cleanedTokens.count >= n {
            var seen: [String: [Int]] = [:]
            for i in 0...(cleanedTokens.count - n) {
                let gram = cleanedTokens[i..<(i + n)].joined(separator: " ")
                seen[gram, default: []].append(i)
            }
            for (gram, positions) in seen {
                for (a, b) in zip(positions, positions.dropFirst()) where b - a < proximity {
                    let pairKey = "\(gram)|\(a)|\(b)"
                    guard !reportedPairs.contains(pairKey) else { continue }
                    reportedPairs.insert(pairKey)

                    let firstStartIndex = sourceIndices[a]
                    let firstEndIndex = sourceIndices[a + n - 1]
                    let secondStartIndex = sourceIndices[b]
                    let secondEndIndex = sourceIndices[b + n - 1]

                    candidates.append(RetakeCandidate(
                        id: candidates.count,
                        phrase: gram,
                        firstRange: words[firstStartIndex].start...words[firstEndIndex].end,
                        secondRange: words[secondStartIndex].start...words[secondEndIndex].end
                    ))
                }
            }
        }

        return candidates
    }
}
