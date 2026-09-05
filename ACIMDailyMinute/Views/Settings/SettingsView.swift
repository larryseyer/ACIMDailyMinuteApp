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
    @AppStorage(PracticeReminderKey.enabled) private var practiceEnabled = false
    @AppStorage(PracticeReminderKey.windowStart) private var practiceStartInterval: Double = Date().timeIntervalSinceReferenceDate
    @AppStorage(PracticeReminderKey.windowEnd) private var practiceEndInterval: Double = Date().timeIntervalSinceReferenceDate
    @AppStorage(PracticeReminderKey.ownStartLesson) private var practiceOwnStartLesson = 0
    @AppStorage(PracticeReminderKey.ownStartDay) private var practiceOwnStartDay = ""
    @Environment(\.modelContext) private var modelContext
    /// "Lesson 95 · five minutes every hour" — what the reminders name today.
    @State private var todayLine = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    #if !os(tvOS)
                .pickerStyle(.segmented)
                #endif
                    .labelsHidden()
                }

                // ⛔ Every reminder control is absent on tvOS. A television
                // cannot deliver a local notification — it can only badge — so
                // there is nothing here for a reader to set. DatePicker and
                // Stepper do not exist there either.
                #if !os(tvOS)
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
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("Each arrives at the same time every day.")
                }
                .onChange(of: minuteReminderEnabled) { _, _ in applyMinuteReminder() }
                .onChange(of: minuteReminderTimeInterval) { _, _ in applyMinuteReminder() }
                .onChange(of: lessonReminderEnabled) { _, _ in applyLessonReminder() }
                .onChange(of: lessonReminderTimeInterval) { _, _ in applyLessonReminder() }

                Section {
                    Toggle("Follow the lesson's practice", isOn: $practiceEnabled)
                    if practiceEnabled {
                        DatePicker(
                            "Day begins",
                            selection: Self.timeBinding($practiceStartInterval),
                            displayedComponents: .hourAndMinute
                        )
                        DatePicker(
                            "Day ends",
                            selection: Self.timeBinding($practiceEndInterval),
                            displayedComponents: .hourAndMinute
                        )
                        LabeledContent("Today") {
                            Text(todayLine)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                        Picker("Which lesson", selection: followsOwnPlace) {
                            Text("Today's published lesson").tag(false)
                            Text("My own place").tag(true)
                        }
                        if practiceOwnStartLesson > 0 {
                            Stepper(
                                "I am on lesson \(practiceOwnStartLesson)",
                                value: $practiceOwnStartLesson,
                                in: 1...365
                            )
                        }
                    }
                    Button("Send test notification") {
                        Task { await NotificationManager.shared.fireTest() }
                    }
                } header: {
                    Text("Practice reminders")
                } footer: {
                    // The Workbook sets each lesson's own cadence — twice a day
                    // at first, every half hour by Lesson 20, the first five
                    // minutes of every hour from Lesson 93 — and the reminders
                    // follow it. What the reader chooses here is the day the
                    // cadence fits inside.
                    Text("Each Workbook lesson asks for its own practice — a longer period morning and evening, a moment every hour, a few short ones through the day — and these reminders follow the lesson you are on. Hourly reminders fall between the times your day begins and ends.\n\nReminders yield to Focus and Do Not Disturb. They are laid out three days ahead and refreshed whenever you open the app.")
                }
                .onChange(of: practiceEnabled) { _, _ in reschedulePractice() }
                .onChange(of: practiceStartInterval) { _, _ in
                    keepWindowUsable()
                    reschedulePractice()
                }
                .onChange(of: practiceEndInterval) { _, _ in
                    keepWindowUsable()
                    reschedulePractice()
                }
                .onChange(of: practiceOwnStartLesson) { _, lesson in
                    // Saying "I am on lesson N" is said today; the day is the
                    // other half of the reader's place.
                    if lesson > 0 {
                        practiceOwnStartDay = PracticeReminderService.localDayFormatter.string(from: Date())
                    } else {
                        practiceOwnStartDay = ""
                    }
                    reschedulePractice()
                }
                .task { refreshTodayLine() }
                #endif

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

                // ⛔ Absent on tvOS: there is no document picker there, so neither
                // backup tier can be operated from a television.
                #if !os(tvOS)
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
                #endif

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

    // ⛔ These exist only to serve the reminder controls above, which tvOS does
    // not have. They go with them rather than surviving as dead code.
    #if !os(tvOS)
    /// "My own place" is on when a start lesson is set. Switching it on
    /// starts from the lesson the reminders would name anyway, so nothing
    /// jumps; switching it off returns to the published sequence.
    private var followsOwnPlace: Binding<Bool> {
        Binding(
            get: { practiceOwnStartLesson > 0 },
            set: { own in
                practiceOwnStartLesson = own ? (PracticeReminderService.currentLesson() ?? 1) : 0
            }
        )
    }

    /// The end is kept at least an hour after the start, because a window
    /// shorter than that holds no hourly reminder and the two pickers would
    /// otherwise look as though they promised one.
    private func keepWindowUsable() {
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute], from: Date(timeIntervalSinceReferenceDate: practiceStartInterval))
        let end = calendar.dateComponents([.hour, .minute], from: Date(timeIntervalSinceReferenceDate: practiceEndInterval))
        let startMinutes = (start.hour ?? 0) * 60 + (start.minute ?? 0)
        let endMinutes = (end.hour ?? 0) * 60 + (end.minute ?? 0)
        guard endMinutes < startMinutes + 60 else { return }
        let pushed = min(startMinutes + 60, 23 * 60 + 59)
        if let date = calendar.date(
            bySettingHour: pushed / 60, minute: pushed % 60, second: 0,
            of: Date(timeIntervalSinceReferenceDate: practiceEndInterval)
        ) {
            practiceEndInterval = date.timeIntervalSinceReferenceDate
        }
    }

    private func reschedulePractice() {
        PracticeReminderService.reschedule(in: modelContext)
        refreshTodayLine()
    }

    private func refreshTodayLine() {
        PracticeReminderService.seedAnchor(from: modelContext)
        guard let lesson = PracticeReminderService.currentLesson() else {
            todayLine = "No lesson yet"
            return
        }
        let cadence = WorkbookPracticeCatalog.record(for: lesson).map(PracticePlanner.cadenceSummary) ?? ""
        todayLine = cadence.isEmpty ? "Lesson \(lesson)" : "Lesson \(lesson) · \(cadence)"
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
    #endif
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
