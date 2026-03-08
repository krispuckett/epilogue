import Foundation
import SwiftData

// MARK: - Re-Entry Intelligence Service
/// Detects when a user returns to a book after 3+ days and builds a personalized
/// recap from their own captured data (quotes, notes, questions, sessions).

@MainActor
final class ReEntryIntelligenceService {
    static let shared = ReEntryIntelligenceService()

    // MARK: - Recap Model

    struct ReEntryRecap {
        let bookTitle: String
        let bookAuthor: String
        let daysSinceLastSession: Int
        let lastSessionDate: Date
        let lastSessionDuration: TimeInterval
        let lastPage: Int?
        let lastQuote: String?
        let lastNote: String?
        let openQuestion: String?
        let sessionCount: Int
    }

    // MARK: - Dismissal Tracking

    private var dismissedBooks: Set<String> = []

    func markDismissed(_ bookId: String) {
        dismissedBooks.insert(bookId)
    }

    func wasDismissed(_ bookId: String) -> Bool {
        dismissedBooks.contains(bookId)
    }

    func clearDismissals() {
        dismissedBooks.removeAll()
    }

    // MARK: - Detection

    /// Check if a book needs re-entry intelligence (3+ days since last session)
    func needsReEntry(for bookModel: BookModel) -> Bool {
        // Skip if already dismissed this app session
        if wasDismissed(bookModel.localId) { return false }

        guard let lastSession = lastSession(for: bookModel),
              let startTime = lastSession.startTime else { return false }

        let daysSince = Calendar.current.dateComponents([.day], from: startTime, to: Date()).day ?? 0
        return daysSince >= 3
    }

    // MARK: - Recap Builder

    /// Build a recap from the user's own captured data
    func buildRecap(for bookModel: BookModel, modelContext: ModelContext) -> ReEntryRecap? {
        guard let lastSession = lastSession(for: bookModel),
              let startTime = lastSession.startTime else { return nil }

        let daysSince = Calendar.current.dateComponents([.day], from: startTime, to: Date()).day ?? 0

        // Most recent quote
        let lastQuote = (bookModel.quotes ?? [])
            .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
            .first?.text

        // Most recent note
        let lastNote = (bookModel.notes ?? [])
            .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
            .first?.content

        // Open question — prefer unanswered, fall back to most recent
        let questions = bookModel.questions ?? []
        let openQuestion: String? = questions
            .filter { $0.isAnswered != true }
            .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
            .first?.content
            ?? questions
                .sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
                .first?.content

        let sessionCount = (bookModel.sessions ?? []).count

        return ReEntryRecap(
            bookTitle: bookModel.title,
            bookAuthor: bookModel.author,
            daysSinceLastSession: daysSince,
            lastSessionDate: startTime,
            lastSessionDuration: lastSession.duration,
            lastPage: lastSession.currentPage ?? bookModel.currentPage,
            lastQuote: lastQuote,
            lastNote: lastNote,
            openQuestion: openQuestion,
            sessionCount: sessionCount
        )
    }

    // MARK: - Private

    private func lastSession(for bookModel: BookModel) -> AmbientSession? {
        (bookModel.sessions ?? [])
            .sorted { ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast) }
            .first
    }
}
