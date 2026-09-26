import SwiftData
import SwiftUI

@main
struct GetSmarterApp: App {
    /// UI tests pass `-uitest` for a clean in-memory store.
    private let isUITest = ProcessInfo.processInfo.arguments.contains("-uitest")
    /// Hosting unit tests: skip CloudKit and the UI so tests run against a quiet app.
    private let isUnitTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.onboarded) private var onboarded = false

    init() {
        container = .app(inMemory: isUITest || isUnitTest)
        if isUITest, let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
        if isUITest && ProcessInfo.processInfo.arguments.contains("-demo") { Self.seedDemo(container.mainContext) }
        SoundPlayer.shared.isEnabled = UserDefaults.standard.object(forKey: SettingsKey.soundOn) as? Bool ?? true
    }

    var body: some Scene {
        WindowGroup {
            if !isUnitTest {
                MenuView()
                    .onChange(of: onboarded, initial: true) {
                        guard onboarded, !isUITest else { return }
                        GameCenterService.shared.authenticate { GameCenterService.shared.sync(container.mainContext) }
                    }
                    .onChange(of: scenePhase) {
                        if scenePhase == .active { GameCenterService.shared.sync(container.mainContext) }
                    }
            }
        }
        .modelContainer(container)
    }

    /// Sample history for App Store screenshots.
    private static func seedDemo(_ context: ModelContext) {
        var rng = SeededRNG(seed: 2026)
        for day in 0..<21 {
            let date = Calendar.current.date(byAdding: .day, value: -day, to: .now)!
            for game in GameKind.allCases {
                let base = [GameKind.pairMatch: 700, .sequenceEcho: 450, .nBack: 550, .wordRecall: 600][game]!
                let record = SessionRecord(
                    game: game, tier: .beginner, mode: .ranked,
                    score: base + (21 - day) * 12 + Int.random(in: 0...80, using: &rng),
                    accuracy: 0.8)
                record.date = date
                context.insert(record)
            }
            if day < 9 {
                let circuit = SessionRecord(game: .nBack, tier: nil, mode: .training, score: 3, accuracy: 0.7)
                circuit.date = date
                circuit.circuitComplete = true
                context.insert(circuit)
            }
        }
        try? context.save()
    }
}
