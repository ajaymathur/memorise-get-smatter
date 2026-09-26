import SwiftData
import SwiftUI

/// Runs one engine: game clock, pause overlay, effects. Calls `onFinish` once when the engine produces an outcome.
struct GamePlayView<Engine: GameEngine, Board: View>: View {
    typealias Send = Sender<Engine>

    @Binding var engine: Engine
    let onFinish: (Outcome) -> Void
    @ViewBuilder let board: (Engine, @escaping Send) -> Board

    @State private var paused = false
    @State private var finished = false
    @State private var haptic: (kind: Effect.Haptic, count: Int) = (.selection, 0)
    @AppStorage(SettingsKey.hapticsOn) private var hapticsOn = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if paused {
                ContentUnavailableView {
                    Label("Paused", systemImage: "pause.circle")
                } description: {
                    Text("The board is hidden while paused.")
                } actions: {
                    Button("Resume") {
                        engine.resumeFromPause()
                        paused = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                board(engine, send)
            }
        }
        .toolbar {
            if !paused {
                Button("Pause", systemImage: "pause.fill") { paused = true }
            }
        }
        .task(id: paused) { await runClock() }
        .onChange(of: scenePhase) { if scenePhase != .active { paused = true } }
        .sensoryFeedback(trigger: haptic.count) { _, _ in
            guard hapticsOn else { return nil }
            switch haptic.kind {
            case .success: return .success
            case .error: return .error
            case .selection: return .selection
            }
        }
    }

    private func send(_ action: (inout Engine) -> [Effect]) {
        guard !paused, !finished else { return }
        perform(action(&engine))
    }

    /// Advances game time only while running, so paused time never counts (REQ-GM-05).
    private func runClock() async {
        guard !paused else { return }
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
        if let outcome = engine.outcome, !finished {
            finished = true
            onFinish(outcome)
        }
    }
}

/// Ranked game shell: intro → play → result + save.
struct GameHostView<Engine: GameEngine, Board: View>: View {
    typealias Send = Sender<Engine>

    let game: GameKind
    let tier: Tier
    let make: (SessionMode) -> Engine
    @ViewBuilder let board: (Engine, @escaping Send) -> Board

    private enum Phase: Equatable { case intro, playing, result(Outcome, best: Bool) }

    @State private var engine: Engine?
    @State private var phase = Phase.intro
    @State private var mode = SessionMode.ranked
    @State private var run = 0
    @State private var askToShare = false
    @State private var lastRecord: SessionRecord?
    @AppStorage(SettingsKey.relaxedTiming) private var relaxedTiming = false
    @AppStorage(SettingsKey.shareScores) private var shareScores = ShareChoice.notAsked.rawValue
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch phase {
            case .intro:
                GameIntroView(game: game, tier: tier, relaxed: relaxedTiming, start: start)
            case .playing:
                if let binding = Binding($engine) {
                    GamePlayView(engine: binding, onFinish: finish, board: board).id(run)
                }
            case .result(let outcome, let best):
                ResultView(game: game, tier: tier, mode: mode, outcome: outcome, isPersonalBest: best, playAgain: start)
                {
                    dismiss()
                }
            }
        }
        .navigationTitle(Text(game.title))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Share your scores on global leaderboards?", isPresented: $askToShare) {
            Button("Share") {
                shareScores = ShareChoice.share.rawValue
                lastRecord?.pendingSubmit = true
                GameCenterService.shared.sync(context)
            }
            Button("Keep private", role: .cancel) { shareScores = ShareChoice.keepPrivate.rawValue }
        } message: {
            Text("Other players will see your Game Center nickname and best scores. You can change this in Settings.")
        }
    }

    private func start() {
        mode = relaxedTiming ? .relaxed : .ranked
        engine = make(mode)
        run += 1
        phase = .playing
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
        let record = SessionRecord(game: game, tier: tier, mode: mode, score: outcome.score, accuracy: outcome.accuracy)
        // Only ranked games from players who opted in are ever submitted (REQ-GC-03).
        record.pendingSubmit = mode == .ranked && shareScores == ShareChoice.share.rawValue
        context.insert(record)
        try? context.save()
        lastRecord = record
        if best { SoundPlayer.shared.play(.personalBest) }
        phase = .result(outcome, best: best)
        let gameCenter = GameCenterService.shared
        gameCenter.sync(context, latest: .init(game: game, tier: tier, outcome: outcome))
        if mode == .ranked, gameCenter.isAuthenticated, shareScores == ShareChoice.notAsked.rawValue {
            askToShare = true  // one-time opt-in (REQ-GC-02)
        }
    }
}
