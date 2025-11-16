import AppIntents
import Foundation
import SwiftData

/// Siri Intent: "Get my notes from Meditations" or "Show notes for The Odyssey"
struct GetNotesForBookIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Notes for Book"
    static var description = IntentDescription("Get all notes captured for a specific book")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Book")
    var book: BookEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get notes from \(\.$book)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[NoteEntity]> & ProvidesDialog {
        // Load books for context
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            throw IntentError.message("Could not load library")
        }

        // Fetch notes from SwiftData for this specific book
        guard let container = try? ModelContainer(
            for: CapturedNote.self, CapturedQuote.self, CapturedQuestion.self, BookModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        ) else {
            throw IntentError.message("Could not access database")
        }

        let context = ModelContext(container)
        let bookId = book.id

        let descriptor = FetchDescriptor<CapturedNote>(
            predicate: #Predicate { $0.book?.id == bookId },
            sortBy: [SortDescriptor(\CapturedNote.timestamp, order: .reverse)]
        )

        let notes = (try? context.fetch(descriptor)) ?? []
        let noteEntities = notes.map { NoteEntity(from: $0, books: books) }

        if noteEntities.isEmpty {
            return .result(
                value: [],
                dialog: "No notes found for '\(book.title)'"
            )
        }

        let message = if noteEntities.count == 1 {
            "Found 1 note from '\(book.title)'"
        } else {
            "Found \(noteEntities.count) notes from '\(book.title)'"
        }

        return .result(
            value: noteEntities,
            dialog: IntentDialog(stringLiteral: message)
        )
    }
}
