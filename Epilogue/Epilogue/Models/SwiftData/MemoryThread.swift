import Foundation
import SwiftData

// MARK: - Memory Thread
/// Groups related conversation entries into coherent threads.
/// Enables "Yesterday we discussed X..." continuity.
/// Named MemoryThread to avoid conflict with AmbientSession.ConversationThread

@Model
final class MemoryThread {
    // MARK: - Core Identity
    var id: String = UUID().uuidString
    var topic: String = ""

    // MARK: - Timestamps
    var startTime: Date = Date()
    var lastUpdateTime: Date = Date()

    // MARK: - Summary
    /// AI-generated summary of the thread (for context injection)
    var summaryText: String = ""

    // MARK: - Primary Entities (comma-separated)
    /// Key entities discussed in this thread
    var primaryEntitiesRaw: String = ""

    var primaryEntities: [String] {
        get { primaryEntitiesRaw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
        set { primaryEntitiesRaw = newValue.joined(separator: ", ") }
    }

    // MARK: - State
    var isActive: Bool = true
    var entryCount: Int = 0

    // MARK: - Relationships
    @Relationship var entries: [ConversationMemoryEntry] = []
    @Relationship var book: BookModel?

    // MARK: - Initialization

    init(
        topic: String,
        book: BookModel? = nil
    ) {
        self.id = UUID().uuidString
        self.topic = topic
        self.startTime = Date()
        self.lastUpdateTime = Date()
        self.book = book
        self.isActive = true
    }

    // MARK: - Convenience

    /// Duration of this thread
    var duration: TimeInterval {
        lastUpdateTime.timeIntervalSince(startTime)
    }

    /// Age since last activity
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: lastUpdateTime, to: Date()).day ?? 0
    }

    /// Whether thread is stale and should be summarized
    var needsSummarization: Bool {
        ageInDays >= 7 && summaryText.isEmpty && entryCount > 0
    }

    /// Add an entry to this thread
    func addEntry(_ entry: ConversationMemoryEntry) {
        entries.append(entry)
        entry.thread = self
        lastUpdateTime = Date()
        entryCount = entries.count

        // Update primary entities
        var allEntities = Set(primaryEntities)
        allEntities.formUnion(entry.entities)
        primaryEntities = Array(allEntities.prefix(10))
    }

    /// Build context string for AI injection
    func buildContextString() -> String {
        if !summaryText.isEmpty {
            return summaryText
        }

        // Build from recent entries
        let recentEntries = entries.suffix(5)
        if recentEntries.isEmpty { return "" }

        let entryStrings = recentEntries.map { entry in
            "Q: \(entry.userText.prefix(100))\nA: \(entry.aiResponse.prefix(200))"
        }

        return """
        Previous discussion about \(topic):
        \(entryStrings.joined(separator: "\n---\n"))
        """
    }
}
