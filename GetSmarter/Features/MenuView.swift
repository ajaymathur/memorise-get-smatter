import SwiftData
import SwiftUI

enum Route: Hashable {
    case game(GameKind)
    case play(GameKind, Tier)
    case training
    case leaderboards
    case progress
    case science(GameKind?)
    case settings
}

struct MenuView: View {
    @State private var path: [Route] = []
    @AppStorage(SettingsKey.onboarded) private var onboarded = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    NavigationLink(value: Route.training) {
                        TrainingRow()
                    }
                }
                Section {
                    ForEach(GameKind.allCases) { game in
                        NavigationLink(value: Route.game(game)) {
                            GameRow(game: game)
                        }
                    }
                } header: {
                    Text("Games")
                }
                Section {
                    NavigationLink(value: Route.progress) { Label("Progress", systemImage: "chart.xyaxis.line") }
                    NavigationLink(value: Route.leaderboards) { Label("Leaderboards", systemImage: "trophy") }
                    NavigationLink(value: Route.science(nil)) { Label("The Science", systemImage: "books.vertical") }
                } header: {
                    Text("You")
                }
            }
            .navigationTitle("Get Smarter")
            .onChange(of: path.isEmpty, initial: true) { GameCenterService.shared.showAccessPoint(path.isEmpty) }
            .fullScreenCover(isPresented: .constant(!onboarded)) {
                OnboardingView { onboarded = true }
            }
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
                case .training: DailyTrainingView()
                case .leaderboards: LeaderboardView()
                case .progress: StatsView()
                case .science(let game): ScienceView(game: game)
                case .settings: SettingsView()
                }
            }
        }
    }
}

private struct TrainingRow: View {
    @Query(filter: #Predicate<SessionRecord> { $0.circuitComplete }) private var circuits: [SessionRecord]

    var body: some View {
        let streak = Progression.streak(circuitDates: circuits.map(\.date))
        HStack(spacing: 16) {
            Image(systemName: "figure.mind.and.body")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.gradient, in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text("Daily Training").font(.headline)
                Text("5 minutes · adapts to you").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if streak > 0 {
                Label("\(streak)", systemImage: "flame.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel(Text("\(streak) day streak"))
            }
        }
        .padding(.vertical, 4)
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
        .toolbar {
            NavigationLink(value: Route.science(game)) {
                Label("The Science", systemImage: "info.circle")
            }
        }
    }
}
