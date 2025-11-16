import AppIntents
import Foundation

/// Siri Intent: "Mark [book] as currently reading" or "Set [book] to want to read"
struct UpdateBookStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Update Book Status"
    static var description = IntentDescription("Change a book's reading status (Want to Read, Currently Reading, Read)")

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
        // Use LibraryService for atomic update across all storage layers
        do {
            try await LibraryService.shared.updateBookStatus(book.id, status: status.toReadingStatus())

            let message = "Marked '\(book.title)' as \(status.rawValue)"
            return .result(dialog: IntentDialog(stringLiteral: message))

        } catch LibraryError.bookNotFound {
            throw IntentError.message("Could not find '\(book.title)' in your library")
        } catch {
            throw IntentError.message("Failed to update status: \(error.localizedDescription)")
        }
    }
}
