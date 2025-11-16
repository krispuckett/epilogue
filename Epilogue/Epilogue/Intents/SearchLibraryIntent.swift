import AppIntents
import Foundation

/// Siri Intent: "Search my library for Meditations" or "Find books by Marcus Aurelius"
struct SearchLibraryIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Library"
    static var description = IntentDescription("Search your library for books")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Search Query")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search library for \(\.$query)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[BookEntity]> & ProvidesDialog {
        // Use LibraryService intelligent search with fuzzy matching and ranking
        let results = LibraryService.shared.searchBooks(query: query, limit: 10)

        if results.isEmpty {
            return .result(
                value: [],
                dialog: "No books found matching '\(query)'"
            )
        }

        let bookEntities = results.map { BookEntity(from: $0) }

        let message = if results.count == 1 {
            "Found 1 book: '\(results[0].title)'"
        } else {
            "Found \(results.count) books matching '\(query)'"
        }

        return .result(
            value: bookEntities,
            dialog: IntentDialog(stringLiteral: message)
        )
    }
}
