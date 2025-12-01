import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "JourneyBuilder")

/// Builds reading journeys through multi-turn conversation
@MainActor
class ConversationalJourneyBuilder {
    private let modelContext: ModelContext
    private let journeyManager: ReadingJourneyManager
    private let intelligence: iOS26FoundationModels

    private var state: BuilderState = .gatheringIntent
    private var collectedInfo = JourneyBuildInfo()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.journeyManager = ReadingJourneyManager.shared
        self.intelligence = FoundationModelsManager.shared
    }

    // MARK: - Builder State

    enum BuilderState {
        case gatheringIntent     // What kind of journey?
        case clarifyingDetails   // Mood, theme, timeframe?
        case generatingJourney   // Creating journey
        case showingPreview      // Preview ready
    }

    struct JourneyBuildInfo {
        var theme: String?
        var mood: String?
        var author: String?
        var timeframe: String?
        var basedOnBooks: [Book] = []
    }

    // MARK: - Process User Response

    func processUserResponse(_ text: String) async -> BuilderResponse {
        logger.info("📝 Processing journey builder response in state: \(String(describing: state))")

        switch state {
        case .gatheringIntent:
            return await gatherIntent(from: text)

        case .clarifyingDetails:
            return await clarifyDetails(from: text)

        case .generatingJourney:
            return .message("Generating your journey...")

        case .showingPreview:
            return .message("Journey already generated")
        }
    }

    // MARK: - State Handlers

    private func gatherIntent(from text: String) async -> BuilderResponse {
        // Extract intent from user's response
        let lowercased = text.lowercased()

        // Look for theme mentions
        if lowercased.contains("classics") {
            collectedInfo.theme = "classics"
        } else if lowercased.contains("sci-fi") || lowercased.contains("science fiction") {
            collectedInfo.theme = "science fiction"
        } else if lowercased.contains("fantasy") {
            collectedInfo.theme = "fantasy"
        } else if lowercased.contains("mythology") {
            collectedInfo.theme = "mythology"
        }

        // Look for mood mentions
        if lowercased.contains("epic") {
            collectedInfo.mood = "epic"
        } else if lowercased.contains("light") || lowercased.contains("fun") {
            collectedInfo.mood = "light"
        } else if lowercased.contains("challenging") || lowercased.contains("demanding") {
            collectedInfo.mood = "challenging"
        }

        // Move to clarifying details
        state = .clarifyingDetails

        // Ask clarifying question
        var question = "Great! "
        if collectedInfo.theme != nil || collectedInfo.mood != nil {
            question += "I understand you want "
            if let theme = collectedInfo.theme {
                question += "\(theme) "
            }
            if let mood = collectedInfo.mood {
                question += "that's \(mood). "
            }
        }

        question += "How much time do you have? (e.g., 'summer reading', 'next 3 months', 'no rush')"

        return .question(question)
    }

    private func clarifyDetails(from text: String) async -> BuilderResponse {
        // Extract timeframe
        let lowercased = text.lowercased()

        if lowercased.contains("summer") {
            collectedInfo.timeframe = "summer (3 months)"
        } else if lowercased.contains("month") {
            collectedInfo.timeframe = "1 month"
        } else if lowercased.contains("year") {
            collectedInfo.timeframe = "1 year"
        } else {
            collectedInfo.timeframe = "flexible"
        }

        // Generate journey
        state = .generatingJourney

        guard let preview = await generateJourney() else {
            return .error("Failed to generate journey")
        }

        state = .showingPreview

        return .preview(preview)
    }

    // MARK: - Journey Generation

    private func generateJourney() async -> JourneyPreviewModel? {
        logger.info("🎯 Generating journey with info: \(String(describing: collectedInfo))")

        // Build prompt for journey generation
        let prompt = buildJourneyPrompt()

        do {
            let response = try await intelligence.generateText(prompt: prompt)
            let preview = try parseJourneyResponse(response)
            return preview
        } catch {
            logger.error("❌ Journey generation failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func buildJourneyPrompt() -> String {
        var prompt = "Create a reading journey"

        if let theme = collectedInfo.theme {
            prompt += " focused on \(theme)"
        }

        if let mood = collectedInfo.mood {
            prompt += " with a \(mood) tone"
        }

        if let timeframe = collectedInfo.timeframe {
            prompt += " for \(timeframe)"
        }

        prompt += """
        .

        Provide 3-5 books with:
        - Title and author
        - Reading duration estimate
        - Reason for inclusion

        Consider pacing (alternate heavy/light), themes, and progression.

        Return JSON:
        {
            "title": "journey title",
            "books": [
                {
                    "title": "string",
                    "author": "string",
                    "duration": "string",
                    "reason": "string"
                }
            ]
        }
        """

        return prompt
    }

    private func parseJourneyResponse(_ response: String) throws -> JourneyPreviewModel {
        guard let jsonData = response.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(JourneyResponse.self, from: jsonData) else {
            throw BuilderError.invalidResponse
        }

        let books = parsed.books.map { book in
            JourneyBookPreview(
                title: book.title,
                author: book.author,
                duration: book.duration,
                reason: book.reason
            )
        }

        return JourneyPreviewModel(
            title: parsed.title,
            books: books
        )
    }

    // MARK: - Create Journey

    func createJourney(from preview: JourneyPreviewModel) async -> ReadingJourney? {
        // Create actual journey using ReadingJourneyManager
        // For now, return nil (needs actual implementation)
        logger.info("📚 Creating journey: \(preview.title)")
        return nil
    }
}

// MARK: - Builder Response

enum BuilderResponse {
    case question(String)    // Ask user for more info
    case message(String)     // Informational message
    case preview(JourneyPreviewModel)  // Journey ready
    case error(String)       // Error occurred
}

enum BuilderError: LocalizedError {
    case invalidResponse
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Failed to parse journey response"
        case .generationFailed:
            return "Journey generation failed"
        }
    }
}

// MARK: - Response Parsing

private struct JourneyResponse: Decodable {
    let title: String
    let books: [BookData]

    struct BookData: Decodable {
        let title: String
        let author: String
        let duration: String
        let reason: String
    }
}
