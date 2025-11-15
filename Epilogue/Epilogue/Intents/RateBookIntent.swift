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
        // Validate rating
        let clampedRating = min(max(rating, 0.0), 5.0)

        // Load books from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              var books = try? JSONDecoder().decode([Book].self, from: data) else {
            throw IntentError.message("Could not load library")
        }

        // Find and update book
        guard let index = books.firstIndex(where: { $0.id == book.id }) else {
            throw IntentError.message("Could not find '\(book.title)' in your library")
        }

        books[index].userRating = clampedRating

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

        let stars = String(format: "%.1f", clampedRating)
        let message = "Rated '\(book.title)' \(stars) stars"
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
