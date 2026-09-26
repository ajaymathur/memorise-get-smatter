/// Side effects an engine asks the host to perform. Engines stay pure; the host plays them.
enum Effect: Sendable, Equatable {
    case sound(Cue)
    case haptic(Haptic)
    case speak(String)
    /// VoiceOver announcement.
    case announce(String)

    enum Haptic: Sendable, Equatable { case success, error, selection }
}

/// How a board sends actions to its engine.
typealias Sender<E> = (_ action: (inout E) -> [Effect]) -> Void

struct Outcome: Sendable, Equatable {
    var score: Int
    var accuracy: Double
    /// Per-game facts used by achievements (e.g. `maxSpan`, `extraMoves`, `luresPicked`).
    var stats: [String: Int] = [:]
}

/// Deterministic, UI-free game state machine driven by game time (design.md §1).
protocol GameEngine: Sendable {
    /// Advance game time; the host only calls this while the game is running (paused time is excluded).
    mutating func advance(by dt: Duration) -> [Effect]
    /// Called on resume from pause. Restarts any stimulus in progress so pausing cannot extend exposure (REQ-GM-05).
    mutating func resumeFromPause()
    var outcome: Outcome? { get }
}

extension GameEngine {
    mutating func resumeFromPause() {}
}

extension Duration {
    var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }

    /// Relaxed timing scales every window by 1.5 (REQ-AX-06).
    func scaled(_ factor: Double) -> Duration { .seconds(seconds * factor) }
}

/// Discrimination index Pr = hit rate − false-alarm rate (Snodgrass & Corwin 1988).
enum Pr {
    static func value(hits: Int, targets: Int, falseAlarms: Int, nonTargets: Int) -> Double {
        let hitRate = targets == 0 ? 0 : Double(hits) / Double(targets)
        let faRate = nonTargets == 0 ? 0 : Double(falseAlarms) / Double(nonTargets)
        return hitRate - faRate
    }

    /// Score = round(1000 × max(0, Pr)) (design.md §3).
    static func score(_ pr: Double) -> Int { Int((1000 * max(0, pr)).rounded()) }
}
