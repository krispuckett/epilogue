import AppIntents
import Foundation
import SwiftData

/// Siri Intent: "Search my notes for stoicism" or "Find notes about meditation"
struct SearchNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Search Notes"
    static var description = IntentDescription("Search across all your personal notes")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Search Query")
    var query: String

    static var parameterSummary: some ParameterSummary {
        Summary("Search notes for \(\.$query)")
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
        let descriptor = FetchDescriptor<CapturedNote>()
        let allNotes = (try? context.fetch(descriptor)) ?? []

        // Search with intelligent ranking
        let queryLower = query.lowercased()
        let queryTokens = queryLower.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        let scored = allNotes.compactMap { note -> (note: CapturedNote, score: Int)? in
            guard let content = note.content else { return nil }

            var score = 0
            let contentLower = content.lowercased()

            for token in queryTokens {
                if contentLower.contains(token) && token.count > 3 {
                    score += 30  // Exact phrase match
                }
                if contentLower.components(separatedBy: .whitespacesAndNewlines).contains(token) {
                    score += 20  // Exact word match
                }
                if contentLower.contains(token) {
                    score += 5  // Contains anywhere
                }
            }

            return score > 0 ? (note, score) : nil
        }

        let results = scored
            .sorted { $0.score > $1.score }
            .prefix(20)
            .map { $0.note }

        let noteEntities = results.map { NoteEntity(from: $0, books: books) }

        if noteEntities.isEmpty {
            return .result(
                value: [],
                dialog: "No notes found matching '\(query)'"
            )
        }

        let message = if noteEntities.count == 1 {
            "Found 1 note matching '\(query)'"
        } else {
            "Found \(noteEntities.count) notes matching '\(query)'"
        }

        return .result(
            value: noteEntities,
            dialog: IntentDialog(stringLiteral: message)
        )
    }
}
