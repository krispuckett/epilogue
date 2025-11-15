import AppIntents
import Foundation

/// Siri Intent: "Mark [book] as currently reading" or "Set [book] to want to read"
struct UpdateBookStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Update Book Status"
    static var description = IntentDescription("Change a book's reading status")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Book")
    var book: BookEntity

    @Parameter(title: "Status")
    var status: ReadingStatusEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$book) as \(\.$status)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Load books from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              var books = try? JSONDecoder().decode([Book].self, from: data) else {
            throw IntentError.message("Could not load library")
        }

        // Find and update book
        guard let index = books.firstIndex(where: { $0.id == book.id }) else {
            throw IntentError.message("Could not find '\(book.title)' in your library")
        }

        let oldStatus = books[index].readingStatus
        books[index].readingStatus = status.toReadingStatus()

        // Save back
        if let encoded = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(encoded, forKey: "com.epilogue.savedBooks")
        }

        // Refresh library
        NotificationCenter.default.post(name: Notification.Name("RefreshLibrary"), object: nil)

        // Index for Spotlight
        Task {
            await SpotlightIndexingService.shared.indexBook(books[index])
        }

        let message = "Marked '\(book.title)' as \(status.rawValue)"
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
