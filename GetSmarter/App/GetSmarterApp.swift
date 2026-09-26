import SwiftData
import SwiftUI

@main
struct GetSmarterApp: App {
    /// UI tests pass `-uitest` for a clean in-memory store.
    private let isUITest = ProcessInfo.processInfo.arguments.contains("-uitest")
    private let container: ModelContainer

    init() {
        container = .app(inMemory: isUITest)
        if isUITest, let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
        SoundPlayer.shared.isEnabled = UserDefaults.standard.object(forKey: SettingsKey.soundOn) as? Bool ?? true
    }

    var body: some Scene {
        WindowGroup {
            MenuView()
        }
        .modelContainer(container)
    }
}
