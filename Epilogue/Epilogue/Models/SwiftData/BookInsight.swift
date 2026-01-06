import Foundation
import SwiftData

// MARK: - Book Insight
/// Accumulated insights about a specific book from AI conversations.
/// Enables rich context when user returns to a book.

@Model
final class BookInsight {
    // MARK: - Core Identity
    var id: String = UUID().uuidString
    var timestamp: Date = Date()

    // MARK: - Insight Content
    var insightType: String = ""  // character, theme, plot, connection, confusion
    var content: String = ""
    var sourceContext: String = ""  // What triggered this insight

    // MARK: - Importance
    /// 1-5 scale of how important this insight is
    var importance: Int = 3

    // MARK: - Relationships
    @Relationship var book: BookModel?

    // MARK: - Initialization

    init(
        type: InsightType,
        content: String,
        sourceContext: String = "",
        importance: Int = 3,
        book: BookModel? = nil
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.insightType = type.rawValue
        self.content = content
        self.sourceContext = sourceContext
        self.importance = min(5, max(1, importance))
        self.book = book
    }

    // MARK: - Types

    enum InsightType: String, CaseIterable {
        case character = "character"      // Character-related insight
        case theme = "theme"              // Theme or symbolism
        case plot = "plot"                // Plot point discussion
        case connection = "connection"    // Connection to other works
        case confusion = "confusion"      // Something user struggled with
        case appreciation = "appreciation" // Something user especially enjoyed
    }

    var type: InsightType {
        InsightType(rawValue: insightType) ?? .theme
    }

    // MARK: - Convenience

    /// Age of insight in days
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: timestamp, to: Date()).day ?? 0
    }

    /// Build context string for this insight
    func buildContextString() -> String {
        switch type {
        case .character:
            return "User discussed character: \(content)"
        case .theme:
            return "User explored theme: \(content)"
        case .plot:
            return "User discussed: \(content)"
        case .connection:
            return "User connected this to: \(content)"
        case .confusion:
            return "User was confused about: \(content)"
        case .appreciation:
            return "User especially enjoyed: \(content)"
        }
    }
}
