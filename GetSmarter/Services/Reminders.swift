import UserNotifications

/// Optional daily local reminder (REQ-UX-03). On-device only; no push server.
enum Reminders {
    private static let id = "daily-training"

    /// Asks permission the first time; returns false if the user declined.
    static func enable(minutes: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return false }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time for Daily Training")
        content.body = String(localized: "Five minutes of memory games. Keep your streak going!")
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60), repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        return true
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
