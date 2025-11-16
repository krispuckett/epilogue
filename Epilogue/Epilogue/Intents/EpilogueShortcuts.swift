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

        AppShortcut(
            intent: UpdateBookStatusIntent(),
            phrases: [
                "Update book status in \(.applicationName)",
                "Change reading status in \(.applicationName)"
            ],
            shortTitle: "Update Status",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: SearchLibraryIntent(),
            phrases: [
                "Search my library in \(.applicationName)",
                "Find a book in \(.applicationName)"
            ],
            shortTitle: "Search Library",
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: SearchNotesIntent(),
            phrases: [
                "Search my notes in \(.applicationName)",
                "Find quotes in \(.applicationName)",
                "Search notes and quotes in \(.applicationName)"
            ],
            shortTitle: "Search Notes",
            systemImageName: "doc.text.magnifyingglass"
        )

        AppShortcut(
            intent: ExportNotesIntent(),
            phrases: [
                "Export notes from \(\.$book) in \(.applicationName)",
                "Get markdown for \(\.$book) in \(.applicationName)"
            ],
            shortTitle: "Export Notes",
            systemImageName: "square.and.arrow.up"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .orange
}
