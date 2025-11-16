import AppIntents
import Foundation
import SwiftData

/// Siri Intent: "Delete this note" or "Remove note from Epilogue"
struct DeleteNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Delete Note"
    static var description = IntentDescription("Delete a note from your library")

    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Note")
    var note: NoteEntity

    @Parameter(
        title: "Confirm Deletion",
        description: "This will permanently delete the note.",
        default: false
    )
    var confirmDeletion: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Delete note") {
            \.$confirmDeletion
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Require explicit confirmation
        guard confirmDeletion else {
            throw IntentError.message("Deletion requires confirmation. This action cannot be undone.")
        }

        // Delete from SwiftData
        guard let container = try? ModelContainer(
            for: CapturedNote.self, CapturedQuote.self, CapturedQuestion.self, BookModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: false)
        ) else {
            throw IntentError.message("Could not access database")
        }

        let context = ModelContext(container)

        // Find the note by ID
        guard let noteUUID = UUID(uuidString: note.id) else {
            throw IntentError.message("Invalid note ID")
        }

        let descriptor = FetchDescriptor<CapturedNote>(
            predicate: #Predicate { $0.id == noteUUID }
        )

        guard let capturedNote = try? context.fetch(descriptor).first else {
            throw IntentError.message("Could not find note in database")
        }

        // Delete the note
        context.delete(capturedNote)

        do {
            try context.save()
            return .result(dialog: "Note deleted")
        } catch {
            throw IntentError.message("Failed to delete note: \(error.localizedDescription)")
        }
    }
}
