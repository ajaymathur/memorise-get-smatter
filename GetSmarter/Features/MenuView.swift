import SwiftData
import SwiftUI

enum Route: Hashable {
    case game(GameKind)
    case play(GameKind, Tier)
    case settings
}

struct MenuView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(GameKind.allCases) { game in
                        NavigationLink(value: Route.game(game)) {
                            GameRow(game: game)
                        }
                    }
                } header: {
                    Text("Games")
                }
            }
            .navigationTitle("Get Smarter")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.settings) {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .game(let game): GameDetailView(game: game)
                case .play(let game, let tier): GameScreen(game: game, tier: tier)
                case .settings: SettingsView()
                }
            }
        }
    }
}

private struct GameRow: View {
    let game: GameKind

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: game.symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(game.color.gradient, in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(game.title).font(.headline)
                Text(game.skill).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct GameDetailView: View {
    let game: GameKind
    @Query private var records: [SessionRecord]
    @AppStorage(SettingsKey.unlockAll) private var unlockAll = false

    init(game: GameKind) {
        self.game = game
        let id = game.rawValue
        _records = Query(filter: #Predicate<SessionRecord> { $0.game == id && $0.mode != "training" })
    }

    private var history: [Progression.Entry] {
        records.compactMap { r in r.tierValue.map { Progression.Entry(tier: $0, score: r.score) } }
    }

    var body: some View {
        List {
            Section {
                ForEach(Tier.allCases) { tier in
                    let unlocked = Progression.isUnlocked(tier, game: game, history: history, unlockAll: unlockAll)
                    let best = history.filter { $0.tier == tier }.map(\.score).max()
                    NavigationLink(value: Route.play(game, tier)) {
                        HStack {
                            Label {
                                Text(tier.title)
                            } icon: {
                                Image(systemName: unlocked ? "play.circle.fill" : "lock.fill")
                                    .foregroundStyle(unlocked ? game.color : .secondary)
                            }
                            Spacer()
                            if let best {
                                Text("Best \(best)").monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(!unlocked)
                    .accessibilityHint(
                        unlocked
                            ? Text("")
                            : Text(
                                "Locked. Score \(Progression.threshold(game, tier == .expert ? .advanced : .beginner)) on the previous tier to unlock."
                            ))
                }
            } header: {
                Text("Choose a level")
            } footer: {
                Text(game.skill)
            }
        }
        .navigationTitle(Text(game.title))
    }
}
