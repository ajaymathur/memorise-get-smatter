import Foundation

/// Achievement rules (design.md §7). History-based ones are recomputed every time;
/// outcome-based ones are judged on the game just finished.
enum Achievements {
    struct Played: Sendable {
        var game: GameKind
        var tier: Tier?
        var score: Int
        var circuitDate: Date?
    }

    struct Latest: Sendable {
        var game: GameKind
        var tier: Tier
        var outcome: Outcome
    }

    static func earned(
        history: [Played], latest: Latest?, trainingLevels: [GameKind: Int],
        today: Date = .now, calendar: Calendar = .current
    ) -> Set<String> {
        var ids: Set<String> = []
        if !history.isEmpty { ids.insert("ach.first_game") }
        if Set(history.map(\.game)).count == GameKind.allCases.count { ids.insert("ach.all_games") }

        let streak = Progression.streak(
            circuitDates: history.compactMap(\.circuitDate), today: today, calendar: calendar)
        if streak >= 3 { ids.insert("ach.streak_3") }
        if streak >= 7 { ids.insert("ach.streak_7") }
        if streak >= 30 { ids.insert("ach.streak_30") }

        if (trainingLevels[.nBack] ?? 0) >= 3 { ids.insert("ach.nback_3") }

        // Earned unlocks only, never the "Unlock all" setting.
        let expertUnlocked = GameKind.allCases.contains { game in
            let entries = history.filter { $0.game == game }.compactMap { p in
                p.tier.map { Progression.Entry(tier: $0, score: p.score) }
            }
            return Progression.isUnlocked(.expert, game: game, history: entries, unlockAll: false)
        }
        if expertUnlocked { ids.insert("ach.expert") }

        if let latest {
            let stats = latest.outcome.stats
            switch latest.game {
            case .pairMatch where stats["completed"] == 1 && stats["extraMoves"] == 0:
                ids.insert("ach.perfect_pairs")
            case .sequenceEcho where (stats["maxSpan"] ?? 0) >= 7:
                ids.insert("ach.span_7")
            case .wordRecall where latest.tier != .beginner && stats["luresPicked"] == 0 && latest.outcome.score > 0:
                ids.insert("ach.lure_proof")
            default: break
            }
        }
        return ids
    }
}
