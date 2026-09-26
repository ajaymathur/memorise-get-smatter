import SwiftUI

struct WordRecallScreen: View {
    let tier: Tier

    var body: some View {
        GameHostView(game: .wordRecall, tier: tier) { mode in
            let config = WordRecallEngine.Config.tier(tier)
            return WordRecallEngine(config: mode == .relaxed ? config.relaxed() : config, rng: SeededRNG())
        } practice: {
            WordRecallEngine(config: .training(length: 4), rng: SeededRNG())
        } board: { engine, send in
            WordRecallBoard(engine: engine, send: send)
        }
    }
}

struct WordRecallBoard: View {
    let engine: WordRecallEngine
    let send: Sender<WordRecallEngine>

    private var color: Color { GameKind.wordRecall.color }

    var body: some View {
        switch engine.phase {
        case .study(let index, _, _):
            VStack(spacing: 24) {
                Text("Word \(index + 1) of \(engine.studied.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(engine.shownWord ?? " ")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(color)
                Spacer()
            }
            .padding()
        case .distractor(let remaining, let current, let options):
            VStack(spacing: 24) {
                Text("Count backward by 3").font(.title2.bold())
                Text("\(Int(remaining.seconds.rounded(.up))) s").font(.headline.monospacedDigit()).foregroundStyle(
                    .secondary)
                Text(current, format: .number.grouping(.never))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                HStack(spacing: 12) {
                    ForEach(options, id: \.self) { value in
                        Button {
                            send { $0.answerDistractor(value) }
                        } label: {
                            Text(value, format: .number.grouping(.never)).font(.title2.monospacedDigit())
                                .frame(maxWidth: .infinity, minHeight: 56)
                        }
                        .buttonStyle(.bordered)
                        .tint(color)
                    }
                }
            }
            .padding()
        case .test, .finished:
            VStack(spacing: 12) {
                Text("Tap every word you studied").font(.headline)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                        ForEach(engine.choices, id: \.self) { word in
                            let on = engine.selected.contains(word)
                            Button {
                                send { $0.toggle(word) }
                            } label: {
                                Text(word)
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(.bordered)
                            .tint(on ? color : .secondary)
                            .overlay(alignment: .topTrailing) {
                                if on {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(color).padding(4)
                                        .accessibilityHidden(true)
                                }
                            }
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal)
                }
                Button {
                    send { $0.done() }
                } label: {
                    Text("Done (\(engine.selected.count) selected)").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(color)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}
