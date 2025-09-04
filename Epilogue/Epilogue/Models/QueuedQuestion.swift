import Foundation
import SwiftData

@Model
final class QueuedQuestion {
    var id: UUID
    var question: String
    var bookTitle: String?
    var bookAuthor: String?
    var timestamp: Date
    var priority: Int
    var processed: Bool
    var processingError: String?
    var response: String?
    var sessionContext: String?
    
    init(
        question: String,
        bookTitle: String? = nil,
        bookAuthor: String? = nil,
        priority: Int = 0,
        sessionContext: String? = nil
    ) {
        self.id = UUID()
        self.question = question
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.timestamp = Date()
        self.priority = priority
        self.processed = false
        self.sessionContext = sessionContext
    }
    
    // Convenience initializer for BookModel
    convenience init(
        question: String,
        bookModel: BookModel? = nil,
        priority: Int = 0,
        sessionContext: String? = nil
    ) {
        self.init(
            question: question,
            bookTitle: bookModel?.title,
            bookAuthor: bookModel?.author,
            priority: priority,
            sessionContext: sessionContext
        )
    }
    
    var bookContext: String {
        if let title = bookTitle, let author = bookAuthor {
            return "\(title) by \(author)"
        }
        return "General question"
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 86400 * 7 // 7 days
    }
}

extension QueuedQuestion: Comparable {
    static func < (lhs: QueuedQuestion, rhs: QueuedQuestion) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }
        return lhs.timestamp < rhs.timestamp
    }
    
    static func == (lhs: QueuedQuestion, rhs: QueuedQuestion) -> Bool {
        lhs.id == rhs.id
    }
}