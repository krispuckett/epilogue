import AppIntents
import Foundation

/// Siri Intent: "Delete [book] from my library" or "Remove [book]"
struct DeleteBookIntent: AppIntent {
    static var title: LocalizedStringResource = "Delete Book"
    static var description = IntentDescription("Remove a book and all its notes from your library")

    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Book")
    var book: BookEntity

    @Parameter(
        title: "Confirm Deletion",
        description: "This will delete the book and all associated notes, quotes, and questions.",
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
        // Require explicit confirmation
        guard confirmDeletion else {
            throw IntentError.message("Deletion requires confirmation. This action cannot be undone.")
        }

        // Use LibraryService for proper cascade delete
        do {
            try await LibraryService.shared.deleteBook(book.id)
            return .result(dialog: "Deleted '\(book.title)' and all associated content from your library")
        } catch LibraryError.bookNotFound {
            throw IntentError.message("Could not find '\(book.title)' in your library")
        } catch {
            throw IntentError.message("Failed to delete book: \(error.localizedDescription)")
        }
    }
}
