import Foundation
import SwiftData

// MARK: - User Notes Result
/// Snapshot of a user's captured quotes, notes, questions, and insights for a book.
struct UserNotesResult {
    let quotes: [QuoteSnapshot]
    let notes: [NoteSnapshot]
    let openQuestions: [QuestionSnapshot]
    let answeredQuestions: [QuestionSnapshot]
    let insights: [InsightSnapshot]

    struct QuoteSnapshot {
        let text: String
        let pageNumber: Int?
        let userNotes: String?
        let timestamp: Date
    }

    struct NoteSnapshot {
        let content: String
        let pageNumber: Int?
        let timestamp: Date
    }

    struct QuestionSnapshot {
        let content: String
        let pageNumber: Int?
        let answer: String?
        let isAnswered: Bool
        let timestamp: Date
    }

    struct InsightSnapshot {
        let type: String
        let content: String
        let importance: Int
        let timestamp: Date
    }

    /// Whether the user has any captured content for this book
    var hasContent: Bool {
        !quotes.isEmpty || !notes.isEmpty || !openQuestions.isEmpty || !insights.isEmpty
    }

    /// Total number of captured items
    var totalItems: Int {
        quotes.count + notes.count + openQuestions.count + answeredQuestions.count + insights.count
    }
}

// MARK: - User Notes Provider
/// Extracts user-generated content (quotes, notes, questions, insights) from SwiftData
/// for a specific book. This personalizes the AI with the reader's own thoughts.
@MainActor
class UserNotesProvider {
    static let shared = UserNotesProvider()

    private init() {}

    /// Get all user notes/quotes/questions for a book, with optional limit
    func getNotes(for book: BookModel, limit: Int = 20) -> UserNotesResult {
        // Quotes - sorted by recency
        let quotes: [UserNotesResult.QuoteSnapshot] = (book.quotes ?? [])
            .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
            .prefix(limit)
            .map { quote in
                UserNotesResult.QuoteSnapshot(
                    text: quote.text ?? "",
                    pageNumber: quote.pageNumber,
                    userNotes: quote.notes,
                    timestamp: quote.timestamp ?? Date()
                )
            }

        // Notes - sorted by recency
        let notes: [UserNotesResult.NoteSnapshot] = (book.notes ?? [])
            .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
            .prefix(limit)
            .map { note in
                UserNotesResult.NoteSnapshot(
                    content: note.content ?? "",
                    pageNumber: note.pageNumber,
                    timestamp: note.timestamp ?? Date()
                )
            }

        // Questions - separate open from answered
        let allQuestions = (book.questions ?? [])
            .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }

        let openQuestions: [UserNotesResult.QuestionSnapshot] = allQuestions
            .filter { !($0.isAnswered ?? false) }
            .prefix(limit)
            .map { q in
                UserNotesResult.QuestionSnapshot(
                    content: q.content ?? "",
                    pageNumber: q.pageNumber,
                    answer: q.answer,
                    isAnswered: false,
                    timestamp: q.timestamp ?? Date()
                )
            }

        let answeredQuestions: [UserNotesResult.QuestionSnapshot] = allQuestions
            .filter { $0.isAnswered ?? false }
            .prefix(limit)
            .map { q in
                UserNotesResult.QuestionSnapshot(
                    content: q.content ?? "",
                    pageNumber: q.pageNumber,
                    answer: q.answer,
                    isAnswered: true,
                    timestamp: q.timestamp ?? Date()
                )
            }

        // Insights - sorted by importance, then recency
        let insights: [UserNotesResult.InsightSnapshot] = (book.insights ?? [])
            .sorted { $0.importance > $1.importance }
            .prefix(limit)
            .map { insight in
                UserNotesResult.InsightSnapshot(
                    type: insight.insightType,
                    content: insight.content,
                    importance: insight.importance,
                    timestamp: insight.timestamp
                )
            }

        return UserNotesResult(
            quotes: quotes,
            notes: notes,
            openQuestions: openQuestions,
            answeredQuestions: answeredQuestions,
            insights: insights
        )
    }

    /// Build a prompt-friendly string of user notes for a book
    func buildNotesContextString(for book: BookModel, maxQuotes: Int = 5, maxNotes: Int = 5, maxQuestions: Int = 3) -> String {
        let result = getNotes(for: book)
        var parts: [String] = []

        if !result.quotes.isEmpty {
            parts.append("Quotes the reader highlighted:")
            for quote in result.quotes.prefix(maxQuotes) {
                var line = "- \"\(quote.text)\""
                if let page = quote.pageNumber {
                    line += " (p.\(page))"
                }
                if let notes = quote.userNotes, !notes.isEmpty {
                    line += " — Reader's note: \(notes)"
                }
                parts.append(line)
            }
        }

        if !result.notes.isEmpty {
            parts.append("\nReader's own thoughts:")
            for note in result.notes.prefix(maxNotes) {
                var line = "- \(note.content)"
                if let page = note.pageNumber {
                    line += " (p.\(page))"
                }
                parts.append(line)
            }
        }

        if !result.openQuestions.isEmpty {
            parts.append("\nOpen questions the reader has:")
            for q in result.openQuestions.prefix(maxQuestions) {
                var line = "- \(q.content)"
                if let page = q.pageNumber {
                    line += " (p.\(page))"
                }
                parts.append(line)
            }
        }

        if !result.insights.isEmpty {
            let highPriority = result.insights.filter { $0.importance >= 4 }
            if !highPriority.isEmpty {
                parts.append("\nKey insights from conversations:")
                for insight in highPriority.prefix(3) {
                    parts.append("- [\(insight.type)] \(insight.content)")
                }
            }
        }

        return parts.joined(separator: "\n")
    }
}
