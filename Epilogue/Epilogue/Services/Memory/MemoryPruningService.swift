import Foundation
import SwiftData
import OSLog

// MARK: - Memory Pruning Service
/// Manages memory storage limits and summarizes old conversations.
/// Keeps memory bounded while preserving important context.

@MainActor
@Observable
final class MemoryPruningService {
    static let shared = MemoryPruningService()

    private let logger = Logger(subsystem: "com.epilogue", category: "MemoryPruning")

    // Configuration
    private let maxTotalEntries = 1000
    private let maxEntriesPerBook = 200
    private let threadSummarizationAgeDays = 7
    private let entryDeletionAgeDays = 30

    private var lastPruneDate: Date?
    private var isPruning = false

    private init() {}

    // MARK: - Pruning

    /// Check and prune if needed (called after saves)
    func pruneIfNeeded(context: ModelContext) async {
        // Only prune once per day
        if let lastPrune = lastPruneDate,
           Calendar.current.isDateInToday(lastPrune) {
            return
        }

        guard !isPruning else { return }
        isPruning = true
        defer { isPruning = false }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Check total entry count
        let totalCount = await countTotalEntries(context: context)
        if totalCount > maxTotalEntries {
            await pruneOldEntries(context: context, targetCount: maxTotalEntries - 100)
        }

        // Summarize old threads
        await summarizeOldThreads(context: context)

        // Delete summarized entries older than threshold
        await deleteOldSummarizedEntries(context: context)

        lastPruneDate = Date()

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("Memory pruning complete in \(String(format: "%.1f", duration))ms")
    }

    // MARK: - Counting

    private func countTotalEntries(context: ModelContext) async -> Int {
        let descriptor = FetchDescriptor<ConversationMemoryEntry>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Pruning Methods

    private func pruneOldEntries(context: ModelContext, targetCount: Int) async {
        logger.info("Pruning entries to target: \(targetCount)")

        // Fetch all entries sorted by date (oldest first)
        var descriptor = FetchDescriptor<ConversationMemoryEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        guard let entries = try? context.fetch(descriptor) else {
            return
        }

        let currentCount = entries.count
        if currentCount <= targetCount {
            return
        }

        // Calculate how many to delete
        let deleteCount = currentCount - targetCount

        // Delete oldest non-important entries
        var deleted = 0
        for entry in entries {
            if deleted >= deleteCount {
                break
            }

            // Skip important entries
            if entry.isImportant {
                continue
            }

            // Prefer deleting already-summarized entries
            if entry.hasBeenSummarized {
                context.delete(entry)
                deleted += 1
            }
        }

        // If we still need to delete more, delete non-important even if not summarized
        if deleted < deleteCount {
            for entry in entries {
                if deleted >= deleteCount {
                    break
                }
                if !entry.isImportant && !entry.hasBeenSummarized {
                    context.delete(entry)
                    deleted += 1
                }
            }
        }

        try? context.save()
        logger.info("Deleted \(deleted) old memory entries")
    }

    private func summarizeOldThreads(context: ModelContext) async {
        // Find threads older than threshold that need summarization
        let threshold = Calendar.current.date(byAdding: .day, value: -threadSummarizationAgeDays, to: Date()) ?? Date()

        var descriptor = FetchDescriptor<MemoryThread>(
            predicate: #Predicate<MemoryThread> { thread in
                thread.lastUpdateTime < threshold && thread.summaryText.isEmpty
            }
        )
        descriptor.fetchLimit = 10

        guard let threads = try? context.fetch(descriptor) else {
            return
        }

        for thread in threads {
            // Skip threads with no entries
            if thread.entries.isEmpty {
                continue
            }

            // Generate summary using Foundation Models (local, free)
            let summary = await generateThreadSummary(thread)

            if !summary.isEmpty {
                thread.summaryText = summary
                thread.isActive = false

                // Mark all entries as summarized
                for entry in thread.entries {
                    entry.hasBeenSummarized = true
                }

                logger.info("Summarized thread: \(thread.topic)")
            }
        }

        try? context.save()
    }

    private func generateThreadSummary(_ thread: MemoryThread) async -> String {
        // Build content from entries
        let entryContent = thread.entries.prefix(10).map { entry in
            "Q: \(entry.userText.prefix(100))\nA: \(entry.aiResponse.prefix(150))"
        }.joined(separator: "\n---\n")

        if entryContent.isEmpty {
            return ""
        }

        // Use Foundation Models for summarization (local, free)
        let prompt = """
        Summarize this reading discussion thread in 2-3 sentences. Focus on what was discussed and any key insights.

        Topic: \(thread.topic)
        \(entryContent)
        """

        // Use SmartEpilogueAI for local summarization
        let summary = await SmartEpilogueAI.shared.smartQuery(prompt)

        // If Foundation Models failed, create a simple summary
        if summary.isEmpty || summary.count < 20 {
            return "Discussed \(thread.topic) with \(thread.entryCount) exchanges. Key topics: \(thread.primaryEntities.prefix(3).joined(separator: ", "))."
        }

        return summary
    }

    private func deleteOldSummarizedEntries(context: ModelContext) async {
        let threshold = Calendar.current.date(byAdding: .day, value: -entryDeletionAgeDays, to: Date()) ?? Date()

        var descriptor = FetchDescriptor<ConversationMemoryEntry>(
            predicate: #Predicate<ConversationMemoryEntry> { entry in
                entry.hasBeenSummarized && !entry.isImportant && entry.timestamp < threshold
            }
        )
        descriptor.fetchLimit = 100

        guard let entries = try? context.fetch(descriptor) else {
            return
        }

        for entry in entries {
            context.delete(entry)
        }

        if !entries.isEmpty {
            try? context.save()
            logger.info("Deleted \(entries.count) old summarized entries")
        }
    }

    // MARK: - Manual Cleanup

    /// Force full cleanup (for settings/debug)
    func forceCleanup(context: ModelContext) async {
        lastPruneDate = nil
        await pruneIfNeeded(context: context)
    }

    /// Get storage statistics
    func getStorageStats(context: ModelContext) async -> MemoryStats {
        let entryCount = await countTotalEntries(context: context)

        let threadDescriptor = FetchDescriptor<MemoryThread>()
        let threadCount = (try? context.fetchCount(threadDescriptor)) ?? 0

        let insightDescriptor = FetchDescriptor<BookInsight>()
        let insightCount = (try? context.fetchCount(insightDescriptor)) ?? 0

        return MemoryStats(
            totalEntries: entryCount,
            totalThreads: threadCount,
            totalInsights: insightCount,
            maxEntries: maxTotalEntries
        )
    }

    struct MemoryStats {
        let totalEntries: Int
        let totalThreads: Int
        let totalInsights: Int
        let maxEntries: Int

        var usagePercentage: Double {
            Double(totalEntries) / Double(maxEntries)
        }
    }
}
