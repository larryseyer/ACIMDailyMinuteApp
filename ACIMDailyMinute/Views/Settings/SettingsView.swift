import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dailyReminderEnabled") private var reminderEnabled = false
    @AppStorage("dailyReminderTimeInterval") private var reminderTimeInterval: Double = Date().timeIntervalSinceReferenceDate
    // `false`, matching `ContentView` and `OnboardingView`. An install that has
    // never stored this key has, by definition, not seen the introduction, so
    // `true` was the wrong answer to give — it was inert only because this
    // screen writes the flag and never reads it to decide anything. The first
    // condition in Settings keyed on it would have inherited the disagreement.
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
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

                Section {
                    NavigationLink {
                        BackupRestoreView()
                    } label: {
                        Text("Backup & Restore")
                    }
                } header: {
                    Text("Your Work")
                } footer: {
                    // Nothing can re-send a reader what they wrote: there is no
                    // server and no account. The one copy is on this device
                    // until they make another.
                    Text("Carry your highlights, notes and bookmarks to another device.")
                }

                Section("About") {
                    NavigationLink {
                        CompanionNoteView()
                    } label: {
                        Text("A note about using this app")
                    }
                    // The policy has existed and been unreachable: nothing
                    // linked to it, so the one screen that states the app
                    // collects nothing could not be read from inside the app.
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Text("Privacy Policy")
                    }
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
