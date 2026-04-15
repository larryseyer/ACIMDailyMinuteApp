import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dailyReminderEnabled") private var reminderEnabled = false
    @AppStorage("dailyReminderTimeInterval") private var reminderTimeInterval: Double = Date().timeIntervalSinceReferenceDate
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true

    private var reminderTime: Date {
        get { Date(timeIntervalSinceReferenceDate: reminderTimeInterval) }
        set { reminderTimeInterval = newValue.timeIntervalSinceReferenceDate }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: reminderTimeInterval) },
            set: { reminderTimeInterval = $0.timeIntervalSinceReferenceDate }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    Toggle("Daily reminder", isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) { _, enabled in
                            handleReminderToggle(enabled: enabled)
                        }
                    DatePicker("Reminder time", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                        .onChange(of: reminderTimeInterval) { _, _ in
                            let newTime = reminderTime
                            guard reminderEnabled else { return }
                            scheduleReminder(at: newTime)
                        }
                    Button("Send test notification") {
                        Task { await NotificationManager.shared.fireTest() }
                    }
                }

                Section("Watched Phrases") {
                    NavigationLink {
                        PhrasesEditorView()
                    } label: {
                        LabeledContent("Manage phrases") {
                            Text("\(PhraseStorage.phrases.count) of \(PhraseStorage.maxPhrases)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Onboarding") {
                    Button("Replay introduction") {
                        hasSeenOnboarding = false
                        dismiss()
                    }
                }

                Section("About") {
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        LabeledContent("Version", value: "\(version) (\(build))")
                    }
                    Text("Sparkly Edition · Teddy Poppe · CIMS lineage")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                #endif
            }
        }
    }

    private func handleReminderToggle(enabled: Bool) {
        if enabled {
            scheduleReminder(at: reminderTime)
        } else {
            Task { await NotificationManager.shared.cancelDailyReminder() }
        }
    }

    private func scheduleReminder(at time: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let h = comps.hour ?? 9
        let m = comps.minute ?? 0
        Task {
            await NotificationManager.shared.requestPermissionIfNeeded()
            await NotificationManager.shared.scheduleDailyReminder(hour: h, minute: m)
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
