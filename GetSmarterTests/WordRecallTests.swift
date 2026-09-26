import Testing

@testable import GetSmarter

struct WordRecallTests {
    func make(_ config: WordRecallEngine.Config, seed: UInt64 = 9) -> WordRecallEngine {
        WordRecallEngine(config: config, rng: SeededRNG(seed: seed))
    }

    func toTest(_ e: inout WordRecallEngine) {
        while e.phase != .test { _ = e.advance(by: .milliseconds(100)) }
    }

    @Test func bankMeetsRequirements() {
        let bank = WordBank.bundled
        #expect(Set(bank.nouns).count >= 300)
        #expect(bank.drm.count >= 12)
        let lures = Set(bank.drm.map(\.lure))
        let associates = Set(bank.drm.flatMap(\.words))
        #expect(lures.isDisjoint(with: associates))
        #expect(Set(bank.nouns).isDisjoint(with: associates.union(lures)))
    }

    @Test(arguments: [Tier.beginner, .advanced, .expert])
    func tierComposition(tier: Tier) {
        let e = make(.tier(tier))
        let c = e.config
        #expect(e.studied.count == c.listLength)
        #expect(e.choices.count == c.choices)
        #expect(Set(e.choices).count == c.choices)  // no repeats (REQ-WR-04)
        #expect(Set(e.studied).isSubset(of: Set(e.choices)))
        #expect(e.lureWords.count == (c.lures ? c.foils / 3 : 0))
        #expect(e.lureWords.isDisjoint(with: Set(e.studied)))
        #expect(e.lureWords.isSubset(of: Set(e.choices)))
    }

    @Test func studyShowsEveryWordInOrder() {
        var e = make(.tier(.beginner))
        var shown: [String] = []
        while e.phase != .test {
            _ = e.advance(by: .milliseconds(50))
            if let w = e.shownWord, shown.last != w { shown.append(w) }
        }
        #expect(shown == e.studied)
    }

    @Test func expertRunsDistractorFor15s() {
        var e = make(.tier(.expert))
        while case .study = e.phase { _ = e.advance(by: .milliseconds(100)) }
        guard case .distractor(_, let start, let options) = e.phase else {
            Issue.record("expected distractor")
            return
        }
        #expect(options.contains(start - 3))
        _ = e.answerDistractor(start - 3)
        if case .distractor(_, let now, _) = e.phase { #expect(now == start - 3) }
        _ = e.advance(by: .seconds(15))
        #expect(e.phase == .test)
    }

    @Test func perfectRecognitionScores1000() {
        var e = make(.tier(.advanced))
        toTest(&e)
        for w in e.studied { _ = e.toggle(w) }
        _ = e.done()
        #expect(e.outcome?.score == 1000)
        #expect(e.outcome?.stats["luresPicked"] == 0)
    }

    @Test func selectingEverythingScoresZero() {
        var e = make(.tier(.advanced))
        toTest(&e)
        for w in e.choices { _ = e.toggle(w) }
        _ = e.done()
        #expect(e.outcome?.score == 0)
        #expect(e.outcome?.stats["luresPicked"] == e.lureWords.count)
    }

    @Test func toggleTwiceDeselects() {
        var e = make(.tier(.beginner))
        toTest(&e)
        _ = e.toggle(e.choices[0])
        _ = e.toggle(e.choices[0])
        #expect(e.selected.isEmpty)
    }

    @Test func noTogglingDuringStudy() {
        var e = make(.tier(.beginner))
        #expect(e.toggle(e.choices[0]).isEmpty)
    }

    @Test(arguments: [4, 10, 20])
    func trainingSizes(length: Int) {
        let e = make(.training(length: length))
        #expect(e.studied.count == length)
        #expect(e.choices.count == length + min(length, 10))
    }
}
