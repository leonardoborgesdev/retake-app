import Foundation

enum ByteFormatting {
    static func humanReadableSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 KB" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }

    static func savingsPercentage(originalBytes: Int64, compressedBytes: Int64) -> Int {
        guard originalBytes > 0 else { return 0 }
        let saved = originalBytes - compressedBytes
        let percentage = (Double(saved) / Double(originalBytes)) * 100
        return Int(percentage.rounded())
    }
}
