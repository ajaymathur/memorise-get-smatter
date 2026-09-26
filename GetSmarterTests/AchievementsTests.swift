import Foundation
import Testing

@testable import GetSmarter

struct AchievementsTests {
    typealias P = Achievements.Played

    @Test func emptyHistoryEarnsNothing() {
        #expect(Achievements.earned(history: [], latest: nil, trainingLevels: [:]).isEmpty)
    }

    @Test func firstAndAllGames() {
        let one = [P(game: .nBack, tier: .beginner, score: 10)]
        #expect(Achievements.earned(history: one, latest: nil, trainingLevels: [:]) == ["ach.first_game"])
        let all = GameKind.allCases.map { P(game: $0, tier: .beginner, score: 10) }
        #expect(Achievements.earned(history: all, latest: nil, trainingLevels: [:]).contains("ach.all_games"))
    }

    @Test func streaks() {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 9))!
        let days = (0..<7).map {
            P(game: .nBack, tier: nil, score: 1, circuitDate: cal.date(byAdding: .day, value: -$0, to: today))
        }
        let ids = Achievements.earned(history: days, latest: nil, trainingLevels: [:], today: today, calendar: cal)
        #expect(ids.isSuperset(of: ["ach.streak_3", "ach.streak_7"]))
        #expect(!ids.contains("ach.streak_30"))
    }

    @Test func expertNeedsEarnedUnlock() {
        let h = [P(game: .nBack, tier: .advanced, score: 700)]
        #expect(Achievements.earned(history: h, latest: nil, trainingLevels: [:]).contains("ach.expert"))
        let low = [P(game: .nBack, tier: .advanced, score: 699)]
        #expect(!Achievements.earned(history: low, latest: nil, trainingLevels: [:]).contains("ach.expert"))
    }

    @Test func outcomeBased() {
        func ids(_ game: GameKind, _ tier: Tier, _ score: Int, _ stats: [String: Int]) -> Set<String> {
            Achievements.earned(
                history: [],
                latest: .init(game: game, tier: tier, outcome: Outcome(score: score, accuracy: 1, stats: stats)),
                trainingLevels: [:])
        }
        #expect(ids(.pairMatch, .beginner, 900, ["completed": 1, "extraMoves": 0]) == ["ach.perfect_pairs"])
        #expect(ids(.pairMatch, .beginner, 900, ["completed": 0, "extraMoves": 0]).isEmpty)
        #expect(ids(.sequenceEcho, .advanced, 700, ["maxSpan": 7]) == ["ach.span_7"])
        #expect(ids(.wordRecall, .advanced, 800, ["luresPicked": 0]) == ["ach.lure_proof"])
        #expect(ids(.wordRecall, .beginner, 800, ["luresPicked": 0]).isEmpty)
        #expect(ids(.wordRecall, .expert, 0, ["luresPicked": 0]).isEmpty)
    }

    @Test func nBackTrainingLevel() {
        #expect(Achievements.earned(history: [], latest: nil, trainingLevels: [.nBack: 3]) == ["ach.nback_3"])
    }
}

struct LeaderboardIDTests {
    @Test func idsMatchDesign() {
        #expect(GameCenterService.leaderboardID(.nBack, .expert, weekly: false) == "lb.nback.expert.alltime")
        #expect(GameCenterService.leaderboardID(.pairMatch, .beginner, weekly: true) == "lb.pairmatch.beginner.weekly")
        let all = GameKind.allCases.flatMap { g in
            Tier.allCases.flatMap { t in [true, false].map { GameCenterService.leaderboardID(g, t, weekly: $0) } }
        }
        #expect(Set(all).count == 24)
    }
}
