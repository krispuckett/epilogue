import AppIntents
import SwiftUI

/// Siri Intent: "Continue reading Meditations" or "Resume my book"
struct ContinueReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "Continue Reading"
    static var description = IntentDescription("Resume reading your current book in Ambient Mode")

    static var openAppWhenRun: Bool = true  // Always open the app

    @Parameter(title: "Book")
    var book: BookEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Continue reading \(\.$book)") {
            \.$book
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Determine which book to open
        let targetBook: Book

        let books = LibraryService.shared.loadBooks()

        if let bookEntity = book {
            // Siri specified a book: "Continue reading Meditations"
            guard let foundBook = books.first(where: { $0.id == bookEntity.id }) else {
                throw IntentError.message("Could not find '\(bookEntity.title)' in your library")
            }
            targetBook = foundBook
        } else {
            // No book specified: "Continue reading" - use currently reading book
            guard let currentBook = books.first(where: { $0.readingStatus == .currentlyReading }) else {
                throw IntentError.message("You don't have any books currently marked as reading. Try saying 'Continue reading' followed by a book title.")
            }
            targetBook = currentBook
        }

        // Post notification to open ambient mode with this book
        // The app will listen for this notification and navigate accordingly
        NotificationCenter.default.post(
            name: .openAmbientModeFromIntent,
            object: targetBook.id,
            userInfo: [
                "bookId": targetBook.id,
                "bookTitle": targetBook.title
            ]
        )

        return .result()
    }
}
