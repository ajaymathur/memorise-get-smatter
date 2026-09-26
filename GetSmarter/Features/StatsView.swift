import Charts
import SwiftData
import SwiftUI

/// Personal bests per game/tier, score trend, and training streak (REQ-UX-02).
struct StatsView: View {
    @Query(sort: \SessionRecord.date) private var records: [SessionRecord]
    @State private var game = GameKind.pairMatch

    private var ranked: [SessionRecord] { records.filter { $0.sessionMode != .training } }

    var body: some View {
        List {
            Section {
                let streak = Progression.streak(circuitDates: records.filter(\.circuitComplete).map(\.date))
                LabeledContent("Training streak") {
                    Label("\(streak) days", systemImage: "flame.fill").foregroundStyle(.orange)
                }
                LabeledContent("Games played", value: records.count, format: .number)
            }
            Section("Personal bests") {
                Grid(alignment: .leading, verticalSpacing: 8) {
                    GridRow {
                        Text("")
                        ForEach(Tier.allCases) { Text($0.title).font(.caption).foregroundStyle(.secondary) }
                    }
                    ForEach(GameKind.allCases) { g in
                        GridRow {
                            Text(g.title).font(.subheadline)
                            ForEach(Tier.allCases) { t in
                                let best = ranked.filter { $0.gameKind == g && $0.tierValue == t }.map(\.score).max()
                                Text(best.map { "\($0)" } ?? "–").monospacedDigit()
                                    .accessibilityLabel(
                                        Text(
                                            "\(Text(g.title)) \(Text(t.title)): \(best.map { "\($0)" } ?? "not played")"
                                        ))
                            }
                        }
                    }
                }
            }
            Section("Score history") {
                Picker("Game", selection: $game) {
                    ForEach(GameKind.allCases) { Text($0.title).tag($0) }
                }
                let points = ranked.filter { $0.gameKind == game }
                if points.isEmpty {
                    Text("Play \(Text(game.title)) to see your scores here.").foregroundStyle(.secondary)
                } else {
                    Chart(points) { r in
                        PointMark(x: .value("Date", r.date), y: .value("Score", r.score))
                            .foregroundStyle(by: .value("Level", String(localized: r.tierValue?.title ?? "")))
                            .symbol(by: .value("Level", String(localized: r.tierValue?.title ?? "")))
                    }
                    .frame(height: 220)
                }
            }
        }
        .navigationTitle("Progress")
    }
}
