import Foundation
import SwiftData
import SwiftUI

// MARK: - SwiftData Book Model

@Model
final class BookModel {
    var id: String = ""  // Google Books ID - Default for CloudKit
    var localId: String = UUID().uuidString  // Local UUID - Default for CloudKit
    var title: String = ""  // Default for CloudKit
    var author: String = ""  // Default for CloudKit
    var publishedYear: String?
    var coverImageURL: String?
    var isbn: String?
    var desc: String? // 'description' is reserved - from Google Books API
    var userDescription: String? // User-provided description (overrides desc if present)
    var pageCount: Int?

    // Offline cover image caching
    @Attribute(.externalStorage) var coverImageData: Data?

    // Smart enrichment (spoiler-free AI-generated context)
    var smartSynopsis: String?        // 2-3 sentences, NO spoilers
    var keyThemes: [String]?          // ["friendship", "courage", "sacrifice"]
    var majorCharacters: [String]?    // ["Frodo", "Sam", "Gandalf"] - just names
    var setting: String?              // "Middle Earth, Third Age"
    var tone: [String]?               // ["epic", "dark", "hopeful"]
    var literaryStyle: String?        // "High fantasy, allegorical"
    var enrichedAt: Date?             // When enrichment was fetched

    // Series metadata (from enrichment)
    var seriesName: String?           // "Harry Potter", "Lord of the Rings"
    var seriesOrder: Int?             // 1, 2, 3, etc.
    var totalBooksInSeries: Int?      // Total books in series

    // Color extraction for gradients (cached from cover)
    var extractedColors: [String]?  // Hex color strings

    // Reading status
    var isInLibrary: Bool = false  // Default for CloudKit
    var readingStatus: String = ReadingStatus.wantToRead.rawValue // Store as string for SwiftData
    var currentPage: Int = 0  // Default for CloudKit
    var userRating: Double?  // Supports half-star ratings (0.5 increments: 1.0, 1.5, 2.0, etc.)
    var userNotes: String?
    var dateAdded: Date = Date()  // Default for CloudKit
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \CapturedNote.book)
    var notes: [CapturedNote]?
    
    @Relationship(deleteRule: .cascade, inverse: \CapturedQuote.book)
    var quotes: [CapturedQuote]?
    
    @Relationship(deleteRule: .cascade, inverse: \CapturedQuestion.book)
    var questions: [CapturedQuestion]?
    
    @Relationship(deleteRule: .cascade, inverse: \AmbientSession.bookModel)
    var sessions: [AmbientSession]?

    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.bookModel)
    var readingSessions: [ReadingSession]?

    // Reading Journey relationship (inverse of JourneyBook.bookModel)
    @Relationship(deleteRule: .nullify, inverse: \JourneyBook.bookModel)
    var journeyBooks: [JourneyBook]?

    // Knowledge Graph relationship
    @Relationship(deleteRule: .nullify)
    var knowledgeNodes: [KnowledgeNode]?

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
        self.coverImageURL = coverImageURL  // Explicitly set the URL
        self.isbn = isbn
        self.desc = description
        self.pageCount = pageCount
        self.isInLibrary = false
        self.readingStatus = ReadingStatus.wantToRead.rawValue
        self.currentPage = 0
        self.dateAdded = Date()
        
        // Debug logging
        #if DEBUG
        if let url = coverImageURL, !url.isEmpty {
            print("✅ BookModel initialized with cover URL: \(url)")
        } else {
            print("⚠️ BookModel initialized WITHOUT cover URL for: \(title)")
        }
        #endif
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
        // Debug logging
        #if DEBUG
        if let url = coverImageURL, !url.isEmpty {
            print("✅ asBook conversion: BookModel has cover URL: \(url)")
        } else {
            print("⚠️⚠️⚠️ asBook conversion: BookModel has NO cover URL for: \(title)")
            print("   BookModel.coverImageURL = \(coverImageURL ?? "nil")")
        }
        #endif

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

        // Final verification
        #if DEBUG
        if book.coverImageURL != coverImageURL {
            print("❌❌❌ CRITICAL: Cover URL changed during conversion!")
            print("   BookModel.coverImageURL: \(coverImageURL ?? "nil")")
            print("   Book.coverImageURL: \(book.coverImageURL ?? "nil")")
        }
        #endif

        return book
    }

    // Check if book has been enriched with smart context
    var isEnriched: Bool {
        smartSynopsis != nil
    }

    // Computed property: return user description if available, otherwise Google Books description
    var effectiveDescription: String? {
        userDescription ?? desc
    }

    // Check if user has added custom description
    var hasUserDescription: Bool {
        userDescription != nil && !userDescription!.isEmpty
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

    /// Localized display name for UI
    var displayName: String {
        switch self {
        case .wantToRead: return "Want to Read"
        case .currentlyReading: return "Currently Reading"
        case .read: return "Read"
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