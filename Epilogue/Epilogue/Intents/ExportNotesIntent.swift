import AppIntents
import SwiftData
import Foundation

/// Siri Intent: "Export notes from [book]" or "Get markdown for [book]"
struct ExportNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Export Notes"
    static var description = IntentDescription("Export notes and quotes from a book as markdown")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Book")
    var book: BookEntity

    @Parameter(title: "Format", default: .standard)
    var format: ExportFormatEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Export notes from \(\.$book) as \(\.$format)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        // Get model container
        guard let container = try? ModelContainer(
            for: BookModel.self, CapturedQuote.self, CapturedNote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        ) else {
            throw IntentError.message("Could not access database")
        }

        let context = ModelContext(container)

        // Find BookModel
        let entityId = book.id
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { $0.id == entityId }
        )

        guard let bookModel = try? context.fetch(descriptor).first else {
            throw IntentError.message("Could not find '\(book.title)' in database")
        }

        // Fetch quotes
        let quotesDescriptor = FetchDescriptor<CapturedQuote>(
            predicate: #Predicate { $0.book?.id == entityId },
            sortBy: [SortDescriptor(\CapturedQuote.pageNumber)]
        )
        let quotes = (try? context.fetch(quotesDescriptor)) ?? []

        // Fetch notes
        let notesDescriptor = FetchDescriptor<CapturedNote>(
            predicate: #Predicate { $0.book?.id == entityId },
            sortBy: [SortDescriptor(\CapturedNote.timestamp, order: .reverse)]
        )
        let notes = (try? context.fetch(notesDescriptor)) ?? []

        // Generate markdown
        var markdown = "# \(book.title)\n\n"
        markdown += "**by \(book.author)**\n\n"
        markdown += "---\n\n"

        if !quotes.isEmpty {
            markdown += "## Quotes (\(quotes.count))\n\n"
            for quote in quotes {
                if let text = quote.text {
                    markdown += "> \"\(text)\"\n\n"
                    if let page = quote.pageNumber {
                        markdown += "Page \(page)\n\n"
                    }
                }
            }
        }

        if !notes.isEmpty {
            markdown += "## Notes (\(notes.count))\n\n"
            for note in notes {
                if let content = note.content {
                    markdown += "- \(content)\n"
                }
            }
            markdown += "\n"
        }

        markdown += "---\n"
        markdown += "*Exported from Epilogue*\n"

        let message = "Exported \(quotes.count) quotes and \(notes.count) notes from '\(book.title)'"
        return .result(
            value: markdown,
            dialog: IntentDialog(stringLiteral: message)
        )
    }
}

/// Export format enum for App Intents
enum ExportFormatEnum: String, AppEnum {
    case standard = "Standard"
    case obsidian = "Obsidian"
    case notion = "Notion"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Export Format")

    static var caseDisplayRepresentations: [ExportFormatEnum: DisplayRepresentation] = [
        .standard: "Standard Markdown",
        .obsidian: "Obsidian Format",
        .notion: "Notion Format"
    ]
}
