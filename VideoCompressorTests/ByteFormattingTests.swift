import XCTest
@testable import VideoCompressor

final class ByteFormattingTests: XCTestCase {
    func test_savingsPercentage_halvedFile_returns50() {
        let result = ByteFormatting.savingsPercentage(originalBytes: 100_000_000, compressedBytes: 50_000_000)
        XCTAssertEqual(result, 50)
    }

    func test_savingsPercentage_noChange_returnsZero() {
        let result = ByteFormatting.savingsPercentage(originalBytes: 100_000_000, compressedBytes: 100_000_000)
        XCTAssertEqual(result, 0)
    }

    func test_savingsPercentage_zeroOriginal_returnsZero() {
        let result = ByteFormatting.savingsPercentage(originalBytes: 0, compressedBytes: 0)
        XCTAssertEqual(result, 0)
    }

    func test_humanReadableSize_producesNonEmptyString() {
        let result = ByteFormatting.humanReadableSize(50_000_000)
        XCTAssertFalse(result.isEmpty)
    }
}
