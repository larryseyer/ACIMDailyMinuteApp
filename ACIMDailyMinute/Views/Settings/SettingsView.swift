import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dailyReminderEnabled") private var reminderEnabled = false
    @AppStorage("dailyReminderTimeInterval") private var reminderTimeInterval: Double = Date().timeIntervalSinceReferenceDate
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true
    @AppStorage("notifyNewMinute") private var notifyNewMinute = true
    @AppStorage("notifyNewLesson") private var notifyNewLesson = true
    @AppStorage("notifyPhraseMatches") private var notifyPhraseMatches = true

    /// Bound to the defaults key `PhraseStorage` writes. The count used to be
    /// read straight off `PhraseStorage.phrases`, which is a plain `static`
    /// accessor — SwiftUI had no dependency on it, so adding a phrase never
    /// redrew this label and it sat at "0 of 10" forever.
    @AppStorage("watchedPhrases") private var watchedPhrasesData = Data()

    private var phraseCount: Int {
        _ = watchedPhrasesData
        return PhraseStorage.phrases.count
    }

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

                Section {
                    Toggle("New Daily Minute", isOn: $notifyNewMinute)
                    Toggle("New Daily Lesson", isOn: $notifyNewLesson)
                    Toggle("Watched phrase matches", isOn: $notifyPhraseMatches)
                } header: {
                    Text("Alert me about")
                } footer: {
                    Text("Checked when the app opens and, when iOS allows it, in the background.")
                }

                Section("Watched Phrases") {
                    NavigationLink {
                        PhrasesEditorView()
                    } label: {
                        LabeledContent("Manage phrases") {
                            Text("\(phraseCount) of \(PhraseStorage.maxPhrases)")
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
                    Text("ACIM Sparkly Edition · Teddy Poppe · CIMS lineage")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .readableContentWidth()
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
