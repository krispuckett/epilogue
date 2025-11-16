import AppIntents
import Foundation
import SwiftData

/// App Entity representing a captured quote
struct QuoteEntity: AppEntity {
    var id: String  // UUID string

    @Property(title: "Text")
    var text: String

    @Property(title: "Book Title")
    var bookTitle: String?

    @Property(title: "Author")
    var author: String?

    @Property(title: "Page Number")
    var pageNumber: Int?

    @Property(title: "Created")
    var timestamp: Date

    @Property(title: "Book ID")
    var bookId: String?

    @Property(title: "Is Favorite")
    var isFavorite: Bool

    @Property(title: "Notes")
    var notes: String?

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Quote")

    var displayRepresentation: DisplayRepresentation {
        var subtitle = ""
        if let book = bookTitle {
            subtitle = "from '\(book)'"
            if let page = pageNumber {
                subtitle += " (page \(page))"
            }
        }

        return DisplayRepresentation(
            title: "\(text)",
            subtitle: subtitle.isEmpty ? nil : "\(subtitle)",
            image: .init(systemName: "quote.bubble")
        )
    }

    static var defaultQuery = QuoteQuery()

    /// Create from CapturedQuote model
    @MainActor
    init(from quote: CapturedQuote, books: [Book]) {
        self.id = quote.id?.uuidString ?? UUID().uuidString
        self.text = quote.text ?? ""
        self.pageNumber = quote.pageNumber
        self.timestamp = quote.timestamp ?? Date()
        self.isFavorite = quote.isFavorite ?? false
        self.notes = quote.notes

        // Get book info
        if let bookId = quote.book?.id,
           let book = books.first(where: { $0.id == bookId }) {
            self.bookId = book.id
            self.bookTitle = book.title
            self.author = book.author
        } else {
            self.bookId = nil
            self.bookTitle = nil
            self.author = nil
        }
    }

    /// Custom initializer for direct construction
    init(id: String, text: String, bookTitle: String?, author: String?, pageNumber: Int?, timestamp: Date, bookId: String?, isFavorite: Bool, notes: String?) {
        self.id = id
        self.text = text
        self.bookTitle = bookTitle
        self.author = author
        self.pageNumber = pageNumber
        self.timestamp = timestamp
        self.bookId = bookId
        self.isFavorite = isFavorite
        self.notes = notes
    }
}

/// Query for finding quotes
struct QuoteQuery: EntityQuery, EnumerableEntityQuery {
    @MainActor
    func allEntities() async throws -> [QuoteEntity] {
        // Load books from UserDefaults for book context
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            return []
        }

        // Fetch all quotes from SwiftData
        guard let container = try? ModelContainer(
            for: CapturedNote.self, CapturedQuote.self, CapturedQuestion.self, BookModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        ) else {
            return []
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CapturedQuote>(
            sortBy: [SortDescriptor(\CapturedQuote.timestamp, order: .reverse)]
        )

        let quotes = (try? context.fetch(descriptor)) ?? []
        return quotes.map { QuoteEntity(from: $0, books: books) }
    }

    @MainActor
    func entities(for identifiers: [String]) async throws -> [QuoteEntity] {
        let all = try await allEntities()
        return all.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [QuoteEntity] {
        // Return recent quotes (last 10)
        let all = try await allEntities()
        return Array(all.prefix(10))
    }
}
