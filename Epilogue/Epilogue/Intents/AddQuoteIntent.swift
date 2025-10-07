import AppIntents
import SwiftData

/// Siri Intent: "Save a quote from [book]"
struct AddQuoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Save Quote"
    static var description = IntentDescription("Save a quote from your reading")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Quote Text")
    var quoteText: String

    @Parameter(title: "Book")
    var book: BookEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Save quote \(\.$quoteText) from \(\.$book)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Get the model container
        guard let container = try? ModelContainer(
            for: BookModel.self, CapturedQuote.self,
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

        // Create the quote
        let quote = CapturedQuote(
            text: quoteText,
            book: bookModel,
            author: bookModel?.author,
            pageNumber: nil,
            timestamp: Date(),
            source: .manual
        )
        context.insert(quote)

        // Save
        try context.save()

        // Index for Spotlight
        await SpotlightIndexingService.shared.indexQuote(quote)

        let message = if let bookTitle = bookModel?.title {
            "Quote saved from \(bookTitle)"
        } else {
            "Quote saved successfully"
        }

        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
