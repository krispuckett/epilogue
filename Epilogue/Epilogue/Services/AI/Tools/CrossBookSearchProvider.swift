import Foundation
import SwiftData

// MARK: - Cross-Book Search Result
/// Results from searching notes, quotes, and insights across all books.
struct CrossBookSearchResult {
    let query: String
    let matchingQuotes: [CrossBookQuote]
    let matchingNotes: [CrossBookNote]
    let matchingInsights: [CrossBookInsight]

    struct CrossBookQuote {
        let text: String
        let bookTitle: String
        let bookAuthor: String
        let pageNumber: Int?
    }

    struct CrossBookNote {
        let content: String
        let bookTitle: String
        let bookAuthor: String
        let pageNumber: Int?
    }

    struct CrossBookInsight {
        let content: String
        let type: String
        let bookTitle: String
        let bookAuthor: String
        let importance: Int
    }

    /// Whether any results were found
    var hasResults: Bool {
        !matchingQuotes.isEmpty || !matchingNotes.isEmpty || !matchingInsights.isEmpty
    }

    /// Total number of matches
    var totalMatches: Int {
        matchingQuotes.count + matchingNotes.count + matchingInsights.count
    }
}

// MARK: - Cross-Book Search Provider
/// Searches notes, quotes, and insights across ALL books in the user's library.
/// Enables the AI to make connections between books the user has read.
@MainActor
class CrossBookSearchProvider {
    static let shared = CrossBookSearchProvider()

    private init() {}

    /// Search across all books for a query string
    func search(query: String, in modelContext: ModelContext, limit: Int = 10) -> CrossBookSearchResult {
        let queryLower = query.lowercased()

        // Fetch all books
        let bookDescriptor = FetchDescriptor<BookModel>()
        let allBooks = (try? modelContext.fetch(bookDescriptor)) ?? []

        var matchingQuotes: [CrossBookSearchResult.CrossBookQuote] = []
        var matchingNotes: [CrossBookSearchResult.CrossBookNote] = []
        var matchingInsights: [CrossBookSearchResult.CrossBookInsight] = []

        for book in allBooks {
            // Search quotes
            for quote in (book.quotes ?? []) {
                let quoteText = quote.text ?? ""
                if quoteText.lowercased().contains(queryLower) {
                    matchingQuotes.append(CrossBookSearchResult.CrossBookQuote(
                        text: quoteText,
                        bookTitle: book.title,
                        bookAuthor: book.author,
                        pageNumber: quote.pageNumber
                    ))
                }
            }

            // Search notes
            for note in (book.notes ?? []) {
                let noteContent = note.content ?? ""
                if noteContent.lowercased().contains(queryLower) {
                    matchingNotes.append(CrossBookSearchResult.CrossBookNote(
                        content: noteContent,
                        bookTitle: book.title,
                        bookAuthor: book.author,
                        pageNumber: note.pageNumber
                    ))
                }
            }

            // Search insights
            for insight in (book.insights ?? []) {
                if insight.content.lowercased().contains(queryLower) ||
                   insight.insightType.lowercased().contains(queryLower) {
                    matchingInsights.append(CrossBookSearchResult.CrossBookInsight(
                        content: insight.content,
                        type: insight.insightType,
                        bookTitle: book.title,
                        bookAuthor: book.author,
                        importance: insight.importance
                    ))
                }
            }
        }

        // Sort by relevance (insights by importance, others by match quality)
        matchingInsights.sort { $0.importance > $1.importance }

        return CrossBookSearchResult(
            query: query,
            matchingQuotes: Array(matchingQuotes.prefix(limit)),
            matchingNotes: Array(matchingNotes.prefix(limit)),
            matchingInsights: Array(matchingInsights.prefix(limit))
        )
    }

    /// Search for thematic connections across books
    func findThematicConnections(theme: String, in modelContext: ModelContext) -> [String] {
        let themeLower = theme.lowercased()

        let bookDescriptor = FetchDescriptor<BookModel>()
        let allBooks = (try? modelContext.fetch(bookDescriptor)) ?? []

        var connections: [String] = []

        for book in allBooks {
            let themes = book.keyThemes ?? []
            let matchingThemes = themes.filter { $0.lowercased().contains(themeLower) }
            if !matchingThemes.isEmpty {
                connections.append("\(book.title) by \(book.author) — themes: \(matchingThemes.joined(separator: ", "))")
            }
        }

        return connections
    }

    /// Build a prompt-friendly search results string
    func buildSearchContextString(query: String, in modelContext: ModelContext) -> String {
        let results = search(query: query, in: modelContext)

        guard results.hasResults else {
            return ""
        }

        var parts: [String] = []
        parts.append("Cross-book search results for '\(query)':")

        if !results.matchingQuotes.isEmpty {
            parts.append("\nRelated quotes from other books:")
            for quote in results.matchingQuotes.prefix(3) {
                parts.append("- \"\(quote.text)\" — \(quote.bookTitle) by \(quote.bookAuthor)")
            }
        }

        if !results.matchingNotes.isEmpty {
            parts.append("\nRelated notes from other books:")
            for note in results.matchingNotes.prefix(3) {
                parts.append("- \(note.content) — \(note.bookTitle)")
            }
        }

        if !results.matchingInsights.isEmpty {
            parts.append("\nRelated insights:")
            for insight in results.matchingInsights.prefix(3) {
                parts.append("- [\(insight.type)] \(insight.content) — \(insight.bookTitle)")
            }
        }

        return parts.joined(separator: "\n")
    }
}
