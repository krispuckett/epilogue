import AppIntents

/// App Shortcuts provider for Siri suggestions
struct EpilogueShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // PRIORITY 1: Continue Reading (most common action)
        AppShortcut(
            intent: ContinueReadingIntent(),
            phrases: [
                "Continue reading in \(.applicationName)",
                "Resume my book in \(.applicationName)",
                "Continue reading \(\.$book) in \(.applicationName)",
                "Resume \(\.$book) in \(.applicationName)",
                "Open \(\.$book) in \(.applicationName)"
            ],
            shortTitle: "Continue Reading",
            systemImageName: "book.fill"
        )

        AppShortcut(
            intent: AddNoteIntent(),
            phrases: [
                "Add a note to \(.applicationName)",
                "Save a note in \(.applicationName)",
                "Add a reading note to \(.applicationName)"
            ],
            shortTitle: "Add Note",
            systemImageName: "note.text"
        )

        AppShortcut(
            intent: AddQuoteIntent(),
            phrases: [
                "Save a quote in \(.applicationName)",
                "Add a quote to \(.applicationName)",
                "Save this quote in \(.applicationName)"
            ],
            shortTitle: "Save Quote",
            systemImageName: "quote.bubble"
        )

        AppShortcut(
            intent: LogPagesIntent(),
            phrases: [
                "Log pages in \(.applicationName)",
                "I read pages in \(.applicationName)",
                "Track reading progress in \(.applicationName)"
            ],
            shortTitle: "Log Pages",
            systemImageName: "book.pages"
        )

        AppShortcut(
            intent: GetReadingProgressIntent(),
            phrases: [
                "What's my reading progress in \(.applicationName)",
                "How many pages left in \(.applicationName)",
                "Check my progress in \(.applicationName)"
            ],
            shortTitle: "Reading Progress",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .orange
}
