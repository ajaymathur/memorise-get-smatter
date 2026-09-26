import Testing

@testable import GetSmarter

struct NBackTests {
    func make(_ config: NBackEngine.Config, seed: UInt64 = 11) -> NBackEngine {
        var rng = SeededRNG(seed: seed)
        return NBackEngine(config: config, rng: &rng)
    }

    /// Plays the whole game; `answer(engine, i, modality)` decides whether to respond on trial i.
    func run(_ e: inout NBackEngine, answer: (NBackEngine, Int, NBackEngine.Modality) -> Bool) {
        _ = e.advance(by: e.config.leadIn)
        while e.outcome == nil {
            let i = e.index
            _ = e.advance(by: .milliseconds(100))
            if answer(e, i, .position) { _ = e.respond(.position) }
            if e.config.dual, answer(e, i, .sound) { _ = e.respond(.sound) }
            _ = e.advance(by: e.config.trial)
        }
    }

    @Test(arguments: [(Tier.beginner, 1, false, 21), (.advanced, 2, false, 22), (.expert, 2, true, 22)])
    func tierParams(tier: Tier, n: Int, dual: Bool, trials: Int) {
        let e = make(.tier(tier))
        #expect(e.config.n == n && e.config.dual == dual && e.config.trials == trials)
        #expect(e.cells.count == trials)
        #expect(e.letterIndices.count == (dual ? trials : 0))
        #expect(e.config.stimulus == .milliseconds(500) && e.config.trial == .seconds(3))
    }

    @Test func centreNeverUsed() {
        #expect(!make(.tier(.advanced)).cells.contains(4))
    }

    @Test func targetRateNearThirty() {
        var rng = SeededRNG(seed: 5)
        let items = NBackEngine.stream(count: 10_000, n: 2, p: 0.3, pool: NBackEngine.positions, rng: &rng)
        let targets = (2..<items.count).filter { items[$0] == items[$0 - 2] }.count
        let rate = Double(targets) / Double(items.count - 2)
        #expect(abs(rate - 0.3) < 0.02)
    }

    @Test func perfectPlayScores1000() {
        var e = make(.tier(.expert))
        run(&e) { engine, i, m in engine.isTarget(m, at: i) }
        #expect(e.outcome?.score == 1000)
        #expect(e.outcome?.accuracy == 1)
    }

    @Test func tappingEverythingScoresZero() {
        var e = make(.tier(.advanced))
        run(&e) { _, _, _ in true }
        #expect(e.outcome?.score == 0)
    }

    @Test func noResponseScoresZero() {
        var e = make(.tier(.beginner))
        run(&e) { _, _, _ in false }
        #expect(e.outcome?.score == 0)
        #expect(e.position.misses == e.position.targets)
    }

    @Test func soundIgnoredInSingleMode() {
        var e = make(.tier(.beginner))
        _ = e.advance(by: .seconds(1))
        #expect(e.respond(.sound).isEmpty)
    }

    @Test func dualSpeaksLetterOnOnset() {
        var e = make(.tier(.expert))
        _ = e.advance(by: .seconds(1))
        let fx = e.advance(by: .milliseconds(10))
        #expect(fx.contains(.speak(NBackEngine.letters[e.letterIndices[0]])))
    }

    @Test func stimulusVisibleOnlyFirst500ms() {
        var e = make(.tier(.beginner))
        #expect(e.visibleCell == nil)  // lead-in
        _ = e.advance(by: .seconds(1))
        _ = e.advance(by: .milliseconds(400))
        #expect(e.visibleCell == e.cells[0])
        _ = e.advance(by: .milliseconds(200))
        #expect(e.visibleCell == nil)
    }

    @Test func resumeReshowsCurrentStimulus() {
        var e = make(.tier(.beginner))
        _ = e.advance(by: .seconds(1))
        _ = e.advance(by: .seconds(2))
        e.resumeFromPause()
        #expect(e.timeInTrial == .zero && e.index == 0)
    }
}
