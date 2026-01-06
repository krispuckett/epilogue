import Foundation
import SwiftData
import OSLog

// MARK: - Memory Persistence Service
/// Handles saving and managing conversation memory entries.
/// Part of the AI Memory System.

@MainActor
@Observable
final class MemoryPersistenceService {
    static let shared = MemoryPersistenceService()

    private let logger = Logger(subsystem: "com.epilogue", category: "MemoryPersistence")
    private var modelContext: ModelContext?

    private init() {}

    // MARK: - Configuration

    func configure(with context: ModelContext) {
        self.modelContext = context
        logger.info("Memory persistence configured")
    }

    // MARK: - Entry Management

    /// Save a conversation exchange to memory
    func saveMemoryEntry(
        userText: String,
        aiResponse: String,
        intentType: String = "",
        topic: String = "",
        entities: [String] = [],
        isImportant: Bool = false,
        book: BookModel? = nil
    ) async {
        guard let context = modelContext else {
            logger.error("ModelContext not configured")
            return
        }

        // Create the entry
        let entry = ConversationMemoryEntry(
            userText: userText,
            aiResponse: aiResponse,
            intentType: intentType,
            topic: topic,
            entities: entities,
            isImportant: isImportant,
            book: book
        )

        // Find or create thread
        let thread = findOrCreateThread(
            topic: topic.isEmpty ? inferTopic(from: userText) : topic,
            book: book,
            context: context
        )

        // Add entry to thread
        thread.addEntry(entry)

        // Insert and save
        context.insert(entry)

        do {
            try context.save()
            logger.info("Saved memory entry: \(userText.prefix(50))...")

            // Check if pruning is needed
            await MemoryPruningService.shared.pruneIfNeeded(context: context)
        } catch {
            logger.error("Failed to save memory entry: \(error)")
        }
    }

    /// Find existing thread or create new one
    private func findOrCreateThread(
        topic: String,
        book: BookModel?,
        context: ModelContext
    ) -> MemoryThread {
        // Try to find an active thread with similar topic
        var descriptor = FetchDescriptor<MemoryThread>(
            predicate: #Predicate<MemoryThread> { thread in
                thread.isActive && thread.topic == topic
            },
            sortBy: [SortDescriptor(\.lastUpdateTime, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first {
            // Check if thread is recent enough to reuse (within 24 hours)
            if existing.ageInDays == 0 {
                return existing
            }
            // Mark old thread as inactive
            existing.isActive = false
        }

        // Create new thread
        let newThread = MemoryThread(topic: topic, book: book)
        context.insert(newThread)
        return newThread
    }

    /// Infer topic from user message
    private func inferTopic(from text: String) -> String {
        let textLower = text.lowercased()

        // Character discussion
        if textLower.contains("who is") || textLower.contains("character") {
            return "characters"
        }

        // Theme discussion
        if textLower.contains("theme") || textLower.contains("symbol") || textLower.contains("meaning") {
            return "themes"
        }

        // Plot discussion
        if textLower.contains("what happens") || textLower.contains("plot") || textLower.contains("story") {
            return "plot"
        }

        // Context/background
        if textLower.contains("context") || textLower.contains("history") || textLower.contains("author") {
            return "context"
        }

        // Confusion
        if textLower.contains("confused") || textLower.contains("understand") || textLower.contains("lost") {
            return "clarification"
        }

        return "general"
    }

    // MARK: - Query Helpers

    /// Get recent entries for a book
    func getRecentEntries(for book: BookModel?, limit: Int = 10) async -> [ConversationMemoryEntry] {
        guard let context = modelContext else { return [] }

        var descriptor = FetchDescriptor<ConversationMemoryEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            let entries = try context.fetch(descriptor)

            // Filter by book if provided
            if let book = book {
                return entries.filter { $0.book?.id == book.id }
            }
            return entries
        } catch {
            logger.error("Failed to fetch recent entries: \(error)")
            return []
        }
    }

    /// Get active threads for a book
    func getActiveThreads(for book: BookModel?, limit: Int = 5) async -> [MemoryThread] {
        guard let context = modelContext else { return [] }

        var descriptor = FetchDescriptor<MemoryThread>(
            predicate: #Predicate<MemoryThread> { $0.isActive },
            sortBy: [SortDescriptor(\.lastUpdateTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            let threads = try context.fetch(descriptor)

            if let book = book {
                return threads.filter { $0.book?.id == book.id }
            }
            return threads
        } catch {
            logger.error("Failed to fetch active threads: \(error)")
            return []
        }
    }

    /// Mark entry as important
    func markAsImportant(_ entry: ConversationMemoryEntry) {
        entry.isImportant = true
        try? modelContext?.save()
    }
}
