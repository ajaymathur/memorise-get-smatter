import Foundation

/// N-back (Kirchner 1958; Jaeggi et al. 2008): respond when the current stimulus matches
/// the one `n` steps back. Position always; spoken letter too in dual mode (REQ-NB-01..05).
struct NBackEngine: GameEngine {
    struct Config: Sendable, Equatable {
        var n: Int
        var dual = false
        var stimulus: Duration = .milliseconds(500)
        var trial: Duration = .milliseconds(3000)
        var trials: Int
        var targetProbability = 0.3
        var leadIn: Duration = .seconds(1)

        static func tier(_ tier: Tier) -> Config {
            switch tier {
            case .beginner: Config(n: 1, trials: 21)
            case .advanced: Config(n: 2, trials: 22)
            case .expert: Config(n: 2, dual: true, trials: 22)
            }
        }

        /// Daily Training block: 10 + n trials, position only (design.md §5).
        static func training(n: Int) -> Config { Config(n: n, trials: 10 + n) }

        func relaxed() -> Config {
            var c = self
            c.stimulus = stimulus.scaled(SessionMode.relaxedTimingFactor)
            c.trial = trial.scaled(SessionMode.relaxedTimingFactor)
            return c
        }
    }

    enum Modality: Sendable { case position, sound }

    /// Outer ring of a 3×3 grid (centre excluded).
    static let positions = [0, 1, 2, 3, 5, 6, 7, 8]
    /// Jaeggi et al. 2008 letter set, chosen to be acoustically distinct.
    static let letters = ["C", "H", "K", "L", "Q", "R", "S", "T"]

    static func positionName(_ cell: Int) -> String {
        switch cell {
        case 0: String(localized: "Top left")
        case 1: String(localized: "Top")
        case 2: String(localized: "Top right")
        case 3: String(localized: "Left")
        case 5: String(localized: "Right")
        case 6: String(localized: "Bottom left")
        case 7: String(localized: "Bottom")
        default: String(localized: "Bottom right")
        }
    }

    struct Tally: Sendable, Equatable {
        var hits = 0, misses = 0, falseAlarms = 0, correctRejections = 0
        var targets: Int { hits + misses }
        var nonTargets: Int { falseAlarms + correctRejections }
        var pr: Double { Pr.value(hits: hits, targets: targets, falseAlarms: falseAlarms, nonTargets: nonTargets) }
    }

    let config: Config
    /// Grid cell per trial.
    let cells: [Int]
    /// Letter index per trial (dual only; empty otherwise).
    let letterIndices: [Int]
    private(set) var index = 0
    private(set) var timeInTrial: Duration = .zero
    private(set) var leadInLeft: Duration
    private var onsetDone = false
    private(set) var responded: Set<Modality> = []
    private(set) var position = Tally()
    private(set) var sound = Tally()
    private(set) var outcome: Outcome?

    init(config: Config, rng: inout some RandomNumberGenerator) {
        self.config = config
        leadInLeft = config.leadIn
        cells = Self.stream(
            count: config.trials, n: config.n, p: config.targetProbability, pool: Self.positions, rng: &rng)
        letterIndices =
            config.dual
            ? Self.stream(count: config.trials, n: config.n, p: config.targetProbability, pool: Array(0..<8), rng: &rng)
            : []
    }

    /// Items where ~p of eligible trials repeat the item n back; non-targets never do by accident.
    static func stream(count: Int, n: Int, p: Double, pool: [Int], rng: inout some RandomNumberGenerator) -> [Int] {
        var items: [Int] = []
        for i in 0..<count {
            if i >= n, Double.random(in: 0..<1, using: &rng) < p {
                items.append(items[i - n])
            } else {
                let avoid = i >= n ? items[i - n] : nil
                items.append(pool.filter { $0 != avoid }.randomElement(using: &rng)!)
            }
        }
        return items
    }

    func isTarget(_ modality: Modality, at i: Int) -> Bool {
        guard i >= config.n else { return false }
        return modality == .position ? cells[i] == cells[i - config.n] : letterIndices[i] == letterIndices[i - config.n]
    }

    var isRunning: Bool { leadInLeft <= .zero && outcome == nil }
    /// Cell currently shown, if the stimulus is visible.
    var visibleCell: Int? { isRunning && timeInTrial < config.stimulus ? cells[index] : nil }

    mutating func respond(_ modality: Modality) -> [Effect] {
        guard isRunning, modality == .position || config.dual, !responded.contains(modality) else { return [] }
        responded.insert(modality)
        return [.haptic(.selection)]
    }

    mutating func advance(by dt: Duration) -> [Effect] {
        guard outcome == nil else { return [] }
        if leadInLeft > .zero {
            leadInLeft -= dt
            return []
        }
        var effects: [Effect] = []
        if !onsetDone {
            onsetDone = true
            effects.append(.announce(Self.positionName(cells[index])))
            if config.dual { effects.append(.speak(Self.letters[letterIndices[index]])) }
        }
        timeInTrial += dt
        if timeInTrial >= config.trial {
            effects += endTrial()
        }
        return effects
    }

    private mutating func endTrial() -> [Effect] {
        var errors = Self.record(&position, target: isTarget(.position, at: index), said: responded.contains(.position))
        if config.dual {
            errors += Self.record(&sound, target: isTarget(.sound, at: index), said: responded.contains(.sound))
        }
        var effects: [Effect] = errors > 0 ? [.haptic(.error)] : []
        responded = []
        timeInTrial = .zero
        onsetDone = false
        index += 1
        if index == config.trials { effects += finish() }
        return effects
    }

    /// Returns 1 for a miss or false alarm, else 0.
    private static func record(_ tally: inout Tally, target: Bool, said: Bool) -> Int {
        switch (target, said) {
        case (true, true): tally.hits += 1
        case (true, false): tally.misses += 1
        case (false, true): tally.falseAlarms += 1
        case (false, false): tally.correctRejections += 1
        }
        return target == said ? 0 : 1
    }

    private mutating func finish() -> [Effect] {
        let prs = config.dual ? [position.pr, sound.pr] : [position.pr]
        let pr = prs.reduce(0, +) / Double(prs.count)
        let tallies = config.dual ? [position, sound] : [position]
        let correct = tallies.map { $0.hits + $0.correctRejections }.reduce(0, +)
        let total = tallies.map { $0.targets + $0.nonTargets }.reduce(0, +)
        outcome = Outcome(
            score: Pr.score(pr), accuracy: total == 0 ? 0 : Double(correct) / Double(total),
            stats: ["n": config.n, "prPercent": Int((pr * 100).rounded())])
        return [.sound(.finish)]
    }

    /// Re-show the current stimulus from its start (REQ-GM-05).
    mutating func resumeFromPause() {
        guard isRunning else { return }
        timeInTrial = .zero
        onsetDone = false
        responded = []
    }
}
