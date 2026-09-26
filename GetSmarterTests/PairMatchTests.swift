import Testing

@testable import GetSmarter

struct PairMatchTests {
    func make(_ tier: Tier, seed: UInt64 = 7) -> PairMatchEngine {
        var rng = SeededRNG(seed: seed)
        return PairMatchEngine(config: .tier(tier), rng: &rng)
    }

    /// Index of the partner card of `i`.
    func partner(_ e: PairMatchEngine, _ i: Int) -> Int {
        e.cards.indices.first { $0 != i && e.cards[$0].face == e.cards[i].face }!
    }

    @Test(arguments: [(Tier.beginner, 6), (.advanced, 8), (.expert, 15)])
    func tierParams(tier: Tier, pairs: Int) {
        let e = make(tier)
        #expect(e.config.pairs == pairs)
        #expect(e.cards.count == pairs * 2)
        #expect(Set(e.cards.map(\.face)).count == pairs)
    }

    @Test func sameSeedSameBoard() {
        #expect(make(.advanced, seed: 1).cards == make(.advanced, seed: 1).cards)
        #expect(make(.advanced, seed: 1).cards != make(.advanced, seed: 2).cards)
    }

    @Test func previewRevealsThenHides() {
        var e = make(.beginner)
        #expect(e.cards.allSatisfy { $0.state == .revealed })
        #expect(e.tap(0).isEmpty)  // taps ignored during preview
        _ = e.advance(by: .seconds(2))
        #expect(e.cards.allSatisfy { $0.state == .hidden })
        #expect(e.phase == .playing)
    }

    @Test func expertHasNoPreview() {
        #expect(make(.expert).phase == .playing)
    }

    @Test func mismatchFlipsBackAndBlocksTaps() {
        var e = make(.expert)
        let a = 0
        let b = e.cards.indices.first { e.cards[$0].face != e.cards[a].face }!
        _ = e.tap(a)
        _ = e.tap(b)
        let third = e.cards.indices.first { $0 != a && $0 != b }!
        #expect(e.tap(third).isEmpty)  // REQ-PM-03
        _ = e.advance(by: .milliseconds(799))
        #expect(e.cards[a].state == .revealed)
        _ = e.advance(by: .milliseconds(1))
        #expect(e.cards[a].state == .hidden && e.cards[b].state == .hidden)
    }

    @Test func perfectGameScore() {
        var e = make(.expert)
        for i in e.cards.indices where e.cards[i].state == .hidden {
            _ = e.tap(i)
            _ = e.tap(partner(e, i))
            _ = e.advance(by: .seconds(1))
        }
        // Last pair found after 14 s → 1500 + 76 s × 5.
        #expect(e.outcome == Outcome(score: 1880, accuracy: 1, stats: ["extraMoves": 0, "completed": 1, "pairs": 15]))
    }

    @Test func timeoutScoresFoundPairsOnly() {
        var e = make(.expert)
        let b = e.cards.indices.first { e.cards[$0].face != e.cards[0].face }!
        _ = e.tap(0)
        _ = e.tap(b)  // one wasted move
        _ = e.advance(by: .seconds(1))
        _ = e.tap(0)
        _ = e.tap(partner(e, 0))
        _ = e.advance(by: .seconds(90))
        #expect(e.phase == .finished)
        #expect(e.outcome?.score == 100)  // 1 pair, 2 moves vs 15 pairs → no extra moves yet
    }

    @Test func scoreNeverNegative() {
        var e = make(.expert)
        let b = e.cards.indices.first { e.cards[$0].face != e.cards[0].face }!
        for _ in 0..<20 {
            _ = e.tap(0)
            _ = e.tap(b)
            _ = e.advance(by: .seconds(1))
        }
        _ = e.advance(by: .seconds(90))
        #expect(e.outcome?.score == 0)
    }

    @Test func relaxedScalesPreviewAndCap() {
        let c = PairMatchEngine.Config.tier(.beginner).relaxed()
        #expect(c.preview == .seconds(3))
        #expect(c.timeCap == .seconds(135))
    }

    @Test(arguments: 3...15)
    func trainingGridFits(pairs: Int) {
        let c = PairMatchEngine.Config.training(pairs: pairs)
        #expect(c.rows * c.cols >= pairs * 2)
        var rng = SeededRNG(seed: 1)
        #expect(PairMatchEngine(config: c, rng: &rng).cards.count == pairs * 2)
    }
}
