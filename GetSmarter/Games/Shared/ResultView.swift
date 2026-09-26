import StoreKit
import SwiftData
import SwiftUI

struct ResultView: View {
    let game: GameKind
    let tier: Tier
    let mode: SessionMode
    let outcome: Outcome
    let isPersonalBest: Bool
    let playAgain: () -> Void
    let done: () -> Void

    @Query private var records: [SessionRecord]
    @Environment(\.requestReview) private var requestReview
    @AppStorage(SettingsKey.lastReviewRequest) private var lastReviewRequest = 0.0

    init(
        game: GameKind, tier: Tier, mode: SessionMode, outcome: Outcome, isPersonalBest: Bool,
        playAgain: @escaping () -> Void, done: @escaping () -> Void
    ) {
        (self.game, self.tier, self.mode, self.outcome, self.isPersonalBest) = (
            game, tier, mode, outcome, isPersonalBest
        )
        (self.playAgain, self.done) = (playAgain, done)
        let id = game.rawValue
        _records = Query(filter: #Predicate<SessionRecord> { $0.game == id && $0.mode != "training" })
    }

    private var suggestion: Tier? {
        let history = records.compactMap { r in r.tierValue.map { Progression.Entry(tier: $0, score: r.score) } }
        return Progression.suggestion(game: game, current: tier, history: history)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isPersonalBest {
                    Label("New personal best!", systemImage: "trophy.fill")
                        .font(.headline)
                        .foregroundStyle(game.color)
                }
                VStack {
                    Text("Score").font(.headline).foregroundStyle(.secondary)
                    Text(outcome.score, format: .number)
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                Text("Accuracy \(outcome.accuracy, format: .percent.precision(.fractionLength(0)))")
                    .font(.title3)
                if mode == .relaxed {
                    Text("Relaxed timing: not posted to leaderboards.").font(.footnote).foregroundStyle(.secondary)
                }
                if let suggestion {
                    Label("You're ready for \(Text(suggestion.title))!", systemImage: "arrow.up.circle.fill")
                        .foregroundStyle(game.color)
                }
                VStack(spacing: 12) {
                    Button(action: playAgain) { Text("Play again").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                        .tint(game.color)
                    Button(action: done) { Text("Done").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding()
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .task {
            let now = Date.now.timeIntervalSince1970
            guard isPersonalBest, now - lastReviewRequest > 30 * 86_400 else { return }
            try? await Task.sleep(for: .seconds(1.5))
            lastReviewRequest = now
            requestReview()
        }
    }
}
