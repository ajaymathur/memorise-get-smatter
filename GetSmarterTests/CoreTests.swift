import Foundation
import Testing

@testable import GetSmarter

struct SeededRNGTests {
    @Test func sameSeedSameSequence() {
        var a = SeededRNG(seed: 42)
        var b = SeededRNG(seed: 42)
        #expect((0..<10).map { _ in a.next() } == (0..<10).map { _ in b.next() })
    }

    @Test func differentSeedsDiffer() {
        var a = SeededRNG(seed: 1)
        var b = SeededRNG(seed: 2)
        #expect(a.next() != b.next())
    }
}

struct ProgressionTests {
    typealias E = Progression.Entry

    @Test func beginnerAlwaysUnlocked() {
        #expect(Progression.isUnlocked(.beginner, game: .nBack, history: [], unlockAll: false))
    }

    @Test func advancedNeedsBeginnerThreshold() {
        let below = [E(tier: .beginner, score: 699)]
        let at = [E(tier: .beginner, score: 700)]
        #expect(!Progression.isUnlocked(.advanced, game: .nBack, history: below, unlockAll: false))
        #expect(Progression.isUnlocked(.advanced, game: .nBack, history: at, unlockAll: false))
    }

    @Test func expertNeedsAdvancedNotBeginner() {
        let history = [E(tier: .beginner, score: 1000)]
        #expect(!Progression.isUnlocked(.expert, game: .pairMatch, history: history, unlockAll: false))
        #expect(
            Progression.isUnlocked(
                .expert, game: .pairMatch, history: history + [E(tier: .advanced, score: 900)], unlockAll: false))
    }

    @Test func unlockAllBypasses() {
        #expect(Progression.isUnlocked(.expert, game: .wordRecall, history: [], unlockAll: true))
    }

    @Test func suggestsAfterThreeQualifyingScores() {
        let two = Array(repeating: E(tier: .beginner, score: 600), count: 2)
        #expect(Progression.suggestion(game: .sequenceEcho, current: .beginner, history: two) == nil)
        let three = two + [E(tier: .beginner, score: 500)]
        #expect(Progression.suggestion(game: .sequenceEcho, current: .beginner, history: three) == .advanced)
        let played = three + [E(tier: .advanced, score: 100)]
        #expect(Progression.suggestion(game: .sequenceEcho, current: .beginner, history: played) == nil)
        #expect(Progression.suggestion(game: .sequenceEcho, current: .expert, history: three) == nil)
    }

    @Test func streakCountsConsecutiveDays() {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 10))!
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: -offset, to: today)! }

        #expect(Progression.streak(circuitDates: [], today: today, calendar: cal) == 0)
        #expect(Progression.streak(circuitDates: [day(0), day(1), day(2)], today: today, calendar: cal) == 3)
        // Not yet played today: streak through yesterday still counts.
        #expect(Progression.streak(circuitDates: [day(1), day(2)], today: today, calendar: cal) == 2)
        // Gap breaks it; duplicates on one day count once.
        #expect(Progression.streak(circuitDates: [day(0), day(0), day(2)], today: today, calendar: cal) == 1)
    }
}

struct StaircaseTests {
    @Test func twoDownOneUp() {
        var s = Staircase(level: 3, range: 1...5)
        s.record(success: true)
        #expect(s.level == 3)
        s.record(success: true)
        #expect(s.level == 4)
        s.record(success: false)
        #expect(s.level == 3)
        // Failure resets the success streak.
        s.record(success: true)
        s.record(success: false)
        s.record(success: true)
        #expect(s.level == 2)
    }

    @Test func clampsToRange() {
        var s = Staircase(level: 99, range: 1...5)
        #expect(s.level == 5)
        s.record(success: true)
        s.record(success: true)
        #expect(s.level == 5)
        var low = Staircase(level: 1, range: 1...5)
        low.record(success: false)
        #expect(low.level == 1)
    }
}
