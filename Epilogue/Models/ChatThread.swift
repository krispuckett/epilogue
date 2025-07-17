import Foundation
import SwiftData

@Model
class ChatThread {
    var id: UUID = UUID()
    var bookId: UUID? // nil for general chat
    var bookTitle: String?
    var bookAuthor: String?
    var messages: [ThreadedChatMessage] = []
    var lastMessageDate: Date = Date()
    var createdDate: Date = Date()
    
    init(book: Book? = nil) {
        if let book = book {
            self.bookId = book.localId
            self.bookTitle = book.title
            self.bookAuthor = book.author
        }
    }
}

// Create a SwiftData compatible version of ChatMessage
@Model
class ThreadedChatMessage {
    var id: UUID = UUID()
    var content: String
    var isUser: Bool
    var timestamp: Date
    var bookTitle: String?
    var bookAuthor: String?
    
    init(content: String, isUser: Bool, timestamp: Date = Date(), bookTitle: String? = nil, bookAuthor: String? = nil) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
    }
}