import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Reading Progress Tool
/// Provides current reading progress information to the AI
#if canImport(FoundationModels)
@available(iOS 26.0, *)
struct ReadingProgressTool: Tool {
    let name = "getReadingProgress"
    let description = "Gets the user's current reading progress including page number, chapter, and session duration"

    @Generable
    struct Arguments {
        // No arguments needed - always returns current session info
    }

    struct ProgressResult: Codable {
        let currentPage: Int?
        let currentChapter: String?
        let sessionDuration: Int // minutes
        let bookTitle: String
        let bookAuthor: String
    }

    func call(arguments: Arguments) async throws -> String {
        // Get ambient context manager state
        let contextManager = await AmbientContextManager.shared
        let currentPage = await contextManager.currentPage
        let currentChapter = await contextManager.currentChapter

        // Get session manager state
        let processor = await TrueAmbientProcessor.shared
        let sessionActive = await processor.sessionActive

        guard sessionActive else {
            return "No active reading session"
        }

        // Get book context
        let book = await AmbientBookDetector.shared.detectedBook
        guard let book = book else {
            return "No book currently detected"
        }

        // Calculate session duration
        let sessionStart = Date() // TODO: Get actual session start time
        let duration = Int(Date().timeIntervalSince(sessionStart) / 60)

        // Build response
        var response = "Reading '\(book.title)' by \(book.author)"

        if let page = currentPage {
            response += "\nUser reports being on page \(page)"
        }

        if let chapter = currentChapter {
            response += "\nCurrently reading: \(chapter)"
        }

        response += "\nSession duration: \(duration) minutes"

        return response
    }
}

// MARK: - Conversation History Tool
/// Retrieves recent conversation history from ConversationMemory
@available(iOS 26.0, *)
struct ConversationHistoryTool: Tool {
    let name = "getConversationHistory"
    let description = "Retrieves recent questions and topics discussed in the current reading session"

    @Generable
    struct Arguments {
        @Guide(description: "Optional topic filter to search for specific subjects")
        var topicFilter: String?

        @Guide(description: "Number of recent items to retrieve", .range(1...10))
        var limit: Int = 5
    }

    func call(arguments: Arguments) async throws -> String {
        let memory = ConversationMemory.shared

        // Get recent memories
        let recentMemories = memory.getRecentContext(limit: arguments.limit)

        if recentMemories.isEmpty {
            return "No conversation history in this session yet"
        }

        var result: [String] = []

        for (index, memory) in recentMemories.enumerated() {
            let timeAgo = formatTimeAgo(memory.timestamp)

            // Filter by topic if specified
            if let filter = arguments.topicFilter?.lowercased() {
                let matchesTopic = memory.text.lowercased().contains(filter) ||
                                 memory.intent.entities.contains { $0.text.lowercased().contains(filter) }
                if !matchesTopic {
                    continue
                }
            }

            var entry = "\(index + 1). [\(timeAgo)] \(memory.text)"

            if let response = memory.response {
                entry += "\n   Response: \(response.prefix(100))..."
            }

            result.append(entry)
        }

        if result.isEmpty {
            return "No conversation history matching '\(arguments.topicFilter ?? "")'"
        }

        return "Recent conversation:\n" + result.joined(separator: "\n")
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}

// MARK: - Entity Mentions Tool
/// Finds all mentions of a specific character, location, or concept
@available(iOS 26.0, *)
struct EntityMentionsTool: Tool {
    let name = "findEntityMentions"
    let description = "Finds all mentions and discussions about a specific character, location, or concept in the current session"

    @Generable
    struct Arguments {
        @Guide(description: "The name of the character, location, or concept to search for")
        var entityName: String
    }

    func call(arguments: Arguments) async throws -> String {
        let memory = ConversationMemory.shared

        // Get context for this entity
        let entityContext = memory.getContextForEntities([arguments.entityName])

        if entityContext.isEmpty {
            return "No mentions of '\(arguments.entityName)' found in this session"
        }

        var result: [String] = []
        result.append("Found \(entityContext.count) mention(s) of '\(arguments.entityName)':")

        for (index, memory) in entityContext.enumerated() {
            let timeAgo = formatTimeAgo(memory.timestamp)
            result.append("\(index + 1). [\(timeAgo)] \(memory.text)")

            if let response = memory.response {
                result.append("   → \(response.prefix(150))...")
            }
        }

        return result.joined(separator: "\n")
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}

// MARK: - Related Captures Tool
/// Finds saved quotes and notes related to a topic
@available(iOS 26.0, *)
struct RelatedCapturesTool: Tool {
    let name = "findRelatedCaptures"
    let description = "Searches for saved quotes and notes related to a specific topic or theme"

    @Generable
    struct Arguments {
        @Guide(description: "The topic or theme to search for in saved quotes and notes")
        var topic: String

        @Guide(description: "Number of results to return", .range(1...10))
        var limit: Int = 5
    }

    func call(arguments: Arguments) async throws -> String {
        // Get current session
        let processor = await TrueAmbientProcessor.shared
        let sessionContent = await processor.detectedContent

        // Filter for quotes and notes
        let captures = sessionContent.filter { content in
            content.type == .quote || content.type == .note
        }

        if captures.isEmpty {
            return "No quotes or notes captured yet in this session"
        }

        // Search for topic
        let searchTerm = arguments.topic.lowercased()
        let matching = captures.filter { content in
            content.text.lowercased().contains(searchTerm)
        }

        if matching.isEmpty {
            return "No saved quotes or notes found related to '\(arguments.topic)'"
        }

        var result: [String] = []
        result.append("Found \(matching.count) capture(s) related to '\(arguments.topic)':")

        for (index, capture) in matching.prefix(arguments.limit).enumerated() {
            let typeIcon = capture.type == .quote ? "📝" : "💭"
            result.append("\(index + 1). \(typeIcon) \(capture.text)")
        }

        return result.joined(separator: "\n")
    }
}

// MARK: - Active Thread Tool
/// Gets information about the current active conversation thread
@available(iOS 26.0, *)
struct ActiveThreadTool: Tool {
    let name = "getActiveThread"
    let description = "Gets information about the current active conversation thread and its topic"

    @Generable
    struct Arguments {
        // No arguments needed
    }

    func call(arguments: Arguments) async throws -> String {
        let memory = ConversationMemory.shared

        guard let activeThread = memory.getActiveThread() else {
            return "No active conversation thread"
        }

        var result: [String] = []
        result.append("Active thread: \(activeThread.topic)")
        result.append("Started: \(formatTimeAgo(activeThread.startTime))")
        result.append("Exchanges: \(activeThread.entries.count)")

        if !activeThread.primaryEntities.isEmpty {
            result.append("Discussing: \(activeThread.primaryEntities.joined(separator: ", "))")
        }

        // Show last few exchanges
        let recentEntries = activeThread.entries.suffix(3)
        if !recentEntries.isEmpty {
            result.append("\nRecent exchanges:")
            for (index, entry) in recentEntries.enumerated() {
                result.append("\(index + 1). \(entry.text.prefix(80))...")
            }
        }

        return result.joined(separator: "\n")
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}
#endif
