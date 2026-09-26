import Foundation

/// Daily Training stage: plays rounds of one game for a time window, adapting the level
/// with a 2-down/1-up staircase after each round (REQ-DT-01, REQ-DT-02). Never ranked.
struct TrainingRounds<Inner: GameEngine>: GameEngine {
    let window: Duration
    let make: @MainActor @Sendable (Int) -> Inner
    let success: @MainActor @Sendable (Outcome) -> Bool
    private(set) var staircase: Staircase
    private(set) var current: Inner
    private(set) var elapsed: Duration = .zero
    private(set) var rounds = 0
    private(set) var successes = 0
    private(set) var outcome: Outcome?

    init(
        level: Int, range: ClosedRange<Int>, window: Duration = .seconds(75),
        make: @escaping @MainActor @Sendable (Int) -> Inner, success: @escaping @MainActor @Sendable (Outcome) -> Bool
    ) {
        staircase = Staircase(level: level, range: range)
        self.window = window
        self.make = make
        self.success = success
        current = make(staircase.level)
    }

    mutating func act(_ action: (inout Inner) -> [Effect]) -> [Effect] {
        guard outcome == nil else { return [] }
        return action(&current) + checkRound()
    }

    mutating func advance(by dt: Duration) -> [Effect] {
        guard outcome == nil else { return [] }
        elapsed += dt
        return current.advance(by: dt) + checkRound()
    }

    mutating func resumeFromPause() { current.resumeFromPause() }

    /// When a round ends: adapt, then start the next round or finish if the window has passed.
    private mutating func checkRound() -> [Effect] {
        guard let result = current.outcome else { return [] }
        let ok = success(result)
        let before = staircase.level
        staircase.record(success: ok)
        rounds += 1
        if ok { successes += 1 }
        if elapsed >= window {
            outcome = Outcome(
                score: staircase.level, accuracy: Double(successes) / Double(rounds),
                stats: ["level": staircase.level])
            return []
        }
        current = make(staircase.level)
        switch staircase.level - before {
        case 1...: return [.announce(String(localized: "Level up"))]
        case ..<0: return [.announce(String(localized: "Level down"))]
        default: return []
        }
    }
}

/// Per-game Daily Training setup (design.md §5).
enum TrainingPlan {
    static func range(_ game: GameKind) -> ClosedRange<Int> {
        switch game {
        case .pairMatch: 3...15
        case .sequenceEcho: 2...9
        case .nBack: 1...6
        case .wordRecall: 4...20
        }
    }

    static func startLevel(_ game: GameKind) -> Int { range(game).lowerBound + (game == .nBack ? 0 : 1) }

    static func success(_ game: GameKind) -> @MainActor @Sendable (Outcome) -> Bool {
        switch game {
        case .pairMatch: { $0.stats["completed"] == 1 && ($0.stats["extraMoves"] ?? .max) <= ($0.stats["pairs"] ?? 0) }
        case .sequenceEcho: { $0.accuracy == 1 }
        case .nBack, .wordRecall: { ($0.stats["prPercent"] ?? 0) >= 60 }
        }
    }
}
