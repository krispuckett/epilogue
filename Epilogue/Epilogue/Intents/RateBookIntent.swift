import AppIntents
import Foundation

/// Siri Intent: "Rate [book] 5 stars" or "Give [book] 3.5 stars"
struct RateBookIntent: AppIntent {
    static var title: LocalizedStringResource = "Rate Book"
    static var description = IntentDescription("Set a star rating for a book")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Book")
    var book: BookEntity

    @Parameter(title: "Rating", default: 5.0, controlStyle: .field)
    var rating: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Rate \(\.$book) \(\.$rating) stars")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Use LibraryService for atomic update across all storage layers
        do {
            try await LibraryService.shared.updateBookRating(book.id, rating: rating)

            let stars = String(format: "%.1f", min(max(rating, 0.0), 5.0))
            let message = "Rated '\(book.title)' \(stars) stars"
            return .result(dialog: IntentDialog(stringLiteral: message))

        } catch LibraryError.bookNotFound {
            throw IntentError.message("Could not find '\(book.title)' in your library")
        } catch {
            throw IntentError.message("Failed to update rating: \(error.localizedDescription)")
        }
    }
}
