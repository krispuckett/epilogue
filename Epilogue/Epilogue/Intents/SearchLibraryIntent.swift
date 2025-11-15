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
        // Load books from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            throw IntentError.message("Could not load library")
        }

        // Search by title or author
        let lowercaseQuery = query.lowercased()
        let results = books.filter { book in
            book.title.lowercased().contains(lowercaseQuery) ||
            book.author.lowercased().contains(lowercaseQuery)
        }

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
