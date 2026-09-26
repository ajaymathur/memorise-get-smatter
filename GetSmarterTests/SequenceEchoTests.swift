import Testing

@testable import GetSmarter

struct SequenceEchoTests {
    func make(_ config: SequenceEchoEngine.Config, seed: UInt64 = 3) -> SequenceEchoEngine {
        SequenceEchoEngine(config: config, rng: SeededRNG(seed: seed))
    }

    /// Runs playback to the input phase.
    func play(_ e: inout SequenceEchoEngine) {
        while e.phase != .input && e.phase != .finished { _ = e.advance(by: .milliseconds(50)) }
    }

    /// Enters the right answer (or a wrong first tile).
    func answer(_ e: inout SequenceEchoEngine, correct: Bool) {
        play(&e)
        let target = e.config.backward ? Array(e.sequence.reversed()) : e.sequence
        if correct {
            target.forEach { _ = e.tap($0) }
        } else {
            _ = e.tap((target[0] + 1) % e.config.tiles)
        }
        _ = e.advance(by: SequenceEchoEngine.feedbackDuration)
    }

    @Test(arguments: [(Tier.beginner, 4, 2), (.advanced, 9, 3), (.expert, 16, 4)])
    func tierParams(tier: Tier, tiles: Int, span: Int) {
        let e = make(.tier(tier))
        #expect(e.config.tiles == tiles)
        #expect(e.sequence.count == span)
        #expect(e.config.backward == (tier == .expert))
    }

    @Test func noImmediateRepeats() {
        for seed in 0..<50 as Range<UInt64> {
            let s = make(.tier(.beginner), seed: seed).sequence
            #expect(zip(s, s.dropFirst()).allSatisfy { $0 != $1 })
        }
    }

    @Test func tapsIgnoredDuringPlayback() {
        var e = make(.tier(.advanced))
        #expect(e.tap(0).isEmpty)
        #expect(e.entered.isEmpty)
    }

    @Test func playbackLightsEachItem() {
        var e = make(.tier(.advanced))
        var lit: [Int] = []
        while e.phase != .input {
            _ = e.advance(by: .milliseconds(10))
            if let t = e.litTile, lit.last != t { lit.append(t) }
        }
        #expect(lit == e.sequence)
    }

    @Test func advancesIfEitherTrialCorrectStopsWhenBothFail() {
        var e = make(.tier(.beginner))
        answer(&e, correct: false)
        #expect(e.span == 2 && e.trialInSpan == 1)
        answer(&e, correct: true)
        #expect(e.span == 3)
        answer(&e, correct: true)
        answer(&e, correct: true)
        #expect(e.span == 4)
        answer(&e, correct: false)
        answer(&e, correct: false)
        #expect(e.phase == .finished)
        // Longest 3, one perfect span (3) → 300 + 25.
        #expect(e.outcome?.score == 325)
        #expect(e.outcome?.stats["maxSpan"] == 3)
    }

    @Test func expertRequiresReverseOrder() {
        var e = make(.tier(.expert))
        play(&e)
        let forward = e.sequence
        _ = e.tap(forward[0])
        // First forward tile is wrong unless it equals the last tile.
        if forward[0] != forward.last {
            #expect(e.trials == 1 && e.correctTrials == 0)
        }
    }

    @Test func trainingSingleTrialFinishes() {
        var e = make(.training(span: 5))
        #expect(e.sequence.count == 5)
        answer(&e, correct: true)
        #expect(e.phase == .finished)
        #expect(e.outcome?.accuracy == 1)
    }

    @Test func resumeReplaysCurrentItemOnly() {
        var e = make(.tier(.advanced))
        while e.litTile == nil { _ = e.advance(by: .milliseconds(10)) }
        _ = e.advance(by: .milliseconds(300))
        e.resumeFromPause()
        #expect(e.phase == .playback(index: 0, lit: false, remaining: e.config.gap))
    }
}
