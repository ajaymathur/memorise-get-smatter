import Foundation
import SwiftData

// CloudKit-compatible (REQ-DS-01): every property defaulted, no unique constraints.

@Model
final class SessionRecord {
    var id: UUID = UUID()
    var game: String = ""
    var tier: String = ""
    var mode: String = SessionMode.ranked.rawValue
    var score: Int = 0
    var accuracy: Double = 0
    var date: Date = Date.now
    var circuitComplete: Bool = false
    /// Ranked + opted in, not yet sent to Game Center (REQ-GC-04).
    var pendingSubmit: Bool = false

    init(game: GameKind, tier: Tier?, mode: SessionMode, score: Int, accuracy: Double) {
        self.game = game.rawValue
        self.tier = tier?.rawValue ?? ""
        self.mode = mode.rawValue
        self.score = score
        self.accuracy = accuracy
    }

    var gameKind: GameKind? { GameKind(rawValue: game) }
    var tierValue: Tier? { Tier(rawValue: tier) }
    var sessionMode: SessionMode { SessionMode(rawValue: mode) ?? .ranked }
}

@Model
final class TrainingLevel {
    var game: String = ""
    var level: Int = 1
    var updatedAt: Date = Date.now

    init(game: GameKind, level: Int) {
        self.game = game.rawValue
        self.level = level
    }
}

extension ModelContainer {
    /// Syncs through the user's private CloudKit database when available; otherwise local only.
    static func app(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([SessionRecord.self, TrainingLevel.self])
        let config =
            inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Never block the game on sync problems: fall back to a local store.
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: local)
        }
    }
}

extension ModelContext {
    /// Newest level per game wins when sync produced duplicates (design.md §6).
    func trainingLevel(for game: GameKind, default initial: Int) -> TrainingLevel {
        let id = game.rawValue
        let rows = (try? fetch(FetchDescriptor<TrainingLevel>(predicate: #Predicate { $0.game == id }))) ?? []
        let sorted = rows.sorted { $0.updatedAt > $1.updatedAt }
        if let newest = sorted.first {
            sorted.dropFirst().forEach(delete)
            return newest
        }
        let row = TrainingLevel(game: game, level: initial)
        insert(row)
        return row
    }
}
