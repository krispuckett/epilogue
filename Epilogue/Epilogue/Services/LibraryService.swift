import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "LibraryService")

/// Unified service for all library data operations
/// SwiftData is the single source of truth for all book data
@MainActor
final class LibraryService {
    static let shared = LibraryService()

    // MARK: - Properties

    private let modelContainer: ModelContainer
    // Cache for performance
    private var cachedBooks: [Book]?
    private var lastLoadTime: Date?
    private let cacheTimeout: TimeInterval = 5.0 // 5 seconds

    /// Flag indicating if we're running in memory-only mode due to storage failure
    private(set) var isMemoryOnlyMode = false

    // MARK: - Initialization

    private init() {
        // Create ModelContainer once and reuse
        do {
            let cloudKitContainer = ModelConfiguration(
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )

            modelContainer = try ModelContainer(
                for: BookModel.self,
                     CapturedNote.self,
                     CapturedQuote.self,
                     CapturedQuestion.self,
                     AmbientSession.self,
                     QueuedQuestion.self,
                     ReadingSession.self,
                configurations: cloudKitContainer
            )

            logger.info("✅ LibraryService initialized with ModelContainer")
        } catch {
            // Fallback to local storage
            logger.error("❌ Failed to initialize with CloudKit, using local: \(error.localizedDescription)")

            do {
                let localConfig = ModelConfiguration(
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .none
                )

                modelContainer = try ModelContainer(
                    for: BookModel.self,
                         CapturedNote.self,
                         CapturedQuote.self,
                         CapturedQuestion.self,
                         AmbientSession.self,
                         QueuedQuestion.self,
                         ReadingSession.self,
                    configurations: localConfig
                )
            } catch {
                // Last resort: memory-only container to prevent crash
                logger.critical("❌ Failed to initialize persistent storage, using memory-only mode: \(error.localizedDescription)")
                isMemoryOnlyMode = true

                do {
                    let memoryConfig = ModelConfiguration(
                        isStoredInMemoryOnly: true
                    )

                    modelContainer = try ModelContainer(
                        for: BookModel.self,
                             CapturedNote.self,
                             CapturedQuote.self,
                             CapturedQuestion.self,
                             AmbientSession.self,
                             QueuedQuestion.self,
                             ReadingSession.self,
                        configurations: memoryConfig
                    )

                    logger.warning("⚠️ Running in memory-only mode - data will not persist")
                } catch {
                    // This should never happen with memory-only, but handle it
                    logger.critical("❌ Critical: Could not initialize even memory-only storage: \(error)")
                    // Create a minimal container as absolute last resort
                    do {
                        modelContainer = try ModelContainer(
                            for: BookModel.self,
                            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                        )
                    } catch {
                        // Should be unreachable — in-memory ModelContainer creation for a single model cannot fail
                        // Log the error for diagnostics, then force-try as absolute last resort
                        logger.critical("❌ Critical: Cannot create any ModelContainer: \(error)")
                        // swiftlint:disable:next force_try
                        modelContainer = try! ModelContainer(
                            for: BookModel.self
                        )
                    }
                }
            }
        }
    }

    // MARK: - Read Operations

    /// Load all library books from SwiftData
    func loadBooks() -> [Book] {
        // Return cached books if fresh
        if let cached = cachedBooks,
           let lastLoad = lastLoadTime,
           Date().timeIntervalSince(lastLoad) < cacheTimeout {
            return cached
        }

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { $0.isInLibrary == true }
        )

        guard var bookModels = try? context.fetch(descriptor) else {
            cachedBooks = []
            lastLoadTime = Date()
            return []
        }

        // Deduplicate BookModels if any share the same Google Books ID
        let grouped = Dictionary(grouping: bookModels) { $0.id }
        let hasDuplicates = grouped.values.contains { $0.count > 1 }
        if hasDuplicates {
            bookModels = deduplicateBookModels(grouped: grouped, context: context)
        }

        var books = bookModels.map { $0.asBook }

        // Safety net: if SwiftData is empty but UserDefaults has books, auto-migrate
        if books.isEmpty {
            let booksKey = "com.epilogue.savedBooks"
            if let data = UserDefaults.standard.data(forKey: booksKey),
               let udBooks = try? JSONDecoder().decode([Book].self, from: data),
               !udBooks.isEmpty {
                logger.warning("⚠️ SwiftData empty but UserDefaults has \(udBooks.count) books — auto-migrating")
                for book in udBooks {
                    let model = BookModel(from: book)
                    model.isInLibrary = true
                    context.insert(model)
                }
                try? context.save()
                books = udBooks
            }
        }

        cachedBooks = books
        lastLoadTime = Date()
        return books
    }

    /// Find a specific book by ID
    func findBook(id: String) -> Book? {
        loadBooks().first(where: { $0.id == id })
    }

    /// Deduplicate BookModels that share the same Google Books ID.
    /// Keeps the "best" copy (most data) and reassigns relationships from duplicates.
    private func deduplicateBookModels(grouped: [String: [BookModel]], context: ModelContext) -> [BookModel] {
        var keepers: [BookModel] = []

        for (_, models) in grouped {
            if models.count == 1 {
                keepers.append(models[0])
                continue
            }

            // Pick the best keeper: enriched > not enriched, most relationships > fewer
            let sorted = models.sorted { a, b in
                scoreForDedup(a) > scoreForDedup(b)
            }

            let keeper = sorted[0]
            keepers.append(keeper)

            // Reassign relationships from duplicates to keeper, then delete
            for duplicate in sorted.dropFirst() {
                // Reassign notes
                for note in duplicate.notes ?? [] {
                    note.book = keeper
                }
                // Reassign quotes
                for quote in duplicate.quotes ?? [] {
                    quote.book = keeper
                }
                // Reassign questions
                for question in duplicate.questions ?? [] {
                    question.book = keeper
                }
                // Reassign ambient sessions
                for session in duplicate.sessions ?? [] {
                    session.bookModel = keeper
                }
                // Reassign reading sessions
                for rs in duplicate.readingSessions ?? [] {
                    rs.bookModel = keeper
                }
                // Reassign insights
                for insight in duplicate.insights ?? [] {
                    insight.book = keeper
                }
                // Reassign memory entries
                for entry in duplicate.memoryEntries ?? [] {
                    entry.book = keeper
                }
                // Reassign memory threads
                for thread in duplicate.memoryThreads ?? [] {
                    thread.book = keeper
                }

                context.delete(duplicate)
            }

            logger.warning("⚠️ Deduplicated '\(keeper.title)' — removed \(sorted.count - 1) duplicate(s)")
        }

        try? context.save()
        return keepers
    }

    /// Score a BookModel for dedup ranking — higher score = more data = keep this one
    private func scoreForDedup(_ model: BookModel) -> Int {
        var score = 0
        if model.isEnriched { score += 100 }
        score += model.notes?.count ?? 0
        score += model.quotes?.count ?? 0
        score += model.questions?.count ?? 0
        score += model.sessions?.count ?? 0
        return score
    }

    // MARK: - Update Operations

    /// Update book status in SwiftData
    func updateBookStatus(_ bookId: String, status: ReadingStatus) async throws {
        logger.info("📚 Updating book status: \(bookId) → \(status.rawValue)")

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { $0.id == bookId }
        )

        guard let bookModel = try context.fetch(descriptor).first else {
            throw LibraryError.bookNotFound(bookId)
        }

        bookModel.readingStatus = status.rawValue
        try context.save()

        // Update Spotlight
        SpotlightIndexingService.shared.indexBook(bookModel.asBook)

        // Invalidate cache and notify UI
        cachedBooks = nil
        NotificationCenter.default.post(name: .refreshLibrary, object: nil)

        logger.info("✅ Book status updated successfully")
    }

    /// Update book rating in SwiftData
    func updateBookRating(_ bookId: String, rating: Double) async throws {
        logger.info("⭐️ Updating book rating: \(bookId) → \(rating)")

        let clampedRating = min(max(rating, 0.0), 5.0)

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { $0.id == bookId }
        )

        guard let bookModel = try context.fetch(descriptor).first else {
            throw LibraryError.bookNotFound(bookId)
        }

        bookModel.userRating = clampedRating
        try context.save()

        // Update Spotlight
        SpotlightIndexingService.shared.indexBook(bookModel.asBook)

        // Invalidate cache and notify UI
        cachedBooks = nil
        NotificationCenter.default.post(name: .refreshLibrary, object: nil)

        logger.info("✅ Book rating updated successfully")
    }

    /// Update current page in SwiftData
    func updateCurrentPage(_ bookId: String, page: Int) async throws {
        logger.info("📖 Updating current page: \(bookId) → \(page)")

        let validPage = max(0, page)

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { $0.id == bookId }
        )

        guard let bookModel = try context.fetch(descriptor).first else {
            throw LibraryError.bookNotFound(bookId)
        }

        bookModel.currentPage = validPage

        // Auto-mark as Read at 100%
        if let pageCount = bookModel.pageCount, pageCount > 0, validPage >= pageCount {
            bookModel.readingStatus = ReadingStatus.read.rawValue
        }

        try context.save()

        // Invalidate cache and notify UI
        cachedBooks = nil
        NotificationCenter.default.post(name: .refreshLibrary, object: nil)

        logger.info("✅ Current page updated successfully")
    }

    // MARK: - Delete Operations

    /// Delete book with cascade delete of all related data
    func deleteBook(_ bookId: String) async throws {
        logger.info("🗑️ Deleting book: \(bookId)")

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { $0.id == bookId }
        )

        guard let bookModel = try context.fetch(descriptor).first else {
            throw LibraryError.bookNotFound(bookId)
        }

        let title = bookModel.title

        // SwiftData cascade rules handle related data deletion
        // (notes, quotes, questions, sessions all have deleteRule: .cascade)
        context.delete(bookModel)
        try context.save()

        // Remove from Spotlight
        SpotlightIndexingService.shared.deindexBook(bookId)

        // Invalidate cache and notify UI
        cachedBooks = nil
        NotificationCenter.default.post(name: .refreshLibrary, object: nil)

        logger.info("✅ Book deleted successfully: '\(title)'")
    }

    // MARK: - Search Operations

    /// Intelligent search with fuzzy matching and ranking
    func searchBooks(query: String, limit: Int = 10) -> [Book] {
        let books = loadBooks()

        guard !query.isEmpty else { return books }

        // Tokenize query
        let queryTokens = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Score each book
        let scored = books.map { book -> (book: Book, score: Int) in
            var score = 0
            let title = book.title.lowercased()
            let author = book.author.lowercased()

            let titleTokens = title.components(separatedBy: .whitespacesAndNewlines)
            let authorTokens = author.components(separatedBy: .whitespacesAndNewlines)

            for queryToken in queryTokens {
                // Exact title match: +20
                if title == queryToken {
                    score += 20
                }
                // Title starts with query: +15
                else if title.hasPrefix(queryToken) {
                    score += 15
                }
                // Exact token match in title: +10
                else if titleTokens.contains(queryToken) {
                    score += 10
                }
                // Partial token match in title: +5
                else if titleTokens.contains(where: { $0.contains(queryToken) || queryToken.contains($0) }) {
                    score += 5
                }
                // Title contains query anywhere: +3
                else if title.contains(queryToken) {
                    score += 3
                }

                // Exact token match in author: +8
                if authorTokens.contains(queryToken) {
                    score += 8
                }
                // Partial token match in author: +4
                else if authorTokens.contains(where: { $0.contains(queryToken) || queryToken.contains($0) }) {
                    score += 4
                }
                // Author contains query anywhere: +2
                else if author.contains(queryToken) {
                    score += 2
                }
            }

            // Boost currently reading books
            if book.readingStatus == .currentlyReading {
                score += 3
            }

            return (book, score)
        }

        // Return top matches, sorted by score
        return scored
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.book }
    }

    /// Search across notes and quotes with intelligent ranking
    func searchNotes(query: String, limit: Int = 20) async -> [ContentSearchResult] {
        logger.info("🔍 Searching notes and quotes for: '\(query)'")

        guard !query.isEmpty else { return [] }

        let context = ModelContext(modelContainer)
        let books = loadBooks()

        // Tokenize query
        let queryTokens = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var results: [(result: ContentSearchResult, score: Int)] = []

        // Search quotes
        let quotesDescriptor = FetchDescriptor<CapturedQuote>()
        if let quotes = try? context.fetch(quotesDescriptor) {
            for quote in quotes {
                guard let text = quote.text,
                      let bookId = quote.book?.id,
                      let book = books.first(where: { $0.id == bookId }) else {
                    continue
                }

                let score = calculateMatchScore(text: text, queryTokens: queryTokens)
                if score > 0 {
                    results.append((
                        result: ContentSearchResult(
                            id: quote.id?.uuidString ?? UUID().uuidString,
                            text: text,
                            type: .quote,
                            bookTitle: book.title,
                            author: book.author,
                            bookId: book.id,
                            pageNumber: quote.pageNumber,
                            timestamp: nil
                        ),
                        score: score
                    ))
                }
            }
        }

        // Search notes
        let notesDescriptor = FetchDescriptor<CapturedNote>()
        if let notes = try? context.fetch(notesDescriptor) {
            for note in notes {
                guard let content = note.content,
                      let bookId = note.book?.id,
                      let book = books.first(where: { $0.id == bookId }) else {
                    continue
                }

                let score = calculateMatchScore(text: content, queryTokens: queryTokens)
                if score > 0 {
                    results.append((
                        result: ContentSearchResult(
                            id: note.id?.uuidString ?? UUID().uuidString,
                            text: content,
                            type: .note,
                            bookTitle: book.title,
                            author: book.author,
                            bookId: book.id,
                            pageNumber: nil,
                            timestamp: note.timestamp
                        ),
                        score: score
                    ))
                }
            }
        }

        logger.info("✅ Found \(results.count) matches")

        // Return top matches, sorted by score
        return results
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.result }
    }

    /// Calculate match score for search text
    private func calculateMatchScore(text: String, queryTokens: [String]) -> Int {
        var score = 0
        let lowercaseText = text.lowercased()
        let textTokens = lowercaseText.components(separatedBy: .whitespacesAndNewlines)

        for queryToken in queryTokens {
            // Exact phrase match in text: +30
            if lowercaseText.contains(queryToken) && queryToken.count > 3 {
                score += 30
            }

            // Exact word match: +20
            if textTokens.contains(queryToken) {
                score += 20
            }

            // Partial word match: +10
            if textTokens.contains(where: { $0.contains(queryToken) || queryToken.contains($0) }) {
                score += 10
            }

            // Contains anywhere: +5
            if lowercaseText.contains(queryToken) {
                score += 5
            }
        }

        return score
    }

    // MARK: - Export Operations

    /// Export notes and quotes for a book
    func exportNotes(bookId: String, format: ExportFormat = .standard) async throws -> String {
        logger.info("📤 Exporting notes for book: \(bookId), format: \(format)")

        guard let book = findBook(id: bookId) else {
            throw LibraryError.bookNotFound(bookId)
        }

        // Fetch quotes and notes from SwiftData
        let context = ModelContext(modelContainer)

        let quotesDescriptor = FetchDescriptor<CapturedQuote>(
            predicate: #Predicate { $0.book?.id == bookId },
            sortBy: [SortDescriptor(\CapturedQuote.pageNumber)]
        )
        let quotes = (try? context.fetch(quotesDescriptor)) ?? []

        let notesDescriptor = FetchDescriptor<CapturedNote>(
            predicate: #Predicate { $0.book?.id == bookId },
            sortBy: [SortDescriptor(\CapturedNote.timestamp, order: .reverse)]
        )
        let notes = (try? context.fetch(notesDescriptor)) ?? []

        logger.debug("  📊 Found \(quotes.count) quotes, \(notes.count) notes")

        // Generate markdown based on format
        switch format {
        case .standard:
            return generateStandardMarkdown(book: book, quotes: quotes, notes: notes)
        case .obsidian:
            return generateObsidianMarkdown(book: book, quotes: quotes, notes: notes)
        case .notion:
            return generateNotionMarkdown(book: book, quotes: quotes, notes: notes)
        }
    }

    // MARK: - Helper Methods

    private func generateStandardMarkdown(book: Book, quotes: [CapturedQuote], notes: [CapturedNote]) -> String {
        var markdown = "# \(book.title)\n\n"
        markdown += "**by \(book.author)**\n\n"

        if let description = book.description {
            markdown += "*\(description)*\n\n"
        }

        markdown += "---\n\n"

        if !quotes.isEmpty {
            markdown += "## Quotes (\(quotes.count))\n\n"
            for quote in quotes {
                if let text = quote.text {
                    markdown += "> \"\(text)\"\n"
                    if let page = quote.pageNumber {
                        markdown += ">\n> — Page \(page)\n"
                    }
                    markdown += "\n"
                }
            }
            markdown += "---\n\n"
        }

        if !notes.isEmpty {
            markdown += "## Notes (\(notes.count))\n\n"
            for note in notes {
                if let content = note.content {
                    markdown += "- \(content)\n"
                    if let timestamp = note.timestamp {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .short
                        markdown += "  *\(formatter.string(from: timestamp))*\n"
                    }
                }
            }
            markdown += "\n"
        }

        markdown += "---\n"
        markdown += "*Exported from Epilogue*\n"

        return markdown
    }

    private func generateObsidianMarkdown(book: Book, quotes: [CapturedQuote], notes: [CapturedNote]) -> String {
        var markdown = "---\n"
        markdown += "title: \(book.title)\n"
        markdown += "author: \(book.author)\n"
        markdown += "tags: [book, reading]\n"
        if let rating = book.userRating {
            markdown += "rating: \(rating)\n"
        }
        markdown += "status: \(book.readingStatus.rawValue)\n"
        markdown += "---\n\n"

        markdown += "# \(book.title)\n\n"
        markdown += "**Author:** [[\(book.author)]]\n"

        if let pageCount = book.pageCount {
            markdown += "**Pages:** \(pageCount)\n"
        }

        markdown += "\n## Highlights\n\n"

        for quote in quotes {
            if let text = quote.text {
                markdown += "- \(text)"
                if let page = quote.pageNumber {
                    markdown += " ^page-\(page)"
                }
                markdown += "\n"
            }
        }

        if !notes.isEmpty {
            markdown += "\n## My Notes\n\n"
            for note in notes {
                if let content = note.content {
                    markdown += "- \(content)\n"
                }
            }
        }

        markdown += "\n---\n"
        markdown += "Created with [Epilogue](https://epilogue.app)\n"

        return markdown
    }

    private func generateNotionMarkdown(book: Book, quotes: [CapturedQuote], notes: [CapturedNote]) -> String {
        var markdown = "# 📚 \(book.title)\n\n"

        // Property table
        markdown += "| Property | Value |\n"
        markdown += "|----------|-------|\n"
        markdown += "| Author | \(book.author) |\n"
        markdown += "| Status | \(book.readingStatus.rawValue) |\n"

        if let rating = book.userRating {
            let stars = String(repeating: "⭐️", count: Int(rating))
            markdown += "| Rating | \(stars) (\(rating)/5) |\n"
        }

        if let pageCount = book.pageCount {
            markdown += "| Pages | \(book.currentPage) / \(pageCount) |\n"
        }

        markdown += "\n---\n\n"

        if !quotes.isEmpty {
            markdown += "## 💭 Quotes\n\n"
            for (index, quote) in quotes.enumerated() {
                if let text = quote.text {
                    markdown += "### Quote \(index + 1)\n\n"
                    markdown += "> \(text)\n\n"
                    if let page = quote.pageNumber {
                        markdown += "📍 Page \(page)\n\n"
                    }
                }
            }
        }

        if !notes.isEmpty {
            markdown += "## 📝 Notes\n\n"
            for note in notes {
                if let content = note.content {
                    markdown += "- [ ] \(content)\n"
                }
            }
        }

        markdown += "\n---\n\n"
        markdown += "*Exported from Epilogue*\n"

        return markdown
    }
}

// MARK: - Content Search Result

/// Result from searching notes and quotes content
struct ContentSearchResult {
    let id: String
    let text: String
    let type: ContentSearchResultType
    let bookTitle: String
    let author: String
    let bookId: String
    let pageNumber: Int?
    let timestamp: Date?
}

/// Type of content search result
enum ContentSearchResultType {
    case quote
    case note
}

// MARK: - Export Format

enum ExportFormat: CustomStringConvertible {
    case standard
    case obsidian
    case notion

    var description: String {
        switch self {
        case .standard: return "Standard"
        case .obsidian: return "Obsidian"
        case .notion: return "Notion"
        }
    }
}

// MARK: - Errors

enum LibraryError: LocalizedError {
    case bookNotFound(String)
    case saveFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .bookNotFound(let id):
            return "Book not found: \(id)"
        case .saveFailed:
            return "Failed to save changes"
        case .deleteFailed:
            return "Failed to delete book"
        }
    }
}
