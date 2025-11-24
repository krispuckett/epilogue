import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AmbientActionRouter")

/// Routes ambient intents to generative actions
@MainActor
class AmbientActionRouter {
    private let modelContext: ModelContext
    private let templateGenerator: TemplateGenerator
    private let enrichmentService: BookEnrichmentService

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.templateGenerator = TemplateGenerator(modelContext: modelContext)
        self.enrichmentService = BookEnrichmentService.shared
    }

    // MARK: - Route Intent

    func routeIntent(
        _ generativeIntent: GenerativeIntent,
        currentBook: Book?,
        conversationHistory: [String]
    ) async -> AmbientAction {

        switch generativeIntent {
        case .template(let request):
            return await handleTemplateRequest(request, currentBook: currentBook)

        case .journey(let request):
            return await handleJourneyRequest(request)

        case .addBook(let request):
            return await handleAddBookRequest(request)

        case .analyzePatterns:
            return await handlePatternAnalysisRequest()
        }
    }

    // MARK: - Template Generation

    private func handleTemplateRequest(
        _ request: TemplateRequest,
        currentBook: Book?
    ) async -> AmbientAction {

        // Determine which book
        let book: Book
        if request.bookTitle.lowercased() == "current book" || request.bookTitle.isEmpty {
            guard let currentBook = currentBook else {
                return .error("No book is currently being read")
            }
            book = currentBook
        } else {
            // Search for book in library
            let descriptor = FetchDescriptor<Book>(
                predicate: #Predicate { book in
                    book.title.localizedStandardContains(request.bookTitle)
                }
            )
            guard let foundBook = try? modelContext.fetch(descriptor).first else {
                return .error("Book '\(request.bookTitle)' not found in library")
            }
            book = foundBook
        }

        // Check for enrichment
        guard let enrichment = book.getEnrichment(context: modelContext) else {
            // Start enrichment in background
            enrichmentService.enrichBookInBackground(book, context: modelContext)
            return .message("Preparing template for \(book.title). This may take a minute...")
        }

        // Check if template already exists
        if let existing = book.getTemplate(type: request.type, context: modelContext) {
            return .navigateToTemplate(existing, book: book)
        }

        // Generate template
        do {
            let template: GeneratedTemplate

            switch request.type {
            case .characters:
                template = try await templateGenerator.generateCharacterMap(
                    for: book,
                    enrichment: enrichment,
                    progress: book.readingProgress
                )

            case .guide:
                template = try await templateGenerator.generateReadingGuide(
                    for: book,
                    enrichment: enrichment,
                    progress: book.readingProgress
                )

            case .themes:
                template = try await templateGenerator.generateThemeTracker(
                    for: book,
                    enrichment: enrichment,
                    progress: book.readingProgress
                )

            case .plot:
                return .error("Plot timelines not yet implemented")
            }

            modelContext.insert(template)
            try modelContext.save()

            logger.info("✅ Generated \(request.type.rawValue) for \(book.title)")

            return .showTemplatePreview(TemplatePreviewModel(
                template: template,
                book: book
            ))

        } catch {
            logger.error("❌ Template generation failed: \(error.localizedDescription)")
            return .error("Failed to generate template: \(error.localizedDescription)")
        }
    }

    // MARK: - Journey Creation

    private func handleJourneyRequest(_ request: JourneyRequest) async -> AmbientAction {
        // For now, return a conversational flow to gather more info
        return .startConversationalFlow(.journeyBuilder(request))
    }

    // MARK: - Book Addition

    private func handleAddBookRequest(_ request: BookRequest) async -> AmbientAction {
        // Search for book (placeholder - needs actual implementation)
        return .showBookSearch(request)
    }

    // MARK: - Pattern Analysis

    private func handlePatternAnalysisRequest() async -> AmbientAction {
        // Analyze reading sessions (placeholder)
        return .message("Pattern analysis coming soon")
    }
}

// MARK: - Ambient Action Types

enum AmbientAction {
    // UI actions
    case showTemplatePreview(TemplatePreviewModel)
    case navigateToTemplate(GeneratedTemplate, book: Book)
    case showJourneyPreview(JourneyPreviewModel)
    case showBookSearch(BookRequest)

    // Conversational flows
    case startConversationalFlow(ConversationFlow)

    // Simple responses
    case message(String)
    case error(String)
}

enum ConversationFlow {
    case journeyBuilder(JourneyRequest)
    case bookSearch(BookRequest)
}

// MARK: - Preview Models

struct TemplatePreviewModel {
    let template: GeneratedTemplate
    let book: Book
}

struct JourneyPreviewModel {
    let title: String
    let books: [JourneyBookPreview]
}

struct JourneyBookPreview {
    let title: String
    let author: String
    let duration: String
    let reason: String
}
