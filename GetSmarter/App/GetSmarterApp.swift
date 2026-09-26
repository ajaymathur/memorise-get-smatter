import SwiftData
import SwiftUI

@main
struct GetSmarterApp: App {
    /// UI tests pass `-uitest` for a clean in-memory store.
    private let isUITest = ProcessInfo.processInfo.arguments.contains("-uitest")
    /// Hosting unit tests: skip CloudKit and the UI so tests run against a quiet app.
    private let isUnitTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    private let container: ModelContainer

    init() {
        container = .app(inMemory: isUITest || isUnitTest)
        if isUITest, let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
        SoundPlayer.shared.isEnabled = UserDefaults.standard.object(forKey: SettingsKey.soundOn) as? Bool ?? true
    }

    var body: some Scene {
        WindowGroup {
            if !isUnitTest {
                MenuView()
            }
        }
        .modelContainer(container)
    }
}
