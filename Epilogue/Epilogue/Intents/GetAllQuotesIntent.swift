import AppIntents
import Foundation
import SwiftData

/// Siri Intent: "Get all my quotes" or "Show all my quotes in Epilogue"
struct GetAllQuotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Get All Quotes"
    static var description = IntentDescription("Get all quotes from your entire library")

    static var openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Get all my quotes")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[QuoteEntity]> & ProvidesDialog {
        // Load books for context
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            throw IntentError.message("Could not load library")
        }

        // Fetch all quotes from SwiftData
        guard let container = try? ModelContainer(
            for: CapturedNote.self, CapturedQuote.self, CapturedQuestion.self, BookModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        ) else {
            throw IntentError.message("Could not access database")
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CapturedQuote>(
            sortBy: [SortDescriptor(\CapturedQuote.timestamp, order: .reverse)]
        )

        let quotes = (try? context.fetch(descriptor)) ?? []
        let quoteEntities = quotes.map { QuoteEntity(from: $0, books: books) }

        if quoteEntities.isEmpty {
            return .result(
                value: [],
                dialog: "You don't have any quotes yet"
            )
        }

        let message = if quoteEntities.count == 1 {
            "Found 1 quote"
        } else {
            "Found \(quoteEntities.count) quotes across your library"
        }

        return .result(
            value: quoteEntities,
            dialog: IntentDialog(stringLiteral: message)
        )
    }
}
