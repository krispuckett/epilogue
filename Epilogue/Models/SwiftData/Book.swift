import SwiftData
import Foundation

@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var isbn: String?
    var coverImageData: Data?
    var dateAdded: Date
    var lastOpened: Date?
    var readingProgress: Double // 0.0 to 1.0
    var totalPages: Int?
    var currentPage: Int?
    var genre: String?
    var publicationYear: Int?
    var publisher: String?
    var bookDescription: String?
    var rating: Int? // 1-5 stars
    
    @Relationship(deleteRule: .cascade, inverse: \Quote.book)
    var quotes: [Quote]?
    
    @Relationship(deleteRule: .cascade, inverse: \Note.book)
    var notes: [Note]?
    
    @Relationship(deleteRule: .cascade, inverse: \AISession.book)
    var aiSessions: [AISession]?
    
    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var readingSessions: [ReadingSession]?
    
    init(
        title: String,
        author: String,
        isbn: String? = nil,
        coverImageData: Data? = nil,
        genre: String? = nil,
        publicationYear: Int? = nil,
        publisher: String? = nil,
        description: String? = nil,
        totalPages: Int? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.isbn = isbn
        self.coverImageData = coverImageData
        self.dateAdded = Date()
        self.lastOpened = nil
        self.readingProgress = 0.0
        self.totalPages = totalPages
        self.currentPage = 0
        self.genre = genre
        self.publicationYear = publicationYear
        self.publisher = publisher
        self.bookDescription = description
        self.rating = nil
        self.quotes = []
        self.notes = []
        self.aiSessions = []
        self.readingSessions = []
    }
    
    var progressPercentage: Int {
        Int(readingProgress * 100)
    }
    
    var estimatedTimeToFinish: TimeInterval? {
        guard let totalPages = totalPages,
              let currentPage = currentPage,
              currentPage > 0,
              let sessions = readingSessions,
              !sessions.isEmpty else { return nil }
        
        let totalReadingTime = sessions.reduce(0) { $0 + $1.duration }
        let averageTimePerPage = totalReadingTime / Double(currentPage)
        let remainingPages = totalPages - currentPage
        
        return averageTimePerPage * Double(remainingPages)
    }
}