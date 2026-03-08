import Foundation
import SwiftData

// MARK: - Memory Card Model
/// Spaced repetition card for resurfacing quotes, notes, and insights.
/// Uses SM-2 algorithm for scheduling reviews.

@Model
final class MemoryCard {
    var id: UUID = UUID()
    var sourceType: String = "quote" // "quote", "note", "insight"
    var content: String = ""
    var bookTitle: String = ""
    var bookAuthor: String = ""
    var bookCoverURL: String?
    var bookLocalId: String? // Link to BookModel
    var bookColors: [String]? // Cached hex colors for gradient
    var createdAt: Date = Date()
    var lastReviewedAt: Date?
    var nextReviewDate: Date = Date()
    var reviewCount: Int = 0
    var easeFactor: Double = 2.5 // SM-2 algorithm default
    var interval: Int = 1 // Days until next review
    var connectionTags: [String]?
    var reflectionPrompt: String?
    var sourceQuoteId: String? // UUID string of source CapturedQuote
    var sourceNoteId: String? // UUID string of source CapturedNote
    var sourceInsightId: String? // ID string of source BookInsight

    init(content: String, sourceType: String, bookTitle: String, bookAuthor: String) {
        self.id = UUID()
        self.content = content
        self.sourceType = sourceType
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.createdAt = Date()
        self.nextReviewDate = Date()
        self.easeFactor = 2.5
        self.interval = 1
        self.reviewCount = 0
    }
}

// MARK: - Review Quality (SM-2 grades)

enum ReviewQuality: Int, CaseIterable {
    case again = 0  // Complete failure, reset
    case hard = 2   // Significant difficulty
    case good = 3   // Correct with some effort
    case easy = 5   // Perfect recall

    var label: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }

    var icon: String {
        switch self {
        case .again: return "arrow.counterclockwise"
        case .hard: return "tortoise.fill"
        case .good: return "checkmark"
        case .easy: return "bolt.fill"
        }
    }

    var color: String {
        switch self {
        case .again: return "red"
        case .hard: return "orange"
        case .good: return "green"
        case .easy: return "blue"
        }
    }
}
