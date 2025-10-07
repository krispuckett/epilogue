import AppIntents

/// Siri Intent: "How many pages left in [book]?" or "What's my reading progress?"
struct GetReadingProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Reading Progress"
    static var description = IntentDescription("Check your reading progress")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Book")
    var book: BookEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Get reading progress for \(\.$book)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bookEntity = book else {
            throw IntentError.message("No book selected")
        }

        // Load books from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data),
              let targetBook = books.first(where: { $0.id == bookEntity.id }) else {
            throw IntentError.message("Book not found in library")
        }

        // Build progress message
        var message = "You're on page \(targetBook.currentPage)"

        if let totalPages = targetBook.pageCount {
            let pagesLeft = totalPages - targetBook.currentPage
            let percentage = Int((Double(targetBook.currentPage) / Double(totalPages)) * 100)

            message += " of \(totalPages)"

            if pagesLeft > 0 {
                message += ". \(pagesLeft) pages left to go. You're \(percentage)% done!"
            } else {
                message += ". You've finished this book! 🎉"
            }
        } else {
            message += " in \(bookEntity.title)"
        }

        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
