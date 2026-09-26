import SwiftUI

struct SequenceEchoScreen: View {
    let tier: Tier

    var body: some View {
        GameHostView(game: .sequenceEcho, tier: tier) { mode in
            let config = SequenceEchoEngine.Config.tier(tier)
            return SequenceEchoEngine(config: mode == .relaxed ? config.relaxed() : config, rng: SeededRNG())
        } board: { engine, send in
            SequenceEchoBoard(engine: engine) { i in send { $0.tap(i) } }
        }
    }
}

struct SequenceEchoBoard: View {
    let engine: SequenceEchoEngine
    let tap: (Int) -> Void

    private var status: Text {
        switch engine.phase {
        case .playback: Text("Watch…")
        case .input: engine.config.backward ? Text("Your turn: reverse order") : Text("Your turn")
        case .feedback(let correct, _): correct ? Text("Correct!") : Text("Not quite")
        case .finished: Text("")
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Span \(engine.span)")
                Spacer()
                status.foregroundStyle(GameKind.sequenceEcho.color)
                Spacer()
                Text("Trial \(min(engine.trialInSpan + 1, 2))/2").opacity(engine.config.singleTrial ? 0 : 1)
            }
            .font(.headline.monospacedDigit())
            .padding(.horizontal)

            GeometryReader { geo in
                let n = engine.config.side
                let spacing: CGFloat = 10
                let side = (min(geo.size.width, geo.size.height) - spacing * CGFloat(n - 1)) / CGFloat(n)
                Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                    ForEach(0..<n, id: \.self) { r in
                        GridRow {
                            ForEach(0..<n, id: \.self) { c in
                                let i = r * n + c
                                TileView(
                                    index: i, lit: engine.litTile == i,
                                    enabled: engine.phase == .input
                                ) { tap(i) }
                                .frame(width: side, height: side)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal)

            Text("\(engine.entered.count)/\(engine.sequence.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .opacity(engine.phase == .input ? 1 : 0)
                .accessibilityHidden(engine.phase != .input)
        }
        .padding(.vertical)
    }
}

private struct TileView: View {
    let index: Int
    let lit: Bool
    let enabled: Bool
    let tap: () -> Void
    @State private var pressed = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            pressed += 1
            tap()
        } label: {
            RoundedRectangle(cornerRadius: 16)
                .fill(Faces.color(index).opacity(lit ? 1 : 0.25))
                .overlay(
                    Image(systemName: Faces.symbol(index))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(lit ? .white : Faces.color(index))
                )
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.primary.opacity(lit ? 0.8 : 0), lineWidth: 4))
                .scaleEffect(lit && !reduceMotion ? 1.06 : 1)
                .animation(.easeOut(duration: 0.12), value: lit)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text(Faces.name(index)))
        .accessibilityHint(enabled ? Text("") : Text("Wait for the sequence to finish"))
    }
}
