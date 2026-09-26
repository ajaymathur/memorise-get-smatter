import SwiftData
import SwiftUI

/// ~5 minute adaptive circuit through all four games. Unranked (REQ-DT-01..04).
struct DailyTrainingView: View {
    private enum Phase: Equatable { case intro, stage(Int), summary }

    @State private var phase = Phase.intro
    @State private var results: [GameKind: Outcome] = [:]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<SessionRecord> { $0.circuitComplete }) private var circuits: [SessionRecord]

    private let games = GameKind.allCases

    var body: some View {
        Group {
            switch phase {
            case .intro: intro
            case .stage(let i):
                let game = games[i]
                stage(game, level: context.trainingLevel(for: game, default: TrainingPlan.startLevel(game)).level) {
                    finish(game, $0, index: i)
                }
                .id(i)
            case .summary: summary
            }
        }
        .navigationTitle("Daily Training")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var intro: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "figure.mind.and.body")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("About 5 minutes. You'll play each game for a little over a minute.")
                    .multilineTextAlignment(.center)
                Text(
                    "Levels adjust as you play: two successes in a row step up, a miss steps down. Training isn't posted to leaderboards."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                Button {
                    phase = .stage(0)
                } label: {
                    Text("Start training").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
    }

    private var summary: some View {
        List {
            Section {
                ForEach(games) { game in
                    if let result = results[game] {
                        LabeledContent {
                            Text("Level \(result.score)").monospacedDigit()
                        } label: {
                            Label {
                                Text(game.title)
                            } icon: {
                                Image(systemName: game.symbol).foregroundStyle(game.color)
                            }
                        }
                    }
                }
            } header: {
                Text("Circuit complete")
            } footer: {
                Text("Streak: \(Progression.streak(circuitDates: circuits.map(\.date))) days")
            }
            Section {
                Button("Done") { dismiss() }
            }
        }
    }

    private func finish(_ game: GameKind, _ outcome: Outcome, index: Int) {
        results[game] = outcome
        let row = context.trainingLevel(for: game, default: outcome.score)
        row.level = outcome.score
        row.updatedAt = .now
        let record = SessionRecord(
            game: game, tier: nil, mode: .training, score: outcome.score, accuracy: outcome.accuracy)
        record.circuitComplete = index == games.count - 1
        context.insert(record)
        try? context.save()
        GameCenterService.shared.sync(context)
        if index + 1 < games.count {
            phase = .stage(index + 1)
        } else {
            SoundPlayer.shared.play(.personalBest)
            phase = .summary
        }
    }

    @ViewBuilder
    private func stage(_ game: GameKind, level: Int, done: @escaping (Outcome) -> Void) -> some View {
        let range = TrainingPlan.range(game)
        let success = TrainingPlan.success(game)
        switch game {
        case .pairMatch:
            TrainingStage(
                game: game,
                engine: TrainingRounds(
                    level: level, range: range,
                    make: { pairs in
                        var rng = SeededRNG()
                        return PairMatchEngine(config: .training(pairs: pairs), rng: &rng)
                    }, success: success), onFinish: done
            ) { e, send in PairMatchBoard(engine: e) { i in send { $0.tap(i) } } }
        case .sequenceEcho:
            TrainingStage(
                game: game,
                engine: TrainingRounds(
                    level: level, range: range,
                    make: { span in
                        SequenceEchoEngine(config: .training(span: span), rng: SeededRNG())
                    }, success: success), onFinish: done
            ) { e, send in SequenceEchoBoard(engine: e) { i in send { $0.tap(i) } } }
        case .nBack:
            TrainingStage(
                game: game,
                engine: TrainingRounds(
                    level: level, range: range,
                    make: { n in
                        var rng = SeededRNG()
                        return NBackEngine(config: .training(n: n), rng: &rng)
                    }, success: success), onFinish: done
            ) { e, send in NBackBoard(engine: e) { m in send { $0.respond(m) } } }
        case .wordRecall:
            TrainingStage(
                game: game,
                engine: TrainingRounds(
                    level: level, range: range,
                    make: { length in
                        WordRecallEngine(config: .training(length: length), rng: SeededRNG())
                    }, success: success), onFinish: done
            ) { e, send in WordRecallBoard(engine: e, send: send) }
        }
    }
}

/// One game's training window: level + time banner over the game's own board.
private struct TrainingStage<Inner: GameEngine, Board: View>: View {
    let game: GameKind
    @State var engine: TrainingRounds<Inner>
    let onFinish: (Outcome) -> Void
    @ViewBuilder let board: (Inner, @escaping Sender<Inner>) -> Board

    var body: some View {
        GamePlayView(engine: $engine, onFinish: onFinish) { rounds, send in
            VStack(spacing: 0) {
                HStack {
                    Label {
                        Text(game.title)
                    } icon: {
                        Image(systemName: game.symbol)
                    }
                    Spacer()
                    Text("Level \(rounds.staircase.level)").monospacedDigit()
                    Text(
                        Duration.seconds(max(0, (rounds.window - rounds.elapsed).seconds).rounded(.up)),
                        format: .time(pattern: .minuteSecond)
                    )
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(game.color)
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
                board(rounds.current) { action in send { $0.act(action) } }
            }
        }
    }
}
