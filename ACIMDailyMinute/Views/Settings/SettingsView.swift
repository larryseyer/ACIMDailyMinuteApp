import SwiftUI
import SwiftData
@preconcurrency import UserNotifications
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var sources: [Source]

    @AppStorage("notifyCorrections") private var notifyCorrections = false
    @AppStorage("notifyBreakingFacts") private var notifyBreakingFacts = false
    @AppStorage("notifyWatchedTerms") private var notifyWatchedTerms = false
    @AppStorage("notifyLiveActivities") private var notifyLiveActivities = false
    @AppStorage("useCustomNotificationSound") private var useCustomNotificationSound = true
    @AppStorage("preferVideoMode") private var preferVideoMode = true
    @AppStorage("archiveDownloadMode") private var archiveDownloadMode = "wifi"
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var showWatchedTerms = false
    @State private var showPrivacyPolicy = false
    @State private var selectedSource: Source?

    var body: some View {
        NavigationStack {
            Form {
                notificationsSection
                #if DEBUG
                if anyNotifyToggleOn {
                    NotificationsDiagnosticsSection()
                }
                #endif
                digestSection
                archiveSection
                sourceDetailsSection
                aboutSection
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            #else
            // macOS: the Settings sheet has no navigation bar, so give
            // it a toolbar Done button for consistent dismissal.
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
            #if os(macOS)
            .sheet(isPresented: $showWatchedTerms) {
                NavigationStack {
                    WatchedTermsView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showWatchedTerms = false }
                            }
                        }
                }
                .frame(width: 400, height: 350)
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                NavigationStack {
                    PrivacyPolicyView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showPrivacyPolicy = false }
                            }
                        }
                }
                .frame(width: 500, height: 500)
            }
            .sheet(item: $selectedSource) { source in
                NavigationStack {
                    SourceDetailView(source: source)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { selectedSource = nil }
                            }
                        }
                }
                .frame(width: 450, height: 400)
            }
            #endif
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Corrections", isOn: $notifyCorrections)
                .onChange(of: notifyCorrections) { _, newValue in
                    if newValue { requestNotificationPermission() }
                }
                .accessibilityHint("Notify when story corrections are published")
            Toggle("Breaking Facts", isOn: $notifyBreakingFacts)
                .onChange(of: notifyBreakingFacts) { _, newValue in
                    if newValue { requestNotificationPermission() }
                }
                .accessibilityHint("Notify for facts published within the last hour")
            Toggle("Watched Terms", isOn: $notifyWatchedTerms)
                .onChange(of: notifyWatchedTerms) { _, newValue in
                    if newValue { requestNotificationPermission() }
                }
                .accessibilityHint("Notify when new stories match your watched terms")
            if notifyWatchedTerms {
                #if os(macOS)
                Button("Manage Watched Terms") { showWatchedTerms = true }
                #else
                NavigationLink("Manage Watched Terms") {
                    WatchedTermsView()
                }
                #endif
            }
            Toggle("Custom Sound", isOn: $useCustomNotificationSound)
                .accessibilityHint("Use the ACIM Daily Minute chime instead of the default notification sound")
            #if os(iOS)
            Toggle("Live Activities", isOn: $notifyLiveActivities)
                .onChange(of: notifyLiveActivities) { _, newValue in
                    if newValue { requestNotificationPermission() }
                }
                .accessibilityHint("Show new facts on Lock Screen and Dynamic Island")
            #endif
        }
    }

    private func requestNotificationPermission() {
        Task {
            await NotificationManager.shared.requestPermissionIfNeeded()
        }
    }

    private var anyNotifyToggleOn: Bool {
        notifyCorrections || notifyBreakingFacts || notifyWatchedTerms || notifyLiveActivities
    }

    // MARK: - Digest

    private var digestSection: some View {
        Section("Digest") {
            Picker("Preferred Mode", selection: $preferVideoMode) {
                Text("Video").tag(true)
                Text("Audio").tag(false)
            }
        }
    }

    // MARK: - Archive

    private var archiveSection: some View {
        Section("Archive Download") {
            Picker("Download Mode", selection: $archiveDownloadMode) {
                Text("Wi-Fi Only").tag("wifi")
                Text("Wi-Fi + Cellular").tag("any")
                Text("Manual").tag("manual")
            }
        }
    }

    // MARK: - Source Details

    private var sourceDetailsSection: some View {
        Section("Source Details (\(sources.count) sources)") {
            ForEach(sources.sorted(by: { $0.name < $1.name }), id: \.name) { source in
                #if os(macOS)
                Button {
                    selectedSource = source
                } label: {
                    HStack {
                        Text(source.name)
                            .font(.acimBody)
                        Spacer()
                        Text(String(format: "%.1f", source.accuracy))
                            .font(.acimCaption)
                            .fontWeight(.bold)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                }
                .buttonStyle(.plain)
                #else
                NavigationLink {
                    SourceDetailView(source: source)
                } label: {
                    HStack {
                        Text(source.name)
                            .font(.acimBody)
                        Spacer()
                        Text(String(format: "%.1f", source.accuracy))
                            .font(.acimCaption)
                            .fontWeight(.bold)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                }
                #endif
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About ACIM Daily Minute") {
            Link("ACIMDailyMinute.org", destination: URL(string: "https://www.acimdailyminute.org")!)
            Link("Whitepaper & Methodology", destination: URL(string: "https://www.acimdailyminute.org/whitepaper.html")!)
            Link(destination: URL(string: "https://www.acimdailyminute.org/submit.html")!) {
                Label("Submit a Story", systemImage: "square.and.pencil")
            }
            Link("Source Code (GitHub)", destination: URL(string: "https://github.com/larryseyer/ACIMDailyMinute")!)
            Link(destination: URL(string: "https://www.acimdailyminute.org/support.html")!) {
                Label("Support ACIM Daily Minute", systemImage: "heart")
            }
            #if os(macOS)
            Button("Privacy Policy") { showPrivacyPolicy = true }
            #else
            NavigationLink("Privacy Policy") {
                PrivacyPolicyView()
            }
            #endif
            Button("Show Welcome") {
                hasSeenOnboarding = false
                dismiss()
            }

            HStack {
                Text("Version")
                Spacer()
                Text("1.0")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Notifications Diagnostics

/// Live introspection of the notification subsystem. Surfaces iOS-granted
/// state (authorization, sound, badge, BG refresh) alongside the app's own
/// scheduling timestamps, and provides a one-tap test notification so the
/// user can verify the audio path independent of www.acimdailyminute.org content.
private struct NotificationsDiagnosticsSection: View {
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var soundSetting: UNNotificationSetting = .notSupported
    @State private var badgeSetting: UNNotificationSetting = .notSupported
    @State private var alertSetting: UNNotificationSetting = .notSupported
    @State private var lastTestResult: String?

    #if os(iOS)
    @State private var backgroundRefreshStatus: UIBackgroundRefreshStatus = .available
    #endif

    var body: some View {
        Section("Notification Diagnostics") {
            diagnosticRow("System Permission", value: authStatusText, tint: authStatusTint)
            diagnosticRow("Sound", value: settingText(soundSetting), tint: settingTint(soundSetting))
            diagnosticRow("Banner / Alert", value: settingText(alertSetting), tint: settingTint(alertSetting))
            diagnosticRow("Badge", value: settingText(badgeSetting), tint: settingTint(badgeSetting))

            #if os(iOS)
            diagnosticRow("Background Refresh", value: backgroundRefreshText, tint: backgroundRefreshTint)
            #endif

            diagnosticRow("Last Breaking check", value: relativeTime(forKey: "lastBreakingCheck"))
            diagnosticRow("Last Foreground check", value: relativeTime(forKey: "lastForegroundCheck"))
            diagnosticRow("Corrections baseline", value: countText(forKey: "lastCorrectionCount"))

            if authStatus == .denied {
                #if os(iOS)
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                #endif
            }

            Button {
                sendTestNotification()
            } label: {
                Label("Send Test Notification", systemImage: "bell.badge")
            }
            .accessibilityHint("Fires a test notification so you can verify sound and banner delivery")

            if let lastTestResult {
                Text(lastTestResult)
                    .font(.acimCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .task { await refreshState() }
    }

    private func diagnosticRow(_ label: String, value: String, tint: Color? = nil) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.acimCaption)
                .foregroundStyle(tint ?? .secondary)
        }
    }

    private func refreshState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = settings.authorizationStatus
        soundSetting = settings.soundSetting
        badgeSetting = settings.badgeSetting
        alertSetting = settings.alertSetting
        #if os(iOS)
        backgroundRefreshStatus = await MainActor.run { UIApplication.shared.backgroundRefreshStatus }
        #endif
    }

    private func sendTestNotification() {
        Task {
            await NotificationManager.shared.requestPermissionIfNeeded()
            await refreshState()
            guard authStatus == .authorized || authStatus == .provisional else {
                lastTestResult = "Permission not granted — tap 'Open iOS Settings' above."
                return
            }
            await NotificationManager.shared.sendNotification(
                title: "ACIM Daily Minute — Test",
                body: "If you hear the chime, notifications are working.",
                identifier: "test-\(UUID().uuidString)"
            )
            lastTestResult = "Test notification sent. Lower ringer volume or Focus mode can silence the chime."
        }
    }

    // MARK: - Display helpers

    private var authStatusText: String {
        switch authStatus {
        case .notDetermined: return "Not yet asked"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private var authStatusTint: Color {
        switch authStatus {
        case .authorized, .provisional: return .green
        case .denied: return .red
        default: return .secondary
        }
    }

    private func settingText(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .enabled: return "Enabled"
        case .disabled: return "Disabled"
        case .notSupported: return "Not supported"
        @unknown default: return "Unknown"
        }
    }

    private func settingTint(_ setting: UNNotificationSetting) -> Color? {
        switch setting {
        case .enabled: return .green
        case .disabled: return .red
        default: return nil
        }
    }

    #if os(iOS)
    private var backgroundRefreshText: String {
        switch backgroundRefreshStatus {
        case .available: return "Available"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        @unknown default: return "Unknown"
        }
    }

    private var backgroundRefreshTint: Color? {
        switch backgroundRefreshStatus {
        case .available: return .green
        case .denied, .restricted: return .red
        @unknown default: return nil
        }
    }
    #endif

    private func relativeTime(forKey key: String) -> String {
        let stamp = UserDefaults.standard.double(forKey: key)
        guard stamp > 0 else { return "Never" }
        let date = Date(timeIntervalSince1970: stamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func countText(forKey key: String) -> String {
        guard UserDefaults.standard.object(forKey: key) != nil else { return "Not seeded" }
        return "\(UserDefaults.standard.integer(forKey: key))"
    }
}
