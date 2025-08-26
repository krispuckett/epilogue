import SwiftData
import Foundation

@Model
final class Quote {
    @Attribute(.unique) var id: UUID
    var text: String
    var pageNumber: Int?
    var chapter: String?
    var dateCreated: Date
    var dateModified: Date
    var notes: String?
    var isFavorite: Bool
    var highlightColor: String?
    var tags: [String]
    
    var book: Book?
    
    init(
        text: String,
        book: Book,
        pageNumber: Int? = nil,
        chapter: String? = nil,
        notes: String? = nil,
        highlightColor: String? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.text = text
        self.book = book
        self.pageNumber = pageNumber
        self.chapter = chapter
        self.dateCreated = Date()
        self.dateModified = Date()
        self.notes = notes
        self.isFavorite = false
        self.highlightColor = highlightColor
        self.tags = tags
    }
    
    func toggleFavorite() {
        isFavorite.toggle()
        dateModified = Date()
    }
    
    func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
            dateModified = Date()
        }
    }
    
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        dateModified = Date()
    }
}