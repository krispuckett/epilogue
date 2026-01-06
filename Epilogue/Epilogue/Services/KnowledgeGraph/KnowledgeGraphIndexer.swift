import Foundation
import SwiftData
import Combine
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "KnowledgeGraphIndexer")

// MARK: - Knowledge Graph Indexer
/// Manages the lifecycle of the knowledge graph:
/// - Initializes on app start
/// - Hooks into save flows
/// - Runs background indexing
/// - Generates periodic insights

@MainActor
final class KnowledgeGraphIndexer: ObservableObject {
    // MARK: - Singleton

    static let shared = KnowledgeGraphIndexer()

    // MARK: - Published State

    @Published var isInitialized = false
    @Published var indexingProgress: Double = 0
    @Published var isIndexing = false
    @Published var lastIndexDate: Date?
    @Published var statistics: KnowledgeGraphService.GraphStatistics?

    // MARK: - Dependencies

    private let graphService = KnowledgeGraphService.shared
    private let extractionService = EntityExtractionService.shared
    private let insightGenerator = ThematicInsightGenerator.shared

    // MARK: - Configuration

    private var modelContext: ModelContext?
    private let indexingDebounce: TimeInterval = 2.0  // Wait 2s after save before indexing
    private var pendingIndexTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - User Defaults Keys

    private let lastFullIndexKey = "com.epilogue.knowledgeGraph.lastFullIndex"
    private let indexedNoteIdsKey = "com.epilogue.knowledgeGraph.indexedNoteIds"
    private let indexedQuoteIdsKey = "com.epilogue.knowledgeGraph.indexedQuoteIds"
    private let indexedBookIdsKey = "com.epilogue.knowledgeGraph.indexedBookIds"

    // MARK: - Initialization

    private init() {}

    /// Configure and initialize the indexer
    func configure(with context: ModelContext) async {
        self.modelContext = context
        graphService.configure(with: context)

        // Load last index date
        if let timestamp = UserDefaults.standard.object(forKey: lastFullIndexKey) as? TimeInterval {
            lastIndexDate = Date(timeIntervalSince1970: timestamp)
        }

        // Update statistics
        try? await refreshStatistics()

        isInitialized = true
        logger.info("✅ KnowledgeGraphIndexer initialized")

        // Check if we need to run initial indexing
        await checkAndRunInitialIndexing()
    }

    // MARK: - Save Flow Integration

    /// Called when a note is saved - triggers async indexing
    func onNoteSaved(_ note: CapturedNote) {
        guard let noteId = note.id else { return }

        // Cancel any pending task for this note
        pendingIndexTasks[noteId]?.cancel()

        // Debounce: wait before indexing in case of rapid saves
        pendingIndexTasks[noteId] = Task {
            try? await Task.sleep(nanoseconds: UInt64(indexingDebounce * 1_000_000_000))

            guard !Task.isCancelled else { return }

            do {
                try await extractionService.extractAndIndex(note: note, book: note.book)
                markNoteAsIndexed(noteId)
                try? await refreshStatistics()
                logger.info("📊 Indexed note: \(noteId)")
            } catch {
                logger.warning("⚠️ Failed to index note: \(error.localizedDescription)")
            }

            pendingIndexTasks.removeValue(forKey: noteId)
        }
    }

    /// Called when a quote is saved - triggers async indexing
    func onQuoteSaved(_ quote: CapturedQuote) {
        guard let quoteId = quote.id else { return }

        pendingIndexTasks[quoteId]?.cancel()

        pendingIndexTasks[quoteId] = Task {
            try? await Task.sleep(nanoseconds: UInt64(indexingDebounce * 1_000_000_000))

            guard !Task.isCancelled else { return }

            do {
                try await extractionService.extractAndIndex(quote: quote, book: quote.book)
                markQuoteAsIndexed(quoteId)
                try? await refreshStatistics()
                logger.info("📊 Indexed quote: \(quoteId)")
            } catch {
                logger.warning("⚠️ Failed to index quote: \(error.localizedDescription)")
            }

            pendingIndexTasks.removeValue(forKey: quoteId)
        }
    }

    /// Called when a book is added or enriched
    func onBookUpdated(_ book: BookModel) {
        Task {
            do {
                try await extractionService.indexBook(book)
                markBookAsIndexed(book.id)
                try? await refreshStatistics()
                logger.info("📊 Indexed book: \(book.title)")
            } catch {
                logger.warning("⚠️ Failed to index book: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Background Indexing

    /// Run a full index of all content (for initial setup or recovery)
    func runFullIndex() async throws {
        guard let context = modelContext else {
            throw KnowledgeGraphError.notConfigured
        }

        isIndexing = true
        indexingProgress = 0
        defer { isIndexing = false }

        logger.info("🔄 Starting full knowledge graph index...")

        // Fetch all content
        let notesDescriptor = FetchDescriptor<CapturedNote>()
        let quotesDescriptor = FetchDescriptor<CapturedQuote>()
        let booksDescriptor = FetchDescriptor<BookModel>()

        let notes = try context.fetch(notesDescriptor)
        let quotes = try context.fetch(quotesDescriptor)
        let books = try context.fetch(booksDescriptor)

        let totalItems = notes.count + quotes.count + books.count
        var processedItems = 0

        // Index books first (they provide context)
        for book in books {
            if !isBookIndexed(book.id) {
                do {
                    try await extractionService.indexBook(book)
                    markBookAsIndexed(book.id)
                } catch {
                    logger.warning("⚠️ Failed to index book \(book.title): \(error.localizedDescription)")
                }
            }
            processedItems += 1
            indexingProgress = Double(processedItems) / Double(totalItems)
        }

        // Index notes
        for note in notes {
            guard let noteId = note.id else {
                processedItems += 1
                indexingProgress = Double(processedItems) / Double(totalItems)
                continue
            }
            if !isNoteIndexed(noteId) {
                do {
                    try await extractionService.extractAndIndex(note: note, book: note.book)
                    markNoteAsIndexed(noteId)
                } catch {
                    logger.warning("⚠️ Failed to index note: \(error.localizedDescription)")
                }
            }
            processedItems += 1
            indexingProgress = Double(processedItems) / Double(totalItems)

            // Small delay to avoid overwhelming the system
            try await Task.sleep(nanoseconds: 50_000_000)  // 0.05s
        }

        // Index quotes
        for quote in quotes {
            guard let quoteId = quote.id else { continue }
            if !isQuoteIndexed(quoteId) {
                do {
                    try await extractionService.extractAndIndex(quote: quote, book: quote.book)
                    markQuoteAsIndexed(quoteId)
                } catch {
                    logger.warning("⚠️ Failed to index quote: \(error.localizedDescription)")
                }
            }
            processedItems += 1
            indexingProgress = Double(processedItems) / Double(totalItems)

            try await Task.sleep(nanoseconds: 50_000_000)
        }

        // Update last index date
        lastIndexDate = Date()
        UserDefaults.standard.set(lastIndexDate!.timeIntervalSince1970, forKey: lastFullIndexKey)

        // Refresh statistics
        try await refreshStatistics()

        // Generate initial insights
        try? await insightGenerator.generateInsights()

        logger.info("✅ Full index complete: \(totalItems) items processed")
    }

    /// Index only new content since last index
    func runIncrementalIndex() async throws {
        guard let context = modelContext else {
            throw KnowledgeGraphError.notConfigured
        }

        isIndexing = true
        defer { isIndexing = false }

        logger.info("🔄 Running incremental index...")

        // Fetch unindexed content
        let notesDescriptor = FetchDescriptor<CapturedNote>()
        let quotesDescriptor = FetchDescriptor<CapturedQuote>()

        let allNotes = try context.fetch(notesDescriptor)
        let allQuotes = try context.fetch(quotesDescriptor)

        let unindexedNotes = allNotes.filter { note in
            guard let id = note.id else { return false }
            return !isNoteIndexed(id)
        }
        let unindexedQuotes = allQuotes.filter {
            guard let id = $0.id else { return false }
            return !isQuoteIndexed(id)
        }

        var indexed = 0

        for note in unindexedNotes {
            guard let noteId = note.id else { continue }
            do {
                try await extractionService.extractAndIndex(note: note, book: note.book)
                markNoteAsIndexed(noteId)
                indexed += 1
            } catch {
                logger.warning("⚠️ Incremental index failed for note: \(error.localizedDescription)")
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        for quote in unindexedQuotes {
            guard let quoteId = quote.id else { continue }
            do {
                try await extractionService.extractAndIndex(quote: quote, book: quote.book)
                markQuoteAsIndexed(quoteId)
                indexed += 1
            } catch {
                logger.warning("⚠️ Incremental index failed for quote: \(error.localizedDescription)")
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        try await refreshStatistics()

        logger.info("✅ Incremental index complete: \(indexed) new items")
    }

    // MARK: - Statistics

    func refreshStatistics() async throws {
        statistics = try graphService.getStatistics()
    }

    // MARK: - Private Helpers

    private func checkAndRunInitialIndexing() async {
        // If we've never done a full index and have content, run one
        if lastIndexDate == nil {
            do {
                let stats = try graphService.getStatistics()
                if stats.totalNodes == 0 {
                    // Check if there's content to index
                    guard let context = modelContext else { return }
                    let notesDescriptor = FetchDescriptor<CapturedNote>()
                    let notes = try context.fetch(notesDescriptor)

                    if !notes.isEmpty {
                        logger.info("📊 Content found, starting initial indexing...")
                        try await runFullIndex()
                    }
                }
            } catch {
                logger.warning("⚠️ Initial indexing check failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Indexed Content Tracking

    private var indexedNoteIds: Set<UUID> {
        get {
            guard let data = UserDefaults.standard.data(forKey: indexedNoteIdsKey),
                  let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) else {
                return []
            }
            return ids
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: indexedNoteIdsKey)
            }
        }
    }

    private var indexedQuoteIds: Set<UUID> {
        get {
            guard let data = UserDefaults.standard.data(forKey: indexedQuoteIdsKey),
                  let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) else {
                return []
            }
            return ids
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: indexedQuoteIdsKey)
            }
        }
    }

    private var indexedBookIds: Set<String> {
        get {
            guard let data = UserDefaults.standard.data(forKey: indexedBookIdsKey),
                  let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else {
                return []
            }
            return ids
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: indexedBookIdsKey)
            }
        }
    }

    private func isNoteIndexed(_ id: UUID) -> Bool {
        indexedNoteIds.contains(id)
    }

    private func isQuoteIndexed(_ id: UUID) -> Bool {
        indexedQuoteIds.contains(id)
    }

    private func isBookIndexed(_ id: String) -> Bool {
        indexedBookIds.contains(id)
    }

    private func markNoteAsIndexed(_ id: UUID) {
        var ids = indexedNoteIds
        ids.insert(id)
        indexedNoteIds = ids
    }

    private func markQuoteAsIndexed(_ id: UUID) {
        var ids = indexedQuoteIds
        ids.insert(id)
        indexedQuoteIds = ids
    }

    private func markBookAsIndexed(_ id: String) {
        var ids = indexedBookIds
        ids.insert(id)
        indexedBookIds = ids
    }

    /// Reset all indexing state (for debugging/recovery)
    func resetIndexingState() {
        UserDefaults.standard.removeObject(forKey: lastFullIndexKey)
        UserDefaults.standard.removeObject(forKey: indexedNoteIdsKey)
        UserDefaults.standard.removeObject(forKey: indexedQuoteIdsKey)
        UserDefaults.standard.removeObject(forKey: indexedBookIdsKey)
        lastIndexDate = nil
        statistics = nil
        graphService.clearCache()
        logger.info("🔄 Indexing state reset")
    }
}

// MARK: - App Lifecycle Integration

extension KnowledgeGraphIndexer {
    /// Call this when the app becomes active
    func onAppBecameActive() async {
        // Run incremental index to catch any missed content
        if isInitialized, lastIndexDate != nil {
            try? await runIncrementalIndex()
        }
    }

    /// Call this when the app goes to background
    func onAppWillResignActive() {
        // Cancel any pending tasks
        for (_, task) in pendingIndexTasks {
            task.cancel()
        }
        pendingIndexTasks.removeAll()
    }

    /// Periodic insight generation (call from a timer or background task)
    func generatePeriodicInsights() async {
        try? await insightGenerator.generateInsights()
    }
}
