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
    /// The same key `SharedModelContainer` reads when it decides whether to
    /// build the reader store with mirroring, named from there so the two
    /// can never drift apart. Written here, acted on at the next launch.
    @AppStorage(SharedModelContainer.syncEnabledKey) private var iCloudSyncEnabled = false
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
                    Toggle("Sync with iCloud", isOn: $iCloudSyncEnabled)
                } header: {
                    Text("Your Work")
                } footer: {
                    // Three things the reader has to know BEFORE they flip it,
                    // which is why they are here rather than in the privacy
                    // policy.
                    //
                    // The middle one matters most: a file restore is strictly
                    // additive, because a backup is a snapshot and an absence in
                    // it carries no information. iCloud is a live sync and
                    // deletes really do travel. That is a genuine behavioural
                    // difference between the two ways of carrying work, and a
                    // reader should meet it here rather than discover it after a
                    // mark disappears.
                    Text("Keeps your highlights, notes and bookmarks on your own Apple devices, in your own iCloud. Nothing goes to any server we run, there is still no account, and only your own marks travel — never the daily readings.\n\nUnlike restoring from a file, deleting a mark on one device deletes it on the others.\n\nTurning this on or off takes effect the next time you open the app.")
                }

                Section {
                    NavigationLink {
                        BackupRestoreView()
                    } label: {
                        Text("Backup & Restore")
                    }
                } footer: {
                    // The file tier answers what iCloud cannot: a machine that
                    // has never run this app, and will never be an Apple one.
                    Text("Carry your highlights, notes and bookmarks to another device — including a Windows, Linux or Android one, which iCloud cannot reach.")
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
            #if os(macOS)
            // The default macOS form is the columns style: it sizes to the
            // ideal single-line width of its content, so every footer ran
            // off the sheet's edge and every label was pushed into a column
            // of its own. Grouped wraps and stacks as the iOS form does.
            .formStyle(.grouped)
            #endif
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
        #if os(macOS)
        // A sheet takes its content's ideal size. A grouped form has none
        // worth having, and the sheet would otherwise change size at every
        // push, so the size is stated once for the whole stack and the
        // window's 420-point minimum is what the ideal width fits inside.
        .frame(
            minWidth: 380, idealWidth: 400, maxWidth: 720,
            minHeight: 440, idealHeight: 560, maxHeight: 900
        )
        #endif
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
