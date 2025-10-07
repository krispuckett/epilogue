import AppIntents
import SwiftData

/// Siri Intent: "Log 20 pages read" or "I read 50 pages"
struct LogPagesIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Pages Read"
    static var description = IntentDescription("Track your reading progress")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Number of Pages")
    var pageCount: Int

    @Parameter(title: "Book")
    var book: BookEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$pageCount) pages read in \(\.$book)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let bookEntity = book else {
            throw IntentError.message("No book selected. Please specify which book you're reading.")
        }

        // Update book progress in UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              var books = try? JSONDecoder().decode([Book].self, from: data) else {
            throw IntentError.message("Could not load your library")
        }

        guard let index = books.firstIndex(where: { $0.id == bookEntity.id }) else {
            throw IntentError.message("Book not found in library")
        }

        // Update page count
        let oldPage = books[index].currentPage
        books[index].currentPage = min(oldPage + pageCount, books[index].pageCount ?? oldPage + pageCount)
        let newPage = books[index].currentPage

        // Check if book is now finished
        let isNowFinished = if let totalPages = books[index].pageCount {
            newPage >= totalPages
        } else {
            false
        }

        if isNowFinished && books[index].readingStatus != .read {
            books[index].readingStatus = .read
        }

        // Save back to UserDefaults
        if let encoded = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(encoded, forKey: "com.epilogue.savedBooks")
            UserDefaults.standard.synchronize()
        }

        // Create message
        var message = "Logged \(pageCount) pages for \(bookEntity.title)"
        if let totalPages = books[index].pageCount {
            let percentage = Int((Double(newPage) / Double(totalPages)) * 100)
            message += ". You're \(percentage)% done!"

            if isNowFinished {
                message += " 🎉 Congratulations, you finished the book!"
            }
        } else {
            message += ". You're now on page \(newPage)."
        }

        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
