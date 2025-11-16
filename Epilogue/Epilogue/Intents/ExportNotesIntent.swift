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
        // Convert ExportFormatEnum to ExportFormat
        let exportFormat: ExportFormat
        switch format {
        case .standard:
            exportFormat = .standard
        case .obsidian:
            exportFormat = .obsidian
        case .notion:
            exportFormat = .notion
        }

        // Use LibraryService for consistent export with all 3 formats
        do {
            let markdown = try await LibraryService.shared.exportNotes(bookId: book.id, format: exportFormat)

            let formatName = format.rawValue
            let message = "Exported notes from '\(book.title)' in \(formatName) format"
            return .result(
                value: markdown,
                dialog: IntentDialog(stringLiteral: message)
            )

        } catch LibraryError.bookNotFound {
            throw IntentError.message("Could not find '\(book.title)' in your library")
        } catch {
            throw IntentError.message("Failed to export notes: \(error.localizedDescription)")
        }
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
