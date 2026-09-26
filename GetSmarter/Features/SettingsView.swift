import SwiftData
import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.soundOn) private var soundOn = true
    @AppStorage(SettingsKey.hapticsOn) private var hapticsOn = true
    @AppStorage(SettingsKey.relaxedTiming) private var relaxedTiming = false
    @AppStorage(SettingsKey.unlockAll) private var unlockAll = false
    @AppStorage(SettingsKey.shareScores) private var shareScores = ShareChoice.notAsked.rawValue
    @AppStorage(SettingsKey.reminderOn) private var reminderOn = false
    @AppStorage(SettingsKey.reminderMinutes) private var reminderMinutes = 19 * 60
    @Environment(\.modelContext) private var context
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Feedback") {
                Toggle("Sound", isOn: $soundOn)
                Toggle("Haptics", isOn: $hapticsOn)
            }
            Section {
                Toggle("Relaxed timing", isOn: $relaxedTiming)
                Toggle("Unlock all levels", isOn: $unlockAll)
            } header: {
                Text("Gameplay")
            } footer: {
                Text("Relaxed timing gives 50% more time. Relaxed games are not posted to leaderboards.")
            }
            Section {
                Toggle(
                    "Share scores on leaderboards",
                    isOn: Binding(
                        get: { shareScores == ShareChoice.share.rawValue },
                        set: { shareScores = ($0 ? ShareChoice.share : .keepPrivate).rawValue }))
            } header: {
                Text("Game Center")
            } footer: {
                Text("When on, your best ranked scores and achievements are posted to Game Center under your nickname.")
            }
            Section {
                Toggle("Daily reminder", isOn: $reminderOn)
                if reminderOn {
                    DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Reminder")
            } footer: {
                Text("A local notification reminding you to do Daily Training. Nothing leaves your device.")
            }
            Section("About") {
                NavigationLink(value: Route.science(nil)) { Text("The Science") }
                Link("Privacy Policy", destination: Links.privacy)
                Link("Support", destination: Links.support)
                LabeledContent(
                    "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
            }
            Section {
                Button("Reset progress", role: .destructive) { confirmReset = true }
            } footer: {
                Text("For entertainment and education only. Not a medical product.")
            }
        }
        .navigationTitle("Settings")
        .onChange(of: soundOn, initial: true) { SoundPlayer.shared.isEnabled = soundOn }
        .onChange(of: reminderOn) { Task { await scheduleReminder() } }
        .onChange(of: reminderMinutes) { Task { await scheduleReminder() } }
        .confirmationDialog(
            "Delete all scores and progress on all your devices?", isPresented: $confirmReset, titleVisibility: .visible
        ) {
            Button("Reset progress", role: .destructive, action: reset)
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now)!
            },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                reminderMinutes = (c.hour ?? 19) * 60 + (c.minute ?? 0)
            })
    }

    /// Permission is requested only when the user turns the reminder on (REQ-UX-03).
    private func scheduleReminder() async {
        Reminders.disable()
        if reminderOn, await !Reminders.enable(minutes: reminderMinutes) { reminderOn = false }
    }

    private func reset() {
        try? context.delete(model: SessionRecord.self)
        try? context.delete(model: TrainingLevel.self)
        try? context.save()
    }
}
