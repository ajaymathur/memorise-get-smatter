import Testing

@testable import GetSmarter

/// Minimal engine whose round ends on the next tick with a chosen outcome.
struct StubEngine: GameEngine {
    let level: Int
    let pass: Bool
    var outcome: Outcome?

    mutating func advance(by dt: Duration) -> [Effect] {
        outcome = Outcome(score: level, accuracy: pass ? 1 : 0)
        return []
    }
}

struct TrainingRoundsTests {
    func make(level: Int, passes: @escaping @MainActor @Sendable (Int) -> Bool) -> TrainingRounds<StubEngine> {
        TrainingRounds(
            level: level, range: 1...6, window: .seconds(10), make: { StubEngine(level: $0, pass: passes($0)) },
            success: { $0.accuracy == 1 })
    }

    @Test func climbsAfterTwoSuccesses() {
        var t = make(level: 2) { _ in true }
        _ = t.advance(by: .seconds(1))
        #expect(t.staircase.level == 2 && t.current.level == 2)
        _ = t.advance(by: .seconds(1))
        #expect(t.staircase.level == 3 && t.current.level == 3)
    }

    @Test func convergesAndFinishesAfterWindow() {
        // Passes up to level 3, fails above: should hover around 3–4.
        var t = make(level: 1) { $0 <= 3 }
        while t.outcome == nil { _ = t.advance(by: .milliseconds(500)) }
        #expect((3...4).contains(t.outcome!.score))
        #expect(t.rounds == 20)
    }

    @Test func pairMatchSuccessRule() {
        let ok = TrainingPlan.success(.pairMatch)
        #expect(ok(Outcome(score: 0, accuracy: 0, stats: ["completed": 1, "extraMoves": 5, "pairs": 5])))
        #expect(!ok(Outcome(score: 0, accuracy: 0, stats: ["completed": 1, "extraMoves": 6, "pairs": 5])))
        #expect(!ok(Outcome(score: 0, accuracy: 0, stats: ["completed": 0, "extraMoves": 0, "pairs": 5])))
    }

    @Test func startLevelsWithinRange() {
        for game in GameKind.allCases {
            #expect(TrainingPlan.range(game).contains(TrainingPlan.startLevel(game)))
        }
    }
}
