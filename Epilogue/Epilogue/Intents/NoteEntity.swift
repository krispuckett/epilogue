import AppIntents
import Foundation
import SwiftData

/// App Entity representing a captured note
struct NoteEntity: AppEntity {
    var id: String  // UUID string

    @Property(title: "Content")
    var content: String

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

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Note")

    var displayRepresentation: DisplayRepresentation {
        var subtitle = ""
        if let book = bookTitle {
            subtitle = "from '\(book)'"
            if let page = pageNumber {
                subtitle += " (page \(page))"
            }
        }

        return DisplayRepresentation(
            title: "\(content)",
            subtitle: subtitle.isEmpty ? nil : "\(subtitle)",
            image: .init(systemName: "note.text")
        )
    }

    static var defaultQuery = NoteQuery()

    /// Create from CapturedNote model
    @MainActor
    init(from note: CapturedNote, books: [Book]) {
        self.id = note.id?.uuidString ?? UUID().uuidString
        self.content = note.content ?? ""
        self.pageNumber = note.pageNumber
        self.timestamp = note.timestamp ?? Date()
        self.isFavorite = note.isFavorite ?? false

        // Get book info
        if let bookId = note.book?.id,
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
    init(id: String, content: String, bookTitle: String?, author: String?, pageNumber: Int?, timestamp: Date, bookId: String?, isFavorite: Bool) {
        self.id = id
        self.content = content
        self.bookTitle = bookTitle
        self.author = author
        self.pageNumber = pageNumber
        self.timestamp = timestamp
        self.bookId = bookId
        self.isFavorite = isFavorite
    }
}

/// Query for finding notes
struct NoteQuery: EntityQuery, EnumerableEntityQuery {
    @MainActor
    func allEntities() async throws -> [NoteEntity] {
        // Load books from UserDefaults for book context
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            return []
        }

        // Fetch all notes from SwiftData
        guard let container = try? ModelContainer(
            for: CapturedNote.self, CapturedQuote.self, CapturedQuestion.self, BookModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        ) else {
            return []
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CapturedNote>(
            sortBy: [SortDescriptor(\CapturedNote.timestamp, order: .reverse)]
        )

        let notes = (try? context.fetch(descriptor)) ?? []
        return notes.map { NoteEntity(from: $0, books: books) }
    }

    @MainActor
    func entities(for identifiers: [String]) async throws -> [NoteEntity] {
        let all = try await allEntities()
        return all.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [NoteEntity] {
        // Return recent notes (last 10)
        let all = try await allEntities()
        return Array(all.prefix(10))
    }
}
