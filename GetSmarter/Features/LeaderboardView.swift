import GameKit
import SwiftUI

/// In-app leaderboard: game + tier, Global/Friends, All time/This week, top 25 + your rank (REQ-GC-05).
struct LeaderboardView: View {
    @State private var game = GameKind.pairMatch
    @State private var tier = Tier.beginner
    @State private var friendsOnly = false
    @State private var weekly = false
    @State private var rows: [Row] = []
    @State private var me: Row?
    @State private var state = LoadState.loading
    private let gameCenter = GameCenterService.shared

    struct Row: Identifiable, Equatable {
        var id: String
        var rank: Int
        var name: String
        var score: String
        var isMe: Bool
    }

    enum LoadState: Equatable { case loading, loaded, failed }

    var body: some View {
        List {
            Section {
                Picker("Game", selection: $game) {
                    ForEach(GameKind.allCases) { Text($0.title).tag($0) }
                }
                Picker("Level", selection: $tier) {
                    ForEach(Tier.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Players", selection: $friendsOnly) {
                    Text("Global").tag(false)
                    Text("Friends").tag(true)
                }
                .pickerStyle(.segmented)
                Picker("Period", selection: $weekly) {
                    Text("All time").tag(false)
                    Text("This week").tag(true)
                }
                .pickerStyle(.segmented)
            }
            if !gameCenter.isAuthenticated {
                ContentUnavailableView {
                    Label("Sign in to Game Center", systemImage: "person.crop.circle.badge.questionmark")
                } description: {
                    Text(
                        "Leaderboards need Game Center. You can sign in from the Settings app. Everything else works without it."
                    )
                }
            } else {
                Section {
                    switch state {
                    case .loading: ProgressView().frame(maxWidth: .infinity)
                    case .failed:
                        Text("Couldn't load scores. Check your connection and try again.").foregroundStyle(.secondary)
                    case .loaded where rows.isEmpty: Text("No scores yet. Be the first!").foregroundStyle(.secondary)
                    case .loaded: ForEach(rows) { RowView(row: $0) }
                    }
                } footer: {
                    if let me, !rows.contains(me) {
                        RowView(row: me).padding(.top, 8)
                    }
                }
                Section {
                    Button("Open in Game Center", systemImage: "gamecontroller") { gameCenter.openDashboard() }
                }
            }
        }
        .navigationTitle("Leaderboards")
        .task(id: [game.rawValue, tier.rawValue, "\(friendsOnly)", "\(weekly)", "\(gameCenter.isAuthenticated)"]) {
            await load()
        }
    }

    private func load() async {
        guard gameCenter.isAuthenticated else { return }
        state = .loading
        do {
            let id = GameCenterService.leaderboardID(game, tier, weekly: weekly)
            guard let board = try await GKLeaderboard.loadLeaderboards(IDs: [id]).first else {
                rows = []
                state = .loaded
                return
            }
            let (local, entries, _) = try await board.loadEntries(
                for: friendsOnly ? .friendsOnly : .global, timeScope: .allTime, range: NSRange(location: 1, length: 25))
            let myID = GKLocalPlayer.local.gamePlayerID
            func row(_ e: GKLeaderboard.Entry) -> Row {
                Row(
                    id: e.player.gamePlayerID, rank: e.rank, name: e.player.displayName, score: e.formattedScore,
                    isMe: e.player.gamePlayerID == myID)
            }
            rows = entries.map(row)
            me = local.map(row)
            state = .loaded
        } catch {
            state = .failed
        }
    }
}

private struct RowView: View {
    let row: LeaderboardView.Row

    var body: some View {
        HStack {
            Text("\(row.rank)").monospacedDigit().foregroundStyle(.secondary).frame(minWidth: 32, alignment: .leading)
            Text(row.name).fontWeight(row.isMe ? .bold : .regular)
            if row.isMe { Text("(you)").foregroundStyle(.secondary) }
            Spacer()
            Text(row.score).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
