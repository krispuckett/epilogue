import AppIntents
import Foundation

/// App Entity representing a book for Siri and Shortcuts
struct BookEntity: AppEntity {
    var id: String
    var title: String
    var author: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Book")

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "by \(author)"
        )
    }

    static var defaultQuery = BookQuery()
}

/// Query for finding books by title or author
struct BookQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BookEntity] {
        // Load books from UserDefaults (matching LibraryViewModel)
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            return []
        }

        return books
            .filter { identifiers.contains($0.id) }
            .map { BookEntity(id: $0.id, title: $0.title, author: $0.author) }
    }

    func suggestedEntities() async throws -> [BookEntity] {
        // Return currently reading books as suggestions
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            return []
        }

        return books
            .filter { $0.readingStatus == .currentlyReading }
            .prefix(5)
            .map { BookEntity(id: $0.id, title: $0.title, author: $0.author) }
    }
}
