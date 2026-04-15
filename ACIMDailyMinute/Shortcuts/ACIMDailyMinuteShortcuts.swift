import AppIntents

struct ACIMDailyMinuteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTodaysReadingIntent(),
            phrases: [
                "Today's Daily Minute from \(.applicationName)",
                "What's today's reading from \(.applicationName)",
                "Read today's lesson from \(.applicationName)"
            ],
            shortTitle: "Today's Reading",
            systemImageName: "sun.max"
        )
    }
}
