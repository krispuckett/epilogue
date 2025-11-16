import AppIntents
import Foundation
import SwiftData

/// Siri Intent: "Get my quotes from Meditations" or "Show quotes for The Odyssey"
struct GetQuotesForBookIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Quotes for Book"
    static var description = IntentDescription("Get all quotes highlighted from a specific book")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Book")
    var book: BookEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get quotes from \(\.$book)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[QuoteEntity]> & ProvidesDialog {
        // Load books for context
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            throw IntentError.message("Could not load library")
        }

        // Fetch quotes from SwiftData for this specific book
        guard let container = try? ModelContainer(
            for: CapturedNote.self, CapturedQuote.self, CapturedQuestion.self, BookModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        ) else {
            throw IntentError.message("Could not access database")
        }

        let context = ModelContext(container)
        let bookId = book.id

        let descriptor = FetchDescriptor<CapturedQuote>(
            predicate: #Predicate { $0.book?.id == bookId },
            sortBy: [SortDescriptor(\CapturedQuote.pageNumber, order: .forward)]
        )

        let quotes = (try? context.fetch(descriptor)) ?? []
        let quoteEntities = quotes.map { QuoteEntity(from: $0, books: books) }

        if quoteEntities.isEmpty {
            return .result(
                value: [],
                dialog: "No quotes found for '\(book.title)'"
            )
        }

        let message = if quoteEntities.count == 1 {
            "Found 1 quote from '\(book.title)'"
        } else {
            "Found \(quoteEntities.count) quotes from '\(book.title)'"
        }

        return .result(
            value: quoteEntities,
            dialog: IntentDialog(stringLiteral: message)
        )
    }
}
