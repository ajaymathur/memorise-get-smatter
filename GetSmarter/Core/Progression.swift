import Foundation

/// Tier unlocks, next-tier suggestions, and streaks, all derived from session history
/// so there is no mutable state to conflict across synced devices (design.md §4–5).
enum Progression {
    /// Score on `tier` needed to unlock (and be suggested) the next tier.
    static func threshold(_ game: GameKind, _ tier: Tier) -> Int {
        switch (game, tier) {
        case (.pairMatch, .beginner): 800
        case (.pairMatch, _): 900
        case (.sequenceEcho, .beginner): 500
        case (.sequenceEcho, _): 600
        case (.nBack, _), (.wordRecall, _): 700
        }
    }

    struct Entry: Sendable {
        var tier: Tier
        var score: Int
    }

    /// Ranked and relaxed sessions count toward unlocks; training does not.
    static func isUnlocked(_ tier: Tier, game: GameKind, history: [Entry], unlockAll: Bool) -> Bool {
        if unlockAll || tier == .beginner { return true }
        let previous: Tier = tier == .expert ? .advanced : .beginner
        let need = threshold(game, previous)
        return history.contains { $0.tier == previous && $0.score >= need }
    }

    /// Suggest the next tier after 3 qualifying scores, if it hasn't been played yet (REQ-GM-07).
    static func suggestion(game: GameKind, current: Tier, history: [Entry]) -> Tier? {
        guard let next = current.next, !history.contains(where: { $0.tier == next }) else { return nil }
        let need = threshold(game, current)
        let qualifying = history.filter { $0.tier == current && $0.score >= need }.count
        return qualifying >= 3 ? next : nil
    }

    /// Consecutive local days with a completed circuit, ending today or yesterday.
    static func streak(circuitDates: [Date], today: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(circuitDates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: today)
        if !days.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while days.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
}
