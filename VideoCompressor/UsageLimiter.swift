import Foundation

/// Tracks the free tier's shared daily allowance for Compress + Cut (Find Duplicates and
/// Split for Stories aren't part of this pool - they're subscriber-only outright). Keyed
/// by calendar date, so it resets on its own with no explicit reset job: yesterday's key
/// is simply never read again.
@MainActor
final class UsageLimiter: ObservableObject {
    static let shared = UsageLimiter()
    static let dailyFreeLimit = 10

    @Published private(set) var usedToday: Int

    private let defaults = UserDefaults.standard

    private init() {
        usedToday = defaults.integer(forKey: Self.todayKey())
    }

    var remainingToday: Int { max(0, Self.dailyFreeLimit - usedToday) }

    func canUse(count: Int = 1) -> Bool {
        remainingToday >= count
    }

    func recordUsage(count: Int = 1) {
        usedToday += count
        defaults.set(usedToday, forKey: Self.todayKey())
    }

    private static func todayKey(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return "usageCount-\(formatter.string(from: date))"
    }
}
