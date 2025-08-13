import Foundation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.epilogue", category: "ConversationMemory")

// MARK: - Conversation Memory System
public class ConversationMemory {
    
    // MARK: - Memory Entry
    public struct MemoryEntry {
        let id = UUID()
        let timestamp: Date
        let text: String
        let intent: EnhancedIntent
        let response: String?
        let bookContext: BookContext?
        let relatedEntries: [UUID] // Links to related memories
        
        struct BookContext {
            let title: String
            let author: String
            let chapter: Int?
            let page: Int?
        }
    }
    
    // MARK: - Conversation Thread
    public struct ConversationThread {
        let id = UUID()
        let startTime: Date
        var lastUpdateTime: Date
        let topic: String
        var entries: [MemoryEntry]
        let primaryEntities: [String]
        
        var duration: TimeInterval {
            lastUpdateTime.timeIntervalSince(startTime)
        }
        
        var isActive: Bool {
            // Thread is active if updated within last 5 minutes
            Date().timeIntervalSince(lastUpdateTime) < 300
        }
    }
    
    // MARK: - Properties
    private var memories: [MemoryEntry] = []
    private var threads: [ConversationThread] = []
    private var entityMap: [String: [UUID]] = [:] // Entity -> Memory IDs
    private var contextWindow: Int = 10 // Keep last 10 exchanges for context
    
    // Session tracking
    private let sessionStartTime = Date()
    private var lastInteractionTime = Date()
    
    public init() {
        logger.info("📚 Conversation Memory initialized")
    }
    
    // MARK: - Adding Memories
    public func addMemory(
        text: String,
        intent: EnhancedIntent,
        response: String? = nil,
        bookTitle: String? = nil,
        bookAuthor: String? = nil,
        chapter: Int? = nil,
        page: Int? = nil
    ) -> MemoryEntry {
        
        // Create book context if available
        let bookContext: MemoryEntry.BookContext?
        if let title = bookTitle {
            bookContext = MemoryEntry.BookContext(
                title: title,
                author: bookAuthor ?? "Unknown",
                chapter: chapter,
                page: page
            )
        } else {
            bookContext = nil
        }
        
        // Find related entries based on entities and timing
        let relatedEntries = findRelatedMemories(for: intent, within: 120) // Within 2 minutes
        
        // Create memory entry
        let memory = MemoryEntry(
            timestamp: Date(),
            text: text,
            intent: intent,
            response: response,
            bookContext: bookContext,
            relatedEntries: relatedEntries
        )
        
        // Store memory
        memories.append(memory)
        
        // Update entity map
        for entity in intent.entities {
            entityMap[entity.text, default: []].append(memory.id)
        }
        
        // Update or create thread
        updateThreads(with: memory)
        
        // Prune old memories if needed
        pruneMemoriesIfNeeded()
        
        lastInteractionTime = Date()
        
        logger.info("💭 Added memory: \(text.prefix(50))... [\(intent.primary.baseType)]")
        if !relatedEntries.isEmpty {
            logger.info("   Linked to \(relatedEntries.count) related memories")
        }
        
        return memory
    }
    
    // MARK: - Context Retrieval
    public func getRecentContext(limit: Int = 5) -> [MemoryEntry] {
        Array(memories.suffix(limit))
    }
    
    public func getContextForEntities(_ entities: [String]) -> [MemoryEntry] {
        let memoryIDs = entities.flatMap { entityMap[$0] ?? [] }
        return memories.filter { memoryIDs.contains($0.id) }
    }
    
    public func getActiveThread() -> ConversationThread? {
        threads.first { $0.isActive }
    }
    
    public func getThreadsAbout(_ topic: String) -> [ConversationThread] {
        threads.filter { thread in
            thread.topic.lowercased().contains(topic.lowercased()) ||
            thread.primaryEntities.contains { $0.lowercased().contains(topic.lowercased()) }
        }
    }
    
    // MARK: - Context Building for AI
    public func buildContextForResponse(currentIntent: EnhancedIntent) -> String {
        var contextParts: [String] = []
        
        // Add active thread context
        if let activeThread = getActiveThread() {
            contextParts.append("Current discussion thread: \(activeThread.topic)")
            
            // Add last few exchanges from thread
            let recentInThread = activeThread.entries.suffix(3)
            for entry in recentInThread {
                if let response = entry.response {
                    contextParts.append("Earlier: User asked '\(entry.text.prefix(50))...', You responded: '\(response.prefix(50))...'")
                }
            }
        }
        
        // Add entity-related context
        let entityContext = getContextForEntities(currentIntent.entities.map { $0.text })
        if !entityContext.isEmpty {
            let entityMentions = entityContext.prefix(2).map { entry in
                "Previously mentioned: \(entry.text.prefix(50))..."
            }
            contextParts.append(contentsOf: entityMentions)
        }
        
        // Add recent questions if current is also a question
        if case .question = currentIntent.primary {
            let recentQuestions = memories.suffix(5).filter { memory in
                if case .question = memory.intent.primary { return true }
                return false
            }
            
            if !recentQuestions.isEmpty {
                contextParts.append("Recent questions in this session:")
                for q in recentQuestions.prefix(2) {
                    contextParts.append("- \(q.text.prefix(50))...")
                }
            }
        }
        
        // Build final context string
        if contextParts.isEmpty {
            return ""
        }
        
        return "Session Context:\n" + contextParts.joined(separator: "\n")
    }
    
    // MARK: - Thread Management
    private func updateThreads(with memory: MemoryEntry) {
        // Check if this belongs to an active thread
        if let activeThread = threads.firstIndex(where: { $0.isActive }) {
            // Check if it's related to the thread topic
            let thread = threads[activeThread]
            let isRelated = memory.intent.entities.contains { entity in
                thread.primaryEntities.contains(entity.text)
            }
            
            if isRelated {
                threads[activeThread].entries.append(memory)
                threads[activeThread].lastUpdateTime = Date()
                logger.info("📎 Added to existing thread: \(thread.topic)")
                return
            }
        }
        
        // Create new thread if significant enough
        if case .question = memory.intent.primary {
            createNewThread(from: memory)
        } else if memory.intent.confidence > 0.7 {
            createNewThread(from: memory)
        }
    }
    
    private func createNewThread(from memory: MemoryEntry) {
        // Determine thread topic from entities or intent
        let topic: String
        if let primaryEntity = memory.intent.entities.first {
            topic = "Discussion about \(primaryEntity.text)"
        } else {
            topic = "General \(memory.intent.primary.baseType) thread"
        }
        
        let thread = ConversationThread(
            startTime: Date(),
            lastUpdateTime: Date(),
            topic: topic,
            entries: [memory],
            primaryEntities: memory.intent.entities.map { $0.text }
        )
        
        threads.append(thread)
        logger.info("🆕 Created new thread: \(topic)")
    }
    
    // MARK: - Related Memory Finding
    private func findRelatedMemories(for intent: EnhancedIntent, within seconds: TimeInterval) -> [UUID] {
        let cutoffTime = Date().addingTimeInterval(-seconds)
        
        return memories.filter { memory in
            // Must be recent
            guard memory.timestamp > cutoffTime else { return false }
            
            // Check for shared entities
            let sharedEntities = Set(intent.entities.map { $0.text })
                .intersection(Set(memory.intent.entities.map { $0.text }))
            
            if !sharedEntities.isEmpty {
                return true
            }
            
            // Check for same intent type
            if memory.intent.primary.baseType == intent.primary.baseType {
                return true
            }
            
            return false
        }.map { $0.id }
    }
    
    // MARK: - Memory Management
    private func pruneMemoriesIfNeeded() {
        // Keep only last 100 memories for performance
        if memories.count > 100 {
            let toRemove = memories.count - 100
            memories.removeFirst(toRemove)
            
            // Clean up entity map
            entityMap = entityMap.compactMapValues { ids in
                let filtered = ids.filter { id in
                    memories.contains { $0.id == id }
                }
                return filtered.isEmpty ? nil : filtered
            }
            
            logger.info("🧹 Pruned \(toRemove) old memories")
        }
        
        // Remove inactive threads older than 30 minutes
        let thirtyMinutesAgo = Date().addingTimeInterval(-1800)
        threads.removeAll { thread in
            !thread.isActive && thread.lastUpdateTime < thirtyMinutesAgo
        }
    }
    
    // MARK: - Session Summary
    public func generateSessionSummary() -> String {
        var summary: [String] = []
        
        summary.append("📚 Session Summary")
        summary.append("Duration: \(Int(Date().timeIntervalSince(sessionStartTime) / 60)) minutes")
        summary.append("Total interactions: \(memories.count)")
        
        // Count by intent type
        var intentCounts: [String: Int] = [:]
        for memory in memories {
            intentCounts[memory.intent.primary.baseType, default: 0] += 1
        }
        
        summary.append("\nActivity breakdown:")
        for (intent, count) in intentCounts.sorted(by: { $0.value > $1.value }) {
            summary.append("- \(intent.capitalized): \(count)")
        }
        
        // Most discussed entities
        let topEntities = entityMap
            .sorted { $0.value.count > $1.value.count }
            .prefix(5)
        
        if !topEntities.isEmpty {
            summary.append("\nMost discussed:")
            for (entity, memories) in topEntities {
                summary.append("- \(entity): \(memories.count) mentions")
            }
        }
        
        // Active threads
        let activeThreads = threads.filter { $0.isActive }
        if !activeThreads.isEmpty {
            summary.append("\nActive discussions:")
            for thread in activeThreads {
                summary.append("- \(thread.topic) (\(thread.entries.count) exchanges)")
            }
        }
        
        return summary.joined(separator: "\n")
    }
    
    // MARK: - Clear Memory
    public func clearSession() {
        memories.removeAll()
        threads.removeAll()
        entityMap.removeAll()
        logger.info("🧹 Session memory cleared")
    }
}