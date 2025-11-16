import AppIntents
import Foundation
import SwiftData

/// Siri Intent: "Delete this quote" or "Remove quote from Epilogue"
struct DeleteQuoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Delete Quote"
    static var description = IntentDescription("Delete a quote from your library")

    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Quote")
    var quote: QuoteEntity

    @Parameter(
        title: "Confirm Deletion",
        description: "This will permanently delete the quote.",
        default: false
    )
    var confirmDeletion: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Delete quote") {
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

        // Find the quote by ID
        guard let quoteUUID = UUID(uuidString: quote.id) else {
            throw IntentError.message("Invalid quote ID")
        }

        let descriptor = FetchDescriptor<CapturedQuote>(
            predicate: #Predicate { $0.id == quoteUUID }
        )

        guard let capturedQuote = try? context.fetch(descriptor).first else {
            throw IntentError.message("Could not find quote in database")
        }

        // Delete the quote
        context.delete(capturedQuote)

        do {
            try context.save()
            return .result(dialog: "Quote deleted")
        } catch {
            throw IntentError.message("Failed to delete quote: \(error.localizedDescription)")
        }
    }
}
