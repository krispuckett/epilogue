import Foundation
import SwiftData
import Observation

/// Builds rich context for generic ambient conversations (not book-specific)
@MainActor
@Observable
class GenericAmbientContextManager {
    static let shared = GenericAmbientContextManager()

    private var modelContext: ModelContext?

    private init() {}

    /// Configure with model context
    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Context Building

    /// Build context for generic ambient conversation
    func buildContext(for message: String) async -> String {
        guard let modelContext = modelContext else {
            return "ERROR: Model context not configured"
        }

        let intent = detectIntent(message)
        var contextParts: [String] = []

        // Always include: Current reading snapshot
        if let currentReading = getCurrentReadingSnapshot(context: modelContext) {
            contextParts.append(currentReading)
        }

        // Always include: Recently finished books
        if let recentFinished = getRecentlyFinished(context: modelContext, limit: 3) {
            contextParts.append(recentFinished)
        }

        // Conditional context based on intent
        switch intent {
        case .recommendation:
            if let tasteContext = buildTasteContext(context: modelContext) {
                contextParts.append(tasteContext)
            }

        case .habitAnalysis:
            if let patternsContext = buildPatternsContext(context: modelContext) {
                contextParts.append(patternsContext)
            }

        case .bookDiscussion(let bookTitle):
            if let bookContext = buildBookDiscussionContext(
                bookTitle: bookTitle,
                context: modelContext
            ) {
                contextParts.append(bookContext)
            }

        case .stats:
            if let statsContext = buildStatsContext(context: modelContext) {
                contextParts.append(statsContext)
            }

        case .general:
            if let overview = buildLibraryOverview(context: modelContext) {
                contextParts.append(overview)
            }
        }

        return contextParts.joined(separator: "\n\n")
    }

    // MARK: - Intent Detection

    private enum MessageIntent {
        case recommendation
        case habitAnalysis
        case bookDiscussion(bookTitle: String)
        case stats
        case general
    }

    private func detectIntent(_ message: String) -> MessageIntent {
        let lower = message.lowercased()

        // Recommendation keywords
        if lower.contains("recommend") || lower.contains("what should i read") ||
           lower.contains("next book") || lower.contains("suggestion") {
            return .recommendation
        }

        // Habit/pattern keywords
        if lower.contains("habit") || lower.contains("pattern") ||
           lower.contains("consistently") || lower.contains("more often") ||
           lower.contains("why can't i") || lower.contains("how can i") {
            return .habitAnalysis
        }

        // Stats keywords
        if lower.contains("stats") || lower.contains("statistics") ||
           lower.contains("how many") || lower.contains("show me my") ||
           lower.contains("reading year") || lower.contains("patterns") {
            return .stats
        }

        // Book title detection - check if message mentions a specific book
        if let bookTitle = detectBookMention(in: message) {
            return .bookDiscussion(bookTitle: bookTitle)
        }

        return .general
    }

    private func detectBookMention(in message: String) -> String? {
        guard let modelContext = modelContext else { return nil }

        let descriptor = FetchDescriptor<Book>()
        guard let allBooks = try? modelContext.fetch(descriptor) else {
            return nil
        }

        for book in allBooks {
            if message.localizedCaseInsensitiveContains(book.title) {
                return book.title
            }
        }

        return nil
    }

    // MARK: - Context Builders

    private func getCurrentReadingSnapshot(context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<ReadingSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        guard let recentSessions = try? context.fetch(descriptor),
              let activeSession = recentSessions.first(where: { $0.endTime == nil }),
              let book = activeSession.book else {
            return nil
        }

        return """
        CURRENT READING:
        - Book: \(book.title) by \(book.author)
        - Current page: \(book.currentPage) of \(book.pageCount ?? 0)
        - Reading status: \(book.readingStatus.rawValue)
        """
    }

    private func getRecentlyFinished(context: ModelContext, limit: Int) -> String? {
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.readingStatus == .finished },
            sortBy: [SortDescriptor(\.lastRead, order: .reverse)]
        )

        guard let finishedBooks = try? context.fetch(descriptor) else {
            return nil
        }

        let recent = finishedBooks.prefix(limit)

        guard !recent.isEmpty else { return nil }

        let bookList = recent.map { book in
            let daysAgo = Calendar.current.dateComponents(
                [.day],
                from: book.lastRead,
                to: .now
            ).day ?? 0
            return "- \(book.title) by \(book.author) (\(daysAgo) days ago)"
        }.joined(separator: "\n")

        return """
        RECENTLY FINISHED BOOKS:
        \(bookList)
        """
    }

    private func buildTasteContext(context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<Book>()
        guard let allBooks = try? context.fetch(descriptor) else {
            return nil
        }

        // Analyze genre distribution
        var genreCounts: [String: Int] = [:]
        var authorCounts: [String: Int] = [:]

        for book in allBooks where book.readingStatus == .finished {
            if !book.genre.isEmpty {
                genreCounts[book.genre, default: 0] += 1
            }
            authorCounts[book.author, default: 0] += 1
        }

        let topGenres = genreCounts.sorted { $0.value > $1.value }
            .prefix(3)
            .map { "\($0.key) (\($0.value) books)" }
            .joined(separator: ", ")

        let topAuthors = authorCounts.sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
            .joined(separator: ", ")

        return """
        READER TASTE PROFILE:
        - Top genres: \(topGenres.isEmpty ? "varied" : topGenres)
        - Favorite authors: \(topAuthors.isEmpty ? "none yet" : topAuthors)
        - Total books finished: \(genreCounts.values.reduce(0, +))
        """
    }

    private func buildPatternsContext(context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<ReadingSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        guard let sessions = try? context.fetch(descriptor) else {
            return nil
        }

        // Analyze session patterns
        let recentSessions = sessions.prefix(20)
        let totalDuration = recentSessions.reduce(0.0) { total, session in
            if let end = session.endTime {
                return total + end.timeIntervalSince(session.startTime)
            }
            return total
        }

        let avgDuration = recentSessions.isEmpty ? 0 : totalDuration / Double(recentSessions.count)
        let avgDurationMinutes = Int(avgDuration / 60)

        // Calculate pages per day (for completed sessions)
        let completedSessions = recentSessions.filter { $0.endTime != nil }
        let totalPages = completedSessions.reduce(0) { $0 + $1.pagesRead }
        let avgPagesPerSession = completedSessions.isEmpty ? 0 : totalPages / completedSessions.count

        return """
        READING PATTERNS:
        - Average session: \(avgDurationMinutes) minutes
        - Average pages per session: \(avgPagesPerSession)
        - Recent sessions: \(sessions.count) total
        """
    }

    private func buildBookDiscussionContext(bookTitle: String, context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { book in
                book.title.localizedStandardContains(bookTitle)
            }
        )

        guard let books = try? context.fetch(descriptor),
              let book = books.first else {
            return nil
        }

        // Get captured content
        let quotes = (book.quotes ?? []).prefix(5).map { quote in
            "- \"\(quote.text.prefix(80))...\" (p. \(quote.pageNumber ?? 0))"
        }.joined(separator: "\n")

        let notes = (book.notes ?? []).prefix(3).map { note in
            "- \(note.content.prefix(80))..."
        }.joined(separator: "\n")

        return """
        BOOK CONTEXT: \(book.title) by \(book.author)

        Status: \(book.readingStatus.rawValue)
        Current page: \(book.currentPage) of \(book.pageCount ?? 0)
        User rating: \(book.userRating > 0 ? "\(String(format: "%.1f", book.userRating)) stars" : "Not rated")

        CAPTURED QUOTES:
        \(quotes.isEmpty ? "None" : quotes)

        NOTES:
        \(notes.isEmpty ? "None" : notes)
        """
    }

    private func buildStatsContext(context: ModelContext) -> String? {
        let booksDescriptor = FetchDescriptor<Book>()
        guard let allBooks = try? context.fetch(booksDescriptor) else {
            return nil
        }

        let finishedBooks = allBooks.filter { $0.readingStatus == .finished }
        let inProgressBooks = allBooks.filter { $0.readingStatus == .reading }

        let totalPages = finishedBooks.reduce(0) { $0 + ($1.pageCount ?? 0) }
        let avgBookLength = finishedBooks.isEmpty ? 0 : totalPages / finishedBooks.count

        // Get total highlights
        let totalHighlights = allBooks.reduce(0) { $0 + ($1.quotes?.count ?? 0) }
        let totalNotes = allBooks.reduce(0) { $0 + ($1.notes?.count ?? 0) }

        return """
        READING STATISTICS:

        Volume:
        - Books finished: \(finishedBooks.count)
        - Currently reading: \(inProgressBooks.count)
        - Total pages read: \(totalPages)
        - Average book length: \(avgBookLength) pages

        Engagement:
        - Highlights captured: \(totalHighlights)
        - Notes written: \(totalNotes)
        """
    }

    private func buildLibraryOverview(context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<Book>()
        guard let allBooks = try? context.fetch(descriptor) else {
            return nil
        }

        let finished = allBooks.filter { $0.readingStatus == .finished }.count
        let reading = allBooks.filter { $0.readingStatus == .reading }.count
        let wantToRead = allBooks.filter { $0.readingStatus == .wantToRead }.count

        return """
        LIBRARY OVERVIEW:
        - Total books: \(allBooks.count)
        - Finished: \(finished)
        - Currently reading: \(reading)
        - Want to read: \(wantToRead)
        """
    }
}
