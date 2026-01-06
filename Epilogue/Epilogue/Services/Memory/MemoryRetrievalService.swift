import Foundation
import SwiftData
import OSLog

// MARK: - Memory Retrieval Service
/// Retrieves and builds context from persistent memory for AI prompts.
/// Enables "Yesterday we discussed..." continuity.

@MainActor
@Observable
final class MemoryRetrievalService {
    static let shared = MemoryRetrievalService()

    private let logger = Logger(subsystem: "com.epilogue", category: "MemoryRetrieval")
    private var modelContext: ModelContext?

    private init() {}

    // MARK: - Configuration

    func configure(with context: ModelContext) {
        self.modelContext = context
        logger.info("Memory retrieval configured")
    }

    // MARK: - Context Building

    /// Build persistent context for AI prompts
    func buildPersistentContext(
        for book: BookModel?,
        query: String,
        maxTokens: Int = 1000
    ) async -> String {
        guard let context = modelContext else {
            return ""
        }

        var contextParts: [String] = []

        // 1. User reading profile preferences
        if let profile = await getUserProfile(context: context) {
            let profileContext = profile.buildPreferenceContext()
            if !profileContext.isEmpty {
                contextParts.append("User preferences: \(profileContext)")
            }
        }

        // 2. Recent conversation history for this book
        if let book = book {
            let recentHistory = await getRecentBookHistory(book: book, context: context)
            if !recentHistory.isEmpty {
                contextParts.append(recentHistory)
            }

            // 3. Relevant book insights
            let insights = await getRelevantInsights(book: book, query: query, context: context)
            if !insights.isEmpty {
                contextParts.append(insights)
            }
        }

        // 4. Active thread context
        let threadContext = await getActiveThreadContext(book: book, context: context)
        if !threadContext.isEmpty {
            contextParts.append(threadContext)
        }

        // Combine and truncate if needed
        let fullContext = contextParts.joined(separator: "\n\n")

        // Rough token estimation (1 token ≈ 4 chars)
        let estimatedTokens = fullContext.count / 4
        if estimatedTokens > maxTokens {
            // Truncate from the beginning, keeping most recent
            let targetChars = maxTokens * 4
            return String(fullContext.suffix(targetChars))
        }

        return fullContext
    }

    // MARK: - Component Fetchers

    private func getUserProfile(context: ModelContext) async -> UserReadingProfile? {
        var descriptor = FetchDescriptor<UserReadingProfile>()
        descriptor.fetchLimit = 1

        return try? context.fetch(descriptor).first
    }

    private func getRecentBookHistory(book: BookModel, context: ModelContext) async -> String {
        // Fetch recent entries for this book
        var descriptor = FetchDescriptor<ConversationMemoryEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 10

        guard let entries = try? context.fetch(descriptor) else {
            return ""
        }

        // Filter to this book
        let bookEntries = entries.filter { $0.book?.id == book.id }

        if bookEntries.isEmpty {
            return ""
        }

        // Build history string
        var historyLines: [String] = []

        // Group by day
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for entry in bookEntries.prefix(5) {
            let entryDay = calendar.startOfDay(for: entry.timestamp)
            let dayDiff = calendar.dateComponents([.day], from: entryDay, to: today).day ?? 0

            let timePrefix: String
            switch dayDiff {
            case 0:
                timePrefix = "Earlier today"
            case 1:
                timePrefix = "Yesterday"
            default:
                timePrefix = "\(dayDiff) days ago"
            }

            // Truncate for context efficiency
            let shortQuestion = String(entry.userText.prefix(100))
            let shortAnswer = String(entry.aiResponse.prefix(200))

            historyLines.append("\(timePrefix): Asked about \"\(shortQuestion)...\" - discussed \(entry.topic)")
        }

        if historyLines.isEmpty {
            return ""
        }

        return """
        Recent reading discussions:
        \(historyLines.joined(separator: "\n"))
        """
    }

    private func getRelevantInsights(book: BookModel, query: String, context: ModelContext) async -> String {
        // Fetch insights for this book
        var descriptor = FetchDescriptor<BookInsight>(
            sortBy: [SortDescriptor(\.importance, order: .reverse)]
        )
        descriptor.fetchLimit = 20

        guard let insights = try? context.fetch(descriptor) else {
            return ""
        }

        // Filter to this book
        let bookInsights = insights.filter { $0.book?.id == book.id }

        if bookInsights.isEmpty {
            return ""
        }

        // Find relevant insights based on query
        let queryLower = query.lowercased()
        let relevantInsights = bookInsights.filter { insight in
            // Match by type based on query
            if queryLower.contains("character") && insight.type == .character {
                return true
            }
            if queryLower.contains("theme") && insight.type == .theme {
                return true
            }
            // Always include high-importance insights
            if insight.importance >= 4 {
                return true
            }
            // Match by content
            return insight.content.lowercased().contains(queryLower)
        }

        if relevantInsights.isEmpty {
            return ""
        }

        let insightStrings = relevantInsights.prefix(3).map { $0.buildContextString() }

        return """
        Previous insights about this book:
        \(insightStrings.joined(separator: "\n"))
        """
    }

    private func getActiveThreadContext(book: BookModel?, context: ModelContext) async -> String {
        var descriptor = FetchDescriptor<MemoryThread>(
            predicate: #Predicate<MemoryThread> { $0.isActive },
            sortBy: [SortDescriptor(\.lastUpdateTime, order: .reverse)]
        )
        descriptor.fetchLimit = 3

        guard let threads = try? context.fetch(descriptor) else {
            return ""
        }

        // Filter to book if provided
        let relevantThreads: [MemoryThread]
        if let book = book {
            relevantThreads = threads.filter { $0.book?.id == book.id }
        } else {
            relevantThreads = threads
        }

        if relevantThreads.isEmpty {
            return ""
        }

        // Use thread summaries if available
        let threadContexts = relevantThreads.compactMap { thread -> String? in
            let context = thread.buildContextString()
            return context.isEmpty ? nil : context
        }

        if threadContexts.isEmpty {
            return ""
        }

        return threadContexts.joined(separator: "\n\n")
    }

    // MARK: - Entity Search

    /// Find entries mentioning specific entities
    func findEntriesWithEntities(_ entities: [String], book: BookModel?) async -> [ConversationMemoryEntry] {
        guard let context = modelContext else { return [] }

        var descriptor = FetchDescriptor<ConversationMemoryEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 50

        guard let entries = try? context.fetch(descriptor) else {
            return []
        }

        // Filter by entities
        let matchingEntries = entries.filter { entry in
            let entryEntities = Set(entry.entities.map { $0.lowercased() })
            let searchEntities = Set(entities.map { $0.lowercased() })
            return !entryEntities.isDisjoint(with: searchEntities)
        }

        // Filter by book if provided
        if let book = book {
            return matchingEntries.filter { $0.book?.id == book.id }
        }

        return matchingEntries
    }
}
