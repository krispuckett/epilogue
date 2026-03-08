import Foundation
import SwiftData

// MARK: - Book DNA
/// A compact, machine-readable profile of a book derived from the reader's activity
/// plus metadata. Powers personalized recommendations: "Find me another book that
/// feels like this one — for me, not in general."

@Model
final class BookDNA {
    var id: UUID = UUID()
    var bookModelId: String = "" // Links to BookModel.localId
    var bookTitle: String = ""
    var bookAuthor: String = ""

    // Theme analysis (weighted tags from user engagement)
    var themeWeights: [String] = [] // Stored as "theme:weight" pairs, e.g. "courage:0.8"
    var toneTags: [String] = [] // ["epic", "dark", "hopeful"]

    // Reading behavior profile
    var paceProfile: String = "moderate" // "fast", "moderate", "meditative", "variable"
    var averageSessionMinutes: Double = 0
    var ideaDensity: Double = 0 // 0-1, derived from highlights per page
    var discussionEnergy: Double = 0 // 0-1, derived from AI questions asked
    var personalResonance: Double = 0 // 0-1, how much user engaged overall

    // Content fingerprint
    var memoryClusters: [String] = [] // Key concepts from notes/quotes
    var topQuoteThemes: [String] = [] // Recurring themes in captured quotes

    // Stats
    var sessionCount: Int = 0
    var totalHighlights: Int = 0
    var totalNotes: Int = 0
    var totalQuestions: Int = 0
    var totalReadingMinutes: Double = 0

    // Timestamps
    var createdAt: Date = Date()
    var lastUpdated: Date = Date()

    init(bookModelId: String, bookTitle: String, bookAuthor: String) {
        self.bookModelId = bookModelId
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
    }
}
