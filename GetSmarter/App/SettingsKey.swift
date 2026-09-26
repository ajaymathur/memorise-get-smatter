/// `@AppStorage` keys (local only, REQ-DS-03).
enum SettingsKey {
    static let soundOn = "soundOn"
    static let hapticsOn = "hapticsOn"
    static let relaxedTiming = "relaxedTiming"
    static let unlockAll = "unlockAll"
    /// 0 = not asked, 1 = share, 2 = keep private (REQ-GC-02).
    static let shareScores = "shareScores"
    static let reminderOn = "reminderOn"
    static let reminderMinutes = "reminderMinutes"
    static let onboarded = "onboarded"
    static let lastReviewRequest = "lastReviewRequest"
    static func tutorialSeen(_ game: GameKind) -> String { "tutorialSeen.\(game.rawValue)" }
}
