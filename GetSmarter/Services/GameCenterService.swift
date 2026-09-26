import GameKit
import SwiftData
import UIKit

/// Game Center: auth, opt-in score submission with an offline queue, achievements (REQ-GC-01..07).
/// GameKit does its own networking; the app never opens a connection itself.
@MainActor @Observable
final class GameCenterService {
    static let shared = GameCenterService()

    private(set) var isAuthenticated = false
    private var authStarted = false

    private init() {}

    static func leaderboardID(_ game: GameKind, _ tier: Tier, weekly: Bool) -> String {
        "lb.\(game.rawValue).\(tier.rawValue).\(weekly ? "weekly" : "alltime")"
    }

    /// Non-blocking; if the player isn't signed in, GameKit supplies a sign-in screen we present once.
    func authenticate(onAuthenticated: @escaping @MainActor () -> Void) {
        guard !authStarted else { return }
        authStarted = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor in
                if let viewController {
                    Self.topViewController()?.present(viewController, animated: true)
                    return
                }
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                if GKLocalPlayer.local.isAuthenticated { onAuthenticated() }
            }
        }
    }

    /// Sends queued ranked scores (REQ-GC-03, REQ-GC-04). Records stay queued on failure.
    func flush(_ context: ModelContext) async {
        guard isAuthenticated,
            UserDefaults.standard.integer(forKey: SettingsKey.shareScores) == ShareChoice.share.rawValue
        else { return }
        let pending =
            (try? context.fetch(FetchDescriptor<SessionRecord>(predicate: #Predicate { $0.pendingSubmit }))) ?? []
        for record in pending {
            guard let game = record.gameKind, let tier = record.tierValue, record.sessionMode == .ranked else {
                record.pendingSubmit = false
                continue
            }
            do {
                try await GKLeaderboard.submitScore(
                    record.score, context: 0, player: GKLocalPlayer.local,
                    leaderboardIDs: [
                        Self.leaderboardID(game, tier, weekly: false), Self.leaderboardID(game, tier, weekly: true),
                    ])
                record.pendingSubmit = false
            } catch {
                break  // likely offline; try again next time
            }
        }
        try? context.save()
    }

    // ponytail: outcome-based achievements earned while offline are not retried; history-based ones are recomputed.
    func report(_ ids: Set<String>) {
        guard isAuthenticated,
            UserDefaults.standard.integer(forKey: SettingsKey.shareScores) == ShareChoice.share.rawValue,
            !ids.isEmpty
        else { return }
        let achievements = ids.map { id in
            let a = GKAchievement(identifier: id)
            a.percentComplete = 100
            a.showsCompletionBanner = true
            return a
        }
        GKAchievement.report(achievements) { _ in }
    }

    /// Access point on the main menu only (REQ-GC-06).
    func showAccessPoint(_ visible: Bool) {
        GKAccessPoint.shared.location = .topLeading
        GKAccessPoint.shared.isActive = visible && isAuthenticated
    }

    func openDashboard() {
        GKAccessPoint.shared.trigger(state: .leaderboards) {}
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

/// Stored in `SettingsKey.shareScores`.
enum ShareChoice: Int {
    case notAsked = 0, share, keepPrivate
}

extension GameCenterService {
    /// After any session: send queued scores and report every achievement earned so far.
    func sync(_ context: ModelContext, latest: Achievements.Latest? = nil) {
        let records = (try? context.fetch(FetchDescriptor<SessionRecord>())) ?? []
        let history = records.compactMap { r in
            r.gameKind.map {
                Achievements.Played(
                    game: $0, tier: r.sessionMode == .training ? nil : r.tierValue, score: r.score,
                    circuitDate: r.circuitComplete ? r.date : nil)
            }
        }
        let levels = Dictionary(
            ((try? context.fetch(FetchDescriptor<TrainingLevel>())) ?? []).compactMap { row in
                GameKind(rawValue: row.game).map { ($0, row.level) }
            }, uniquingKeysWith: max)
        report(Achievements.earned(history: history, latest: latest, trainingLevels: levels))
        Task { await flush(context) }
    }
}
