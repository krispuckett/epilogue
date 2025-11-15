import AppIntents
import Foundation

/// Siri Intent: "Delete [book] from my library" or "Remove [book]"
struct DeleteBookIntent: AppIntent {
    static var title: LocalizedStringResource = "Delete Book"
    static var description = IntentDescription("Remove a book from your library")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Book")
    var book: BookEntity

    @Parameter(
        title: "Confirm Deletion",
        description: "Are you sure you want to delete this book?",
        default: false
    )
    var confirmDeletion: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$book) from library") {
            \.$confirmDeletion
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Require confirmation
        guard confirmDeletion else {
            return .result(dialog: "Deletion cancelled")
        }

        // Load books from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              var books = try? JSONDecoder().decode([Book].self, from: data) else {
            throw IntentError.message("Could not load library")
        }

        // Find and remove book
        guard let index = books.firstIndex(where: { $0.id == book.id }) else {
            throw IntentError.message("Could not find '\(book.title)' in your library")
        }

        let removedBook = books.remove(at: index)

        // Save back
        if let encoded = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(encoded, forKey: "com.epilogue.savedBooks")
        }

        // Refresh library
        NotificationCenter.default.post(name: Notification.Name("RefreshLibrary"), object: nil)

        // Remove from Spotlight
        Task {
            await SpotlightIndexingService.shared.deindexBook(removedBook.id)
        }

        return .result(dialog: "Deleted '\(book.title)' from your library")
    }
}
