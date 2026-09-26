import SwiftUI

struct NBackScreen: View {
    let tier: Tier

    var body: some View {
        GameHostView(game: .nBack, tier: tier) { mode in
            var rng = SeededRNG()
            let config = NBackEngine.Config.tier(tier)
            return NBackEngine(config: mode == .relaxed ? config.relaxed() : config, rng: &rng)
        } board: { engine, send in
            NBackBoard(engine: engine) { m in send { $0.respond(m) } }
        }
    }
}

struct NBackBoard: View {
    let engine: NBackEngine
    let respond: (NBackEngine.Modality) -> Void

    private var color: Color { GameKind.nBack.color }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("\(engine.config.n)-back")
                Spacer()
                if engine.isRunning {
                    Text("\(engine.index + 1)/\(engine.config.trials)")
                } else if engine.outcome == nil {
                    Text("Get ready…").foregroundStyle(color)
                }
            }
            .font(.headline.monospacedDigit())
            .padding(.horizontal)

            GeometryReader { geo in
                let spacing: CGFloat = 10
                let side = (min(geo.size.width, geo.size.height) - spacing * 2) / 3
                Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
                    ForEach(0..<3, id: \.self) { r in
                        GridRow {
                            ForEach(0..<3, id: \.self) { c in
                                let cell = r * 3 + c
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        engine.visibleCell == cell
                                            ? AnyShapeStyle(color.gradient) : AnyShapeStyle(.fill.tertiary)
                                    )
                                    .overlay {
                                        if cell == 4 {
                                            Image(systemName: "plus").foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(width: side, height: side)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    engine.visibleCell.map { Text(NBackEngine.positionName($0)) } ?? Text("Grid"))
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                MatchButton(
                    title: "Position match", symbol: "square.grid.3x3.middle.filled",
                    done: engine.responded.contains(.position)
                ) { respond(.position) }
                if engine.config.dual {
                    MatchButton(
                        title: "Sound match", symbol: "speaker.wave.2.fill", done: engine.responded.contains(.sound)
                    ) {
                        respond(.sound)
                    }
                }
            }
            .disabled(!engine.isRunning)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

private struct MatchButton: View {
    let title: LocalizedStringResource
    let symbol: String
    let done: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: done ? "checkmark" : symbol)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(.borderedProminent)
        .tint(done ? .secondary : GameKind.nBack.color)
        .accessibilityValue(done ? Text("Answered") : Text(""))
    }
}
