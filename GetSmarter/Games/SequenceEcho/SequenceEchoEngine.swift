import Foundation

/// Corsi block-tapping (REQ-SE-01..04): watch a sequence, reproduce it (backward on Expert).
/// Two trials per span; advance if either is correct; stop when both fail (Kessels et al. 2000).
struct SequenceEchoEngine: GameEngine {
    struct Config: Sendable, Equatable {
        var side: Int
        var startSpan: Int
        var itemDuration: Duration
        var gap: Duration = .milliseconds(250)
        var backward = false
        var maxSpan = 12
        /// Daily Training: one sequence per round instead of the two-trial rule.
        var singleTrial = false

        var tiles: Int { side * side }

        static func tier(_ tier: Tier) -> Config {
            switch tier {
            case .beginner: Config(side: 2, startSpan: 2, itemDuration: .milliseconds(800))
            case .advanced: Config(side: 3, startSpan: 3, itemDuration: .milliseconds(600))
            case .expert: Config(side: 4, startSpan: 4, itemDuration: .milliseconds(450), backward: true)
            }
        }

        static func training(span: Int) -> Config {
            Config(side: 3, startSpan: span, itemDuration: .milliseconds(600), maxSpan: span, singleTrial: true)
        }

        func relaxed() -> Config {
            var c = self
            c.itemDuration = itemDuration.scaled(SessionMode.relaxedTimingFactor)
            c.gap = gap.scaled(SessionMode.relaxedTimingFactor)
            return c
        }
    }

    enum Phase: Sendable, Equatable {
        /// Showing `sequence[index]`; `lit` false during the gap before it.
        case playback(index: Int, lit: Bool, remaining: Duration)
        case input
        /// Brief pause after an answer before the next trial.
        case feedback(correct: Bool, remaining: Duration)
        case finished
    }

    let config: Config
    private var rng: SeededRNG
    private(set) var span: Int
    private(set) var trialInSpan = 0
    private(set) var sequence: [Int] = []
    private(set) var entered: [Int] = []
    private(set) var phase: Phase = .input
    private var spanHadCorrect = false
    private(set) var longestCorrect = 0
    private(set) var perfectSpans = 0
    private var spanCorrectCount = 0
    private(set) var trials = 0
    private(set) var correctTrials = 0
    private(set) var outcome: Outcome?

    static let feedbackDuration: Duration = .milliseconds(700)

    init(config: Config, rng: SeededRNG) {
        self.config = config
        self.rng = rng
        span = config.startSpan
        startTrial()
    }

    /// Tile lit during playback, if any.
    var litTile: Int? {
        if case .playback(let i, true, _) = phase { return sequence[i] }
        return nil
    }

    private var expected: [Int] { config.backward ? sequence.reversed() : sequence }

    private mutating func startTrial() {
        // Random tiles; never the same tile twice in a row (a repeat is invisible on playback).
        sequence = []
        while sequence.count < span {
            let t = Int.random(in: 0..<config.tiles, using: &rng)
            if t != sequence.last { sequence.append(t) }
        }
        entered = []
        phase = .playback(index: 0, lit: false, remaining: config.gap)
    }

    mutating func tap(_ tile: Int) -> [Effect] {
        guard phase == .input, (0..<config.tiles).contains(tile) else { return [] }
        entered.append(tile)
        var effects: [Effect] = [.sound(.tile(tile)), .haptic(.selection)]
        let target = expected
        if entered.last != target[entered.count - 1] {
            effects += endTrial(correct: false)
        } else if entered.count == target.count {
            effects += endTrial(correct: true)
        }
        return effects
    }

    private mutating func endTrial(correct: Bool) -> [Effect] {
        trials += 1
        if correct {
            correctTrials += 1
            spanCorrectCount += 1
            longestCorrect = max(longestCorrect, span)
        }
        phase = .feedback(correct: correct, remaining: Self.feedbackDuration)
        return correct
            ? [.sound(.correct), .haptic(.success), .announce(String(localized: "Correct"))]
            : [.sound(.wrong), .haptic(.error), .announce(String(localized: "Wrong"))]
    }

    /// After feedback: second trial at this span, next span, or finish.
    private mutating func nextTrial() -> [Effect] {
        trialInSpan += 1
        if config.singleTrial || trialInSpan == 2 {
            if spanCorrectCount == 2 { perfectSpans += 1 }
            let passed = spanCorrectCount > 0
            if !passed || span >= config.maxSpan || config.singleTrial { return finish() }
            span += 1
            trialInSpan = 0
            spanCorrectCount = 0
        }
        startTrial()
        return []
    }

    private mutating func finish() -> [Effect] {
        phase = .finished
        outcome = Outcome(
            score: longestCorrect * 100 + perfectSpans * 25,
            accuracy: trials == 0 ? 0 : Double(correctTrials) / Double(trials),
            stats: ["maxSpan": longestCorrect])
        return [.sound(.finish)]
    }

    mutating func advance(by dt: Duration) -> [Effect] {
        switch phase {
        case .input, .finished:
            return []
        case .feedback(let correct, let remaining):
            if remaining > dt {
                phase = .feedback(correct: correct, remaining: remaining - dt)
                return []
            }
            return nextTrial()
        case .playback(let index, let lit, let remaining):
            if remaining > dt {
                phase = .playback(index: index, lit: lit, remaining: remaining - dt)
                return []
            }
            if !lit {
                phase = .playback(index: index, lit: true, remaining: config.itemDuration)
                let tile = sequence[index]
                return [.sound(.tile(tile)), .announce(Faces.name(tile))]
            }
            if index + 1 < sequence.count {
                phase = .playback(index: index + 1, lit: false, remaining: config.gap)
            } else {
                phase = .input
                return [.announce(String(localized: config.backward ? "Your turn, in reverse" : "Your turn"))]
            }
            return []
        }
    }

    /// Replay the current item from its start (REQ-GM-05) without replaying earlier items.
    mutating func resumeFromPause() {
        if case .playback(let index, _, _) = phase {
            phase = .playback(index: index, lit: false, remaining: config.gap)
        }
    }
}
