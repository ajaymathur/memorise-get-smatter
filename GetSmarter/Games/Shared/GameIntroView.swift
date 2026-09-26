import SwiftUI

extension GameKind {
    var howToPlay: LocalizedStringResource {
        switch self {
        case .pairMatch:
            "Memorise the cards, then flip two at a time to find matching pairs. Fewer flips and faster finishes score more."
        case .sequenceEcho:
            "Watch the tiles light up, then tap them in the same order. On Expert, tap them in reverse order."
        case .nBack:
            "Squares appear one at a time. Tap Position when the square is in the same place as N steps ago. On Expert, also tap Sound when the letter matches."
        case .wordRecall:
            "Study the words as they appear. Then tap every word you saw. Watch out for words that only feel familiar."
        }
    }
}

struct GameIntroView: View {
    let game: GameKind
    let tier: Tier
    let relaxed: Bool
    let tutorialSeen: Bool
    let practice: () -> Void
    let start: () -> Void
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: game.symbol)
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                    .frame(width: 112, height: 112)
                    .background(game.color.gradient, in: .rect(cornerRadius: 28))
                    .accessibilityHidden(true)
                VStack(spacing: 4) {
                    Text(game.title).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(tier.title).font(.title3).foregroundStyle(.secondary)
                }
                Text(game.howToPlay)
                    .multilineTextAlignment(.center)
                if voiceOver && !relaxed {
                    Label("Tip: turn on Relaxed timing in Settings for more time.", systemImage: "tortoise")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if relaxed {
                    Label("Relaxed timing is on. This game won't be posted to leaderboards.", systemImage: "tortoise")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 12) {
                    if tutorialSeen {
                        Button(action: start) { Text("Start").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent)
                        Button(action: practice) { Text("Practice round").frame(maxWidth: .infinity) }
                            .buttonStyle(.bordered)
                    } else {
                        Button(action: practice) { Text("Try a practice round").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent)
                        Button(action: start) { Text("Skip to game").frame(maxWidth: .infinity) }
                            .buttonStyle(.bordered)
                    }
                }
                .controlSize(.large)
                .tint(game.color)
            }
            .padding()
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
    }
}
