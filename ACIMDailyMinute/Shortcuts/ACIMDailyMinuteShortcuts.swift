import AppIntents

struct ACIMDailyMinuteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTodaysFactsIntent(),
            phrases: [
                "What are today's facts in \(.applicationName)",
                "Read today's news from \(.applicationName)",
                "Get today's facts from \(.applicationName)"
            ],
            shortTitle: "Today's Facts",
            systemImageName: "newspaper"
        )
    }
}
