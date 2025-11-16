import AppIntents
import Foundation
import SwiftData

/// Siri Intent: "Get my favorite quotes" or "Show favorite quotes in Epilogue"
struct GetFavoriteQuotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Favorite Quotes"
    static var description = IntentDescription("Get all quotes marked as favorites")

    static var openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Get my favorite quotes")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[QuoteEntity]> & ProvidesDialog {
        // Load books for context
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            throw IntentError.message("Could not load library")
        }

        // Fetch favorite quotes from SwiftData
        guard let container = try? ModelContainer(
            for: CapturedNote.self, CapturedQuote.self, CapturedQuestion.self, BookModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        ) else {
            throw IntentError.message("Could not access database")
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CapturedQuote>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\CapturedQuote.timestamp, order: .reverse)]
        )

        let quotes = (try? context.fetch(descriptor)) ?? []
        let quoteEntities = quotes.map { QuoteEntity(from: $0, books: books) }

        if quoteEntities.isEmpty {
            return .result(
                value: [],
                dialog: "You don't have any favorite quotes yet"
            )
        }

        let message = if quoteEntities.count == 1 {
            "Found 1 favorite quote"
        } else {
            "Found \(quoteEntities.count) favorite quotes"
        }

        return .result(
            value: quoteEntities,
            dialog: IntentDialog(stringLiteral: message)
        )
    }
}
