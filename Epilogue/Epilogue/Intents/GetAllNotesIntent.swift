import AppIntents
import Foundation
import SwiftData

/// Siri Intent: "Get all my notes" or "Show all my notes in Epilogue"
struct GetAllNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Get All Notes"
    static var description = IntentDescription("Get all notes from your entire library")

    static var openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Get all my notes")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[NoteEntity]> & ProvidesDialog {
        // Load books for context
        guard let data = UserDefaults.standard.data(forKey: "com.epilogue.savedBooks"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            throw IntentError.message("Could not load library")
        }

        // Fetch all notes from SwiftData
        guard let container = try? ModelContainer(
            for: CapturedNote.self, CapturedQuote.self, CapturedQuestion.self, BookModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        ) else {
            throw IntentError.message("Could not access database")
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CapturedNote>(
            sortBy: [SortDescriptor(\CapturedNote.timestamp, order: .reverse)]
        )

        let notes = (try? context.fetch(descriptor)) ?? []
        let noteEntities = notes.map { NoteEntity(from: $0, books: books) }

        if noteEntities.isEmpty {
            return .result(
                value: [],
                dialog: "You don't have any notes yet"
            )
        }

        let message = if noteEntities.count == 1 {
            "Found 1 note"
        } else {
            "Found \(noteEntities.count) notes across your library"
        }

        return .result(
            value: noteEntities,
            dialog: IntentDialog(stringLiteral: message)
        )
    }
}
