import SwiftUI

struct PairMatchScreen: View {
    let tier: Tier

    var body: some View {
        GameHostView(game: .pairMatch, tier: tier) { mode in
            var rng = SeededRNG()
            let config = PairMatchEngine.Config.tier(tier)
            return PairMatchEngine(config: mode == .relaxed ? config.relaxed() : config, rng: &rng)
        } board: { engine, send in
            PairMatchBoard(engine: engine) { i in send { $0.tap(i) } }
        }
    }
}

struct PairMatchBoard: View {
    let engine: PairMatchEngine
    let tap: (Int) -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("\(engine.pairsFound)/\(engine.config.pairs)", systemImage: "square.on.square")
                    .accessibilityLabel(Text("\(engine.pairsFound) of \(engine.config.pairs) pairs found"))
                Spacer()
                if case .preview = engine.phase {
                    Text("Memorise!").font(.headline).foregroundStyle(GameKind.pairMatch.color)
                }
                Spacer()
                Label {
                    Text(Duration.seconds(engine.timeLeft.seconds.rounded(.up)), format: .time(pattern: .minuteSecond))
                } icon: {
                    Image(systemName: "timer")
                }
                .accessibilityLabel(Text("\(Int(engine.timeLeft.seconds)) seconds left"))
            }
            .font(.headline.monospacedDigit())
            .padding(.horizontal)

            GeometryReader { geo in
                let cols = engine.config.cols
                let rows = engine.config.rows
                let spacing: CGFloat = 8
                let side = min(
                    (geo.size.width - spacing * CGFloat(cols - 1)) / CGFloat(cols),
                    (geo.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows))
                Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                    ForEach(0..<rows, id: \.self) { r in
                        GridRow {
                            ForEach(0..<cols, id: \.self) { c in
                                let i = r * cols + c
                                if engine.cards.indices.contains(i) {
                                    CardView(card: engine.cards[i], row: r + 1, column: c + 1) { tap(i) }
                                        .frame(width: side, height: side)
                                } else {
                                    Color.clear.frame(width: side, height: side)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

private struct CardView: View {
    let card: PairMatchEngine.Card
    let row: Int
    let column: Int
    let tap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var faceUp: Bool { card.state != .hidden }

    var body: some View {
        Button(action: tap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(GameKind.pairMatch.color.gradient)
                    .overlay(
                        Image(systemName: "questionmark").font(.title2.bold()).foregroundStyle(.white.opacity(0.7))
                    )
                    .opacity(faceUp ? 0 : 1)
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background.secondary)
                    .overlay(
                        Image(systemName: Faces.symbol(card.face))
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Faces.color(card.face))
                            .minimumScaleFactor(0.5)
                    )
                    .overlay(alignment: .topTrailing) {
                        if card.state == .matched {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).padding(4)
                        }
                    }
                    .opacity(faceUp ? 1 : 0)
                    .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (0, 1, 0))
            }
            .rotation3DEffect(.degrees(faceUp && !reduceMotion ? 180 : 0), axis: (0, 1, 0))
            .opacity(card.state == .matched ? 0.6 : 1)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35), value: card.state)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(card.state == .hidden ? [] : .isStaticText)
    }

    private var label: Text {
        switch card.state {
        case .hidden: Text("Row \(row), column \(column), face down")
        case .revealed: Text(Faces.name(card.face))
        case .matched: Text("\(Faces.name(card.face)), matched")
        }
    }
}
