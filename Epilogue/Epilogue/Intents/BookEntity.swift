import AppIntents
import Foundation

/// Reading status enum for App Intents
enum ReadingStatusEnum: String, AppEnum {
    case wantToRead = "Want to Read"
    case currentlyReading = "Currently Reading"
    case read = "Read"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Reading Status")

    static var caseDisplayRepresentations: [ReadingStatusEnum: DisplayRepresentation] = [
        .wantToRead: DisplayRepresentation(
            title: "Want to Read",
            subtitle: "Books you plan to read",
            image: .init(systemName: "bookmark")
        ),
        .currentlyReading: DisplayRepresentation(
            title: "Currently Reading",
            subtitle: "Books you're reading now",
            image: .init(systemName: "book")
        ),
        .read: DisplayRepresentation(
            title: "Read",
            subtitle: "Books you've finished",
            image: .init(systemName: "checkmark.circle")
        )
    ]

    /// Convert to Book model's ReadingStatus
    func toReadingStatus() -> ReadingStatus {
        switch self {
        case .wantToRead: return .wantToRead
        case .currentlyReading: return .currentlyReading
        case .read: return .read
        }
    }

    /// Create from Book model's ReadingStatus
    init(from status: ReadingStatus) {
        switch status {
        case .wantToRead: self = .wantToRead
        case .currentlyReading: self = .currentlyReading
        case .read: self = .read
        }
    }
}

/// App Entity representing a book for Siri and Shortcuts
struct BookEntity: AppEntity {
    // Identifiers
    var id: String  // Google Books ID
    var localId: UUID

    // Core metadata
    @Property(title: "Title")
    var title: String

    @Property(title: "Author")
    var author: String

    @Property(title: "Published Year")
    var publishedYear: String?

    @Property(title: "ISBN")
    var isbn: String?

    @Property(title: "Description")
    var bookDescription: String?

    // Reading progress
    @Property(title: "Current Page")
    var currentPage: Int

    @Property(title: "Total Pages")
    var pageCount: Int?

    @Property(title: "Reading Status")
    var readingStatus: ReadingStatusEnum

    // User data
    @Property(title: "Rating")
    var userRating: Double?

    @Property(title: "Cover Image URL")
    var coverImageURL: String?

    @Property(title: "Date Added")
    var dateAdded: Date

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Book")

    var displayRepresentation: DisplayRepresentation {
        // Create display with cover image if available
        var display = DisplayRepresentation(
            title: "\(title)",
            subtitle: "by \(author)"
        )

        // Add cover image from URL if available
        if let urlString = coverImageURL,
           let url = URL(string: urlString) {
            display.image = .init(url: url)
        } else {
            display.image = .init(systemName: "book.closed")
        }

        return display
    }

    static var defaultQuery = BookQuery()

    /// Progress as percentage (0.0 to 1.0)
    var progress: Double {
        guard let total = pageCount, total > 0 else { return 0 }
        return Double(currentPage) / Double(total)
    }

    /// Pages remaining to read
    var pagesRemaining: Int {
        guard let total = pageCount else { return 0 }
        return max(0, total - currentPage)
    }

    /// Convenience initializer from Book model
    init(from book: Book) {
        self.id = book.id
        self.localId = book.localId
        self.title = book.title
        self.author = book.author
        self.publishedYear = book.publishedYear
        self.isbn = book.isbn
        self.bookDescription = book.description
        self.currentPage = book.currentPage
        self.pageCount = book.pageCount
        self.readingStatus = ReadingStatusEnum(from: book.readingStatus)
        self.userRating = book.userRating
        self.coverImageURL = book.coverImageURL
        self.dateAdded = book.dateAdded
    }
}

/// Query for finding books by title or author
struct BookQuery: EntityQuery, EnumerableEntityQuery {
    /// iOS 18+ optimization: System derives complex queries from this
    func allEntities() async throws -> [BookEntity] {
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            return []
        }

        return books.map { BookEntity(from: $0) }
    }

    /// Required: Find specific books by ID
    func entities(for identifiers: [String]) async throws -> [BookEntity] {
        let allBooks = try await allEntities()
        return allBooks.filter { identifiers.contains($0.id) }
    }

    /// Suggested books for Siri (currently reading + recently added)
    func suggestedEntities() async throws -> [BookEntity] {
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            return []
        }

        // Priority 1: Currently reading books
        let currentlyReading = books
            .filter { $0.readingStatus == .currentlyReading }
            .sorted { $0.dateAdded > $1.dateAdded }
            .map { BookEntity(from: $0) }

        // Priority 2: Want to read (recently added)
        let wantToRead = books
            .filter { $0.readingStatus == .wantToRead }
            .sorted { $0.dateAdded > $1.dateAdded }
            .prefix(3)
            .map { BookEntity(from: $0) }

        // Combine and limit to 8 suggestions
        return Array((currentlyReading + wantToRead).prefix(8))
    }

    /// Default sort: Currently Reading first, then by date added
    func defaultResult() async -> BookEntity? {
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            return nil
        }

        // Return the most recent "currently reading" book
        return books
            .filter { $0.readingStatus == .currentlyReading }
            .sorted { $0.dateAdded > $1.dateAdded }
            .first
            .map { BookEntity(from: $0) }
    }
}
