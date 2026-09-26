import SwiftData
import SwiftUI

/// Shared shell for every ranked game: intro → play (clock, pause) → result + save.
struct GameHostView<Engine: GameEngine, Board: View>: View {
    typealias Send = (_ action: (inout Engine) -> [Effect]) -> Void

    let game: GameKind
    let tier: Tier
    let make: (SessionMode) -> Engine
    @ViewBuilder let board: (Engine, @escaping Send) -> Board

    private enum Phase: Equatable { case intro, playing, paused, result(Outcome, best: Bool) }

    @State private var engine: Engine?
    @State private var phase = Phase.intro
    @State private var mode = SessionMode.ranked
    @State private var haptic: (kind: Effect.Haptic, count: Int) = (.selection, 0)
    @AppStorage(SettingsKey.relaxedTiming) private var relaxedTiming = false
    @AppStorage(SettingsKey.hapticsOn) private var hapticsOn = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
            .navigationTitle(Text(game.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if phase == .playing {
                    Button("Pause", systemImage: "pause.fill") { phase = .paused }
                }
            }
            .task(id: phase == .playing) { await runClock() }
            .onChange(of: scenePhase) { if scenePhase != .active && phase == .playing { phase = .paused } }
            .sensoryFeedback(trigger: haptic.count) { _, _ in
                guard hapticsOn else { return nil }
                switch haptic.kind {
                case .success: return .success
                case .error: return .error
                case .selection: return .selection
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .intro:
            GameIntroView(game: game, tier: tier, relaxed: relaxedTiming, start: start)
        case .playing:
            if let engine { board(engine, send) }
        case .paused:
            PausedView {
                engine?.resumeFromPause()
                phase = .playing
            }
        case .result(let outcome, let best):
            ResultView(game: game, tier: tier, mode: mode, outcome: outcome, isPersonalBest: best, playAgain: start) {
                dismiss()
            }
        }
    }

    private func start() {
        mode = relaxedTiming ? .relaxed : .ranked
        engine = make(mode)
        phase = .playing
    }

    private func send(_ action: (inout Engine) -> [Effect]) {
        guard phase == .playing, var e = engine else { return }
        let effects = action(&e)
        engine = e
        perform(effects)
    }

    /// Advances game time only while playing, so paused time never counts (REQ-GM-05).
    private func runClock() async {
        guard phase == .playing else { return }
        let clock = ContinuousClock()
        var last = clock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            let now = clock.now
            send { $0.advance(by: now - last) }
            last = now
        }
    }

    private func perform(_ effects: [Effect]) {
        for effect in effects {
            switch effect {
            case .sound(let cue): SoundPlayer.shared.play(cue)
            case .haptic(let kind): haptic = (kind, haptic.count + 1)
            case .speak(let text): Speech.shared.say(text)
            case .announce(let text): AccessibilityNotification.Announcement(text).post()
            }
        }
        if let outcome = engine?.outcome, phase == .playing { finish(outcome) }
    }

    private func finish(_ outcome: Outcome) {
        let id = game.rawValue
        let tierID = tier.rawValue
        let previous =
            (try? context.fetch(
                FetchDescriptor<SessionRecord>(
                    predicate: #Predicate { $0.game == id && $0.tier == tierID && $0.mode != "training" })))?
            .map(\.score).max()
        let best = outcome.score > 0 && outcome.score > (previous ?? 0)
        context.insert(
            SessionRecord(game: game, tier: tier, mode: mode, score: outcome.score, accuracy: outcome.accuracy))
        try? context.save()
        if best { SoundPlayer.shared.play(.personalBest) }
        phase = .result(outcome, best: best)
    }
}

private struct PausedView: View {
    let resume: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Paused", systemImage: "pause.circle")
        } description: {
            Text("The board is hidden while paused.")
        } actions: {
            Button("Resume", action: resume).buttonStyle(.borderedProminent)
        }
    }
}
