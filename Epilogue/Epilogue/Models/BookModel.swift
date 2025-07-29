import Foundation
import SwiftData
import SwiftUI

// MARK: - SwiftData Book Model

@Model
final class BookModel {
    var id: String  // Google Books ID
    var localId: String  // Local UUID for linking
    var title: String
    var author: String
    var publishedYear: String?
    var coverImageURL: String?
    var isbn: String?
    var desc: String? // 'description' is reserved
    var pageCount: Int?
    
    // Reading status
    var isInLibrary: Bool
    var readingStatus: String // Store as string for SwiftData
    var currentPage: Int
    var userRating: Int?
    var userNotes: String?
    var dateAdded: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \CapturedNote.book)
    var notes: [CapturedNote]?
    
    @Relationship(deleteRule: .cascade, inverse: \CapturedQuote.book)
    var quotes: [CapturedQuote]?
    
    @Relationship(deleteRule: .cascade, inverse: \CapturedQuestion.book)
    var questions: [CapturedQuestion]?
    
    init(
        id: String,
        title: String,
        author: String,
        publishedYear: String? = nil,
        coverImageURL: String? = nil,
        isbn: String? = nil,
        description: String? = nil,
        pageCount: Int? = nil,
        localId: String? = nil
    ) {
        self.id = id
        self.localId = localId ?? UUID().uuidString
        self.title = title
        self.author = author
        self.publishedYear = publishedYear
        self.coverImageURL = coverImageURL
        self.isbn = isbn
        self.desc = description
        self.pageCount = pageCount
        self.isInLibrary = false
        self.readingStatus = ReadingStatus.wantToRead.rawValue
        self.currentPage = 0
        self.dateAdded = Date()
    }
    
    // Convert from the existing Book struct
    convenience init(from book: Book) {
        self.init(
            id: book.id,
            title: book.title,
            author: book.author,
            publishedYear: book.publishedYear,
            coverImageURL: book.coverImageURL,
            isbn: book.isbn,
            description: book.description,
            pageCount: book.pageCount,
            localId: book.localId.uuidString
        )
        self.isInLibrary = book.isInLibrary
        self.readingStatus = book.readingStatus.rawValue
        self.currentPage = book.currentPage
        self.userRating = book.userRating
        self.userNotes = book.userNotes
        self.dateAdded = book.dateAdded
    }
    
    // Convert to the existing Book struct for compatibility
    var asBook: Book {
        var book = Book(
            id: id,
            title: title,
            author: author,
            publishedYear: publishedYear,
            coverImageURL: coverImageURL,
            isbn: isbn,
            description: desc,
            pageCount: pageCount,
            localId: UUID(uuidString: localId) ?? UUID()
        )
        book.isInLibrary = isInLibrary
        book.readingStatus = ReadingStatus(rawValue: readingStatus) ?? .wantToRead
        book.currentPage = currentPage
        book.userRating = userRating
        book.userNotes = userNotes
        book.dateAdded = dateAdded
        return book
    }
}

// MARK: - Reading Status (moved from Book)

enum ReadingStatus: String, Codable, CaseIterable {
    case wantToRead = "Want to Read"
    case currentlyReading = "Currently Reading"
    case read = "Read"
    
    var icon: String {
        switch self {
        case .wantToRead: return "bookmark"
        case .currentlyReading: return "book"
        case .read: return "checkmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .wantToRead: return .blue
        case .currentlyReading: return .orange
        case .read: return .green
        }
    }
}