import Foundation

/// Concentration-style pair matching (REQ-PM-01..03). Scoring per design.md §3.
struct PairMatchEngine: GameEngine {
    struct Config: Sendable, Equatable {
        var rows: Int
        var cols: Int
        var preview: Duration
        var timeCap: Duration = .seconds(90)
        var mismatchDelay: Duration = .milliseconds(800)
        /// Defaults to filling the grid; training grids may leave slots empty.
        var pairs: Int

        init(rows: Int, cols: Int, preview: Duration, pairs: Int? = nil) {
            (self.rows, self.cols, self.preview) = (rows, cols, preview)
            self.pairs = pairs ?? rows * cols / 2
        }

        static func tier(_ tier: Tier) -> Config {
            switch tier {
            case .beginner: Config(rows: 4, cols: 3, preview: .seconds(2))
            case .advanced: Config(rows: 4, cols: 4, preview: .seconds(1))
            case .expert: Config(rows: 6, cols: 5, preview: .zero)
            }
        }

        /// Daily Training: `pairs` 3…15 on the smallest grid that fits, 1 s preview (design.md §5).
        static func training(pairs: Int) -> Config {
            let cards = pairs * 2
            let cols = cards <= 12 ? 3 : cards <= 20 ? 4 : 5
            return Config(rows: (cards + cols - 1) / cols, cols: cols, preview: .seconds(1), pairs: pairs)
        }

        func relaxed() -> Config {
            var c = self
            c.preview = preview.scaled(SessionMode.relaxedTimingFactor)
            c.timeCap = timeCap.scaled(SessionMode.relaxedTimingFactor)
            return c
        }
    }

    enum CardState: Sendable, Equatable { case hidden, revealed, matched }

    struct Card: Sendable, Equatable {
        var face: Int
        var state: CardState = .hidden
    }

    enum Phase: Sendable, Equatable {
        case preview(remaining: Duration)
        case playing
        case mismatch(remaining: Duration, first: Int, second: Int)
        case finished
    }

    let config: Config
    private(set) var cards: [Card]
    private(set) var phase: Phase
    private(set) var playTime: Duration = .zero
    private(set) var moves = 0
    private(set) var pairsFound = 0
    private var firstPick: Int?
    private(set) var outcome: Outcome?

    init(config: Config, rng: inout some RandomNumberGenerator) {
        self.config = config
        var faces = Array(0..<config.pairs).flatMap { [$0, $0] }
        faces.shuffle(using: &rng)
        // Odd grids (training) leave one slot empty; cards fill the first `2 × pairs` slots.
        cards = faces.map { Card(face: $0) }
        if config.preview > .zero {
            cards = cards.map { Card(face: $0.face, state: .revealed) }
            phase = .preview(remaining: config.preview)
        } else {
            phase = .playing
        }
    }

    var timeLeft: Duration { max(.zero, config.timeCap - playTime) }
    var extraMoves: Int { max(0, moves - config.pairs) }

    mutating func tap(_ index: Int) -> [Effect] {
        guard cards.indices.contains(index), cards[index].state == .hidden else { return [] }
        switch phase {
        case .playing: break
        default: return []  // REQ-PM-03: ignore taps during preview, mismatch, or after finish
        }
        cards[index].state = .revealed
        var effects: [Effect] = [.sound(.flip), .haptic(.selection), .announce(Faces.name(cards[index].face))]
        guard let first = firstPick else {
            firstPick = index
            return effects
        }
        firstPick = nil
        moves += 1
        if cards[first].face == cards[index].face {
            cards[first].state = .matched
            cards[index].state = .matched
            pairsFound += 1
            effects += [.sound(.correct), .haptic(.success), .announce(String(localized: "Match"))]
            if pairsFound == config.pairs { effects += finish(completed: true) }
        } else {
            phase = .mismatch(remaining: config.mismatchDelay, first: first, second: index)
            effects += [.haptic(.error)]
        }
        return effects
    }

    mutating func advance(by dt: Duration) -> [Effect] {
        switch phase {
        case .finished:
            return []
        case .preview(let remaining):
            if remaining > dt {
                phase = .preview(remaining: remaining - dt)
            } else {
                for i in cards.indices { cards[i].state = .hidden }
                phase = .playing
            }
            return []
        case .mismatch(let remaining, let a, let b):
            playTime += dt
            if remaining <= dt {
                cards[a].state = .hidden
                cards[b].state = .hidden
                phase = .playing
            } else {
                phase = .mismatch(remaining: remaining - dt, first: a, second: b)
            }
        case .playing:
            playTime += dt
        }
        return playTime >= config.timeCap ? finish(completed: false) : []
    }

    private mutating func finish(completed: Bool) -> [Effect] {
        phase = .finished
        let bonus = completed ? Int(timeLeft.seconds) * 5 : 0
        let score = max(0, pairsFound * 100 - extraMoves * 10 + bonus)
        let accuracy = moves == 0 ? 0 : Double(pairsFound) / Double(moves)
        outcome = Outcome(
            score: score, accuracy: accuracy,
            stats: ["extraMoves": extraMoves, "completed": completed ? 1 : 0, "pairs": config.pairs])
        return [.sound(.finish)]
    }
}
