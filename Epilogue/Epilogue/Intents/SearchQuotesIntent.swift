import AppIntents
import Foundation
import SwiftData

/// Siri Intent: "Search my quotes for Gandalf" or "Find quotes about wisdom"
struct SearchQuotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Quotes"
    static var description = IntentDescription("Search across all your highlighted quotes")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Search Query")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search quotes for \(\.$query)")
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
        let descriptor = FetchDescriptor<CapturedQuote>()
        let allQuotes = (try? context.fetch(descriptor)) ?? []

        // Search with intelligent ranking
        let queryLower = query.lowercased()
        let queryTokens = queryLower.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        let scored = allQuotes.compactMap { quote -> (quote: CapturedQuote, score: Int)? in
            guard let text = quote.text else { return nil }

            var score = 0
            let textLower = text.lowercased()

            for token in queryTokens {
                if textLower.contains(token) && token.count > 3 {
                    score += 30  // Exact phrase match
                }
                if textLower.components(separatedBy: .whitespacesAndNewlines).contains(token) {
                    score += 20  // Exact word match
                }
                if textLower.contains(token) {
                    score += 5  // Contains anywhere
                }
            }

            return score > 0 ? (quote, score) : nil
        }

        let results = scored
            .sorted { $0.score > $1.score }
            .prefix(20)
            .map { $0.quote }

        let quoteEntities = results.map { QuoteEntity(from: $0, books: books) }

        if quoteEntities.isEmpty {
            return .result(
                value: [],
                dialog: "No quotes found matching '\(query)'"
            )
        }

        let message = if quoteEntities.count == 1 {
            "Found 1 quote matching '\(query)'"
        } else {
            "Found \(quoteEntities.count) quotes matching '\(query)'"
        }

        return .result(
            value: quoteEntities,
            dialog: IntentDialog(stringLiteral: message)
        )
    }
}
