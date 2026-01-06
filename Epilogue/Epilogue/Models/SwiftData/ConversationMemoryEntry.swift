import Foundation
import SwiftData

// MARK: - Conversation Memory Entry
/// Persists individual conversation exchanges for memory across sessions.
/// Part of the AI Memory System for contextual continuity.

@Model
final class ConversationMemoryEntry {
    // MARK: - Core Identity
    var id: String = UUID().uuidString
    var timestamp: Date = Date()

    // MARK: - Content
    var userText: String = ""
    var aiResponse: String = ""

    // MARK: - Classification
    var intentType: String = ""  // e.g., "question", "discussion", "clarification"
    var topic: String = ""       // e.g., "character", "theme", "plot"

    // MARK: - Entities (stored as comma-separated)
    /// Key entities mentioned: character names, themes, locations, etc.
    var entitiesRaw: String = ""

    var entities: [String] {
        get { entitiesRaw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
        set { entitiesRaw = newValue.joined(separator: ", ") }
    }

    // MARK: - Importance
    /// Flag for entries that should be retained longer
    var isImportant: Bool = false

    // MARK: - Summarization
    /// If this entry has been summarized into a thread summary
    var hasBeenSummarized: Bool = false

    // MARK: - Relationships
    @Relationship var book: BookModel?
    @Relationship var thread: MemoryThread?

    // MARK: - Initialization

    init(
        userText: String,
        aiResponse: String,
        intentType: String = "",
        topic: String = "",
        entities: [String] = [],
        isImportant: Bool = false,
        book: BookModel? = nil
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.userText = userText
        self.aiResponse = aiResponse
        self.intentType = intentType
        self.topic = topic
        self.entitiesRaw = entities.joined(separator: ", ")
        self.isImportant = isImportant
        self.book = book
    }

    // MARK: - Convenience

    /// Age of this entry in days
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: timestamp, to: Date()).day ?? 0
    }

    /// Whether this entry can be pruned (old and not important)
    var canBePruned: Bool {
        !isImportant && hasBeenSummarized && ageInDays > 30
    }
}
