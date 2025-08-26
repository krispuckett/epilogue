import SwiftData
import Foundation

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var dateCreated: Date
    var dateModified: Date
    var tags: [String]
    var pageReference: Int?
    var chapterReference: String?
    var isPinned: Bool
    var attachmentData: [Data]? // For images or other attachments
    
    var book: Book?
    
    @Relationship(inverse: \Quote.relatedNote)
    var linkedQuotes: [Quote]?
    
    init(
        title: String,
        content: String,
        book: Book,
        tags: [String] = [],
        pageReference: Int? = nil,
        chapterReference: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.book = book
        self.dateCreated = Date()
        self.dateModified = Date()
        self.tags = tags
        self.pageReference = pageReference
        self.chapterReference = chapterReference
        self.isPinned = false
        self.attachmentData = []
        self.linkedQuotes = []
    }
    
    func updateContent(_ newContent: String) {
        self.content = newContent
        self.dateModified = Date()
    }
    
    func togglePin() {
        isPinned.toggle()
        dateModified = Date()
    }
    
    func linkQuote(_ quote: Quote) {
        if linkedQuotes == nil {
            linkedQuotes = []
        }
        if let quotes = linkedQuotes, !quotes.contains(where: { $0.id == quote.id }) {
            linkedQuotes?.append(quote)
            dateModified = Date()
        }
    }
}

extension Quote {
    var relatedNote: Note?
}