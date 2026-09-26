import SwiftData
import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.soundOn) private var soundOn = true
    @AppStorage(SettingsKey.hapticsOn) private var hapticsOn = true
    @AppStorage(SettingsKey.relaxedTiming) private var relaxedTiming = false
    @AppStorage(SettingsKey.unlockAll) private var unlockAll = false
    @AppStorage(SettingsKey.shareScores) private var shareScores = ShareChoice.notAsked.rawValue
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
                Button("Reset progress", role: .destructive) { confirmReset = true }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: soundOn, initial: true) { SoundPlayer.shared.isEnabled = soundOn }
        .confirmationDialog(
            "Delete all scores and progress on all your devices?", isPresented: $confirmReset, titleVisibility: .visible
        ) {
            Button("Reset progress", role: .destructive, action: reset)
        }
    }

    private func reset() {
        try? context.delete(model: SessionRecord.self)
        try? context.delete(model: TrainingLevel.self)
        try? context.save()
    }
}
