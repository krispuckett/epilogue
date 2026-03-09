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

        // Load book from SwiftData
        guard let targetBook = LibraryService.shared.findBook(id: bookEntity.id) else {
            throw IntentError.message("Book not found in library")
        }

        // Calculate new page
        let oldPage = targetBook.currentPage
        let newPage = min(oldPage + pageCount, targetBook.pageCount ?? oldPage + pageCount)

        // Check if book is now finished
        let isNowFinished = if let totalPages = targetBook.pageCount {
            newPage >= totalPages
        } else {
            false
        }

        // Update in SwiftData
        try await LibraryService.shared.updateCurrentPage(bookEntity.id, page: newPage)

        if isNowFinished && targetBook.readingStatus != .read {
            try await LibraryService.shared.updateBookStatus(bookEntity.id, status: .read)
        }

        // Create message
        var message = "Logged \(pageCount) pages for \(bookEntity.title)"
        if let totalPages = targetBook.pageCount {
            let percentage = Int((Double(newPage) / Double(totalPages)) * 100)
            message += ". You're \(percentage)% done!"

            if isNowFinished {
                message += " Congratulations, you finished the book!"
            }
        } else {
            message += ". You're now on page \(newPage)."
        }

        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
