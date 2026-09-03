import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Appearance.key) private var appearance = Appearance.dark.rawValue
    /// The Daily Minute reminder. The keys predate the split into two
    /// reminders and keep their names, so a reader who had the one reminder
    /// on still has one at the same time — about the minute.
    @AppStorage("dailyReminderEnabled") private var minuteReminderEnabled = false
    @AppStorage("dailyReminderTimeInterval") private var minuteReminderTimeInterval: Double = Date().timeIntervalSinceReferenceDate
    @AppStorage("lessonReminderEnabled") private var lessonReminderEnabled = false
    @AppStorage("lessonReminderTimeInterval") private var lessonReminderTimeInterval: Double = Date().timeIntervalSinceReferenceDate
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    Toggle("Daily Minute", isOn: $minuteReminderEnabled)
                    if minuteReminderEnabled {
                        DatePicker(
                            "Time",
                            selection: Self.timeBinding($minuteReminderTimeInterval),
                            displayedComponents: .hourAndMinute
                        )
                    }
                    Toggle("Daily Lesson", isOn: $lessonReminderEnabled)
                    if lessonReminderEnabled {
                        DatePicker(
                            "Time",
                            selection: Self.timeBinding($lessonReminderTimeInterval),
                            displayedComponents: .hourAndMinute
                        )
                    }
                    Button("Send test notification") {
                        Task { await NotificationManager.shared.fireTest() }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Each arrives at the same time every day. Reminders yield to Focus and Do Not Disturb.")
                }
                .onChange(of: minuteReminderEnabled) { _, _ in applyMinuteReminder() }
                .onChange(of: minuteReminderTimeInterval) { _, _ in applyMinuteReminder() }
                .onChange(of: lessonReminderEnabled) { _, _ in applyLessonReminder() }
                .onChange(of: lessonReminderTimeInterval) { _, _ in applyLessonReminder() }

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
                    // The marketing version alone. The build number is the
                    // store's bookkeeping and means nothing to a reader.
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        LabeledContent("Version", value: version)
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

    /// A time-of-day key is stored as a `timeIntervalSinceReferenceDate` so
    /// `@AppStorage` can hold it; the picker wants a `Date`.
    static func timeBinding(_ interval: Binding<Double>) -> Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: interval.wrappedValue) },
            set: { interval.wrappedValue = $0.timeIntervalSinceReferenceDate }
        )
    }

    private func applyMinuteReminder() {
        let enabled = minuteReminderEnabled
        let interval = minuteReminderTimeInterval
        Task { await NotificationManager.shared.applyDailyReminder(.minute, enabled: enabled, timeInterval: interval) }
    }

    private func applyLessonReminder() {
        let enabled = lessonReminderEnabled
        let interval = lessonReminderTimeInterval
        Task { await NotificationManager.shared.applyDailyReminder(.lesson, enabled: enabled, timeInterval: interval) }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
