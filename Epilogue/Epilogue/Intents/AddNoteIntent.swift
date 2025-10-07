import AppIntents
import SwiftData

/// Siri Intent: "Add a note to [book]"
struct AddNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Note"
    static var description = IntentDescription("Add a reading note to your current book")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Note Text")
    var noteText: String

    @Parameter(title: "Book")
    var book: BookEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Add note \(\.$noteText) to \(\.$book)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Get the model container
        guard let container = try? ModelContainer(
            for: BookModel.self, CapturedNote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        ) else {
            throw IntentError.message("Could not access database")
        }

        let context = ModelContext(container)

        // Find or create the book
        var bookModel: BookModel?
        if let bookEntity = book {
            // Try to find existing BookModel
            let entityId = bookEntity.id
            let descriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate { $0.id == entityId }
            )

            if let existing = try? context.fetch(descriptor).first {
                bookModel = existing
            } else {
                // Create new BookModel
                bookModel = BookModel(
                    id: bookEntity.id,
                    title: bookEntity.title,
                    author: bookEntity.author
                )
                context.insert(bookModel!)
            }
        }

        // Create the note
        let note = CapturedNote(content: noteText, book: bookModel)
        context.insert(note)

        // Save
        try context.save()

        // Index for Spotlight
        await SpotlightIndexingService.shared.indexNote(note)

        let message = if let bookTitle = bookModel?.title {
            "Note added to \(bookTitle)"
        } else {
            "Note saved successfully"
        }

        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

extension BookEntity {
    /// Default to the currently reading book
    static var currentBook: BookEntity? {
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data),
              let currentBook = books.first(where: { $0.readingStatus == .currentlyReading }) else {
            return nil
        }

        return BookEntity(
            id: currentBook.id,
            title: currentBook.title,
            author: currentBook.author
        )
    }
}

// MARK: - Intent Error
enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case message(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let text):
            return LocalizedStringResource(stringLiteral: text)
        }
    }
}
