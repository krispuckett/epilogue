import Foundation
import SwiftData

/// PROTOTYPE: Manages conversational book discovery chat
/// This is a minimal prototype to validate the design concept
@MainActor
class DiscoveryConversationService: ObservableObject {
    static let shared = DiscoveryConversationService()

    @Published var isProcessing = false
    @Published var lastError: Error?

    private init() {}

    // MARK: - Core Discovery Flow

    /// Handles a user message in discovery chat and returns AI response
    func handleMessage(
        _ userMessage: String,
        library: [BookModel],
        conversationHistory: [ConversationMessage] = []
    ) async throws -> DiscoveryResponse {
        isProcessing = true
        defer { isProcessing = false }

        // Step 1: Classify intent
        let intent = classifyIntent(userMessage)

        // Step 2: Build context from library if available
        let context = await buildContext(
            intent: intent,
            library: library,
            conversationHistory: conversationHistory
        )

        // Step 3: Generate response based on intent
        switch intent {
        case .needsClarification:
            return try await askClarifyingQuestion(userMessage, context: context)

        case .readyToRecommend(let criteria):
            return try await generateRecommendations(
                criteria: criteria,
                context: context,
                library: library
            )

        case .tellMeMore(let bookTitle):
            return try await provideBookDetails(bookTitle)
        }
    }

    // MARK: - Intent Classification

    enum UserIntent {
        case needsClarification
        case readyToRecommend(criteria: RecommendationCriteria)
        case tellMeMore(bookTitle: String)
    }

    struct RecommendationCriteria {
        var genre: String?
        var mood: String?
        var similarTo: String?
        var length: String?
        var specificRequest: String
    }

    private func classifyIntent(_ message: String) -> UserIntent {
        let lowercased = message.lowercased()

        // Check for "tell me more" requests
        if lowercased.contains("tell me more") || lowercased.contains("more about") {
            // Extract book title (simplified)
            return .tellMeMore(bookTitle: "Unknown")
        }

        // Check if request is specific enough
        let hasGenre = lowercased.contains("mystery") ||
                      lowercased.contains("fantasy") ||
                      lowercased.contains("sci-fi") ||
                      lowercased.contains("romance") ||
                      lowercased.contains("thriller")

        let hasMood = lowercased.contains("fast-paced") ||
                     lowercased.contains("slow") ||
                     lowercased.contains("light") ||
                     lowercased.contains("heavy") ||
                     lowercased.contains("fun") ||
                     lowercased.contains("serious")

        let hasComparison = lowercased.contains("like") ||
                           lowercased.contains("similar to")

        // If specific enough, ready to recommend
        if hasGenre || hasMood || hasComparison {
            let criteria = RecommendationCriteria(
                genre: extractGenre(from: lowercased),
                mood: extractMood(from: lowercased),
                similarTo: nil,
                length: nil,
                specificRequest: message
            )
            return .readyToRecommend(criteria: criteria)
        }

        // Otherwise needs clarification
        return .needsClarification
    }

    private func extractGenre(from text: String) -> String? {
        if text.contains("mystery") { return "Mystery" }
        if text.contains("fantasy") { return "Fantasy" }
        if text.contains("sci-fi") || text.contains("science fiction") { return "Science Fiction" }
        if text.contains("romance") { return "Romance" }
        if text.contains("thriller") { return "Thriller" }
        return nil
    }

    private func extractMood(from text: String) -> String? {
        if text.contains("fast-paced") || text.contains("quick") { return "Fast-paced" }
        if text.contains("slow") || text.contains("contemplative") { return "Contemplative" }
        if text.contains("light") || text.contains("fun") { return "Light" }
        if text.contains("heavy") || text.contains("serious") { return "Serious" }
        return nil
    }

    // MARK: - Context Building

    struct DiscoveryContext {
        let tasteProfile: LibraryTasteAnalyzer.TasteProfile?
        let recentBooks: [String]
        let conversationSummary: String
    }

    private func buildContext(
        intent: UserIntent,
        library: [BookModel],
        conversationHistory: [ConversationMessage]
    ) async -> DiscoveryContext {
        // Analyze library if it has books
        let tasteProfile: LibraryTasteAnalyzer.TasteProfile?
        if !library.isEmpty {
            tasteProfile = await LibraryTasteAnalyzer.shared.analyzeLibrary(books: library)
        } else {
            tasteProfile = nil
        }

        // Extract recent books
        let recentBooks = library
            .sorted(by: { ($0.lastOpened ?? Date.distantPast) > ($1.lastOpened ?? Date.distantPast) })
            .prefix(3)
            .map { "\($0.title) by \($0.author)" }

        // Summarize conversation
        let conversationSummary = conversationHistory
            .suffix(5)
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")

        return DiscoveryContext(
            tasteProfile: tasteProfile,
            recentBooks: Array(recentBooks),
            conversationSummary: conversationSummary
        )
    }

    // MARK: - Response Generation

    private func askClarifyingQuestion(
        _ userMessage: String,
        context: DiscoveryContext
    ) async throws -> DiscoveryResponse {
        // Simple clarifying questions based on what we know
        let question: String

        if context.tasteProfile == nil {
            // No library - ask basic question
            question = "I've got you! Are you thinking fiction or non-fiction?"
        } else {
            // Has library - ask about mood
            question = "What's the vibe - something gripping and fast-paced, or more thoughtful and literary?"
        }

        return DiscoveryResponse(
            text: question,
            recommendations: [],
            needsUserInput: true
        )
    }

    private func generateRecommendations(
        criteria: RecommendationCriteria,
        context: DiscoveryContext,
        library: [BookModel]
    ) async throws -> DiscoveryResponse {
        // Use existing RecommendationEngine if we have a taste profile
        if let profile = context.tasteProfile {
            let recs = try await RecommendationEngine.shared.generateRecommendations(for: profile)

            // Format as discovery response
            let text = "Based on your love of \(profile.genres.keys.first ?? "books"), here are some recommendations:"

            return DiscoveryResponse(
                text: text,
                recommendations: recs.prefix(3).map { BookRecommendation(from: $0) },
                needsUserInput: false
            )
        } else {
            // No library - use Perplexity directly with criteria
            let prompt = buildRecommendationPrompt(from: criteria)
            let response = try await OptimizedPerplexityService.shared.chat(
                message: prompt,
                bookContext: nil as Book?
            )

            // Parse recommendations from response
            let recommendations = parseRecommendationsFromText(response)

            return DiscoveryResponse(
                text: "Here are some recommendations based on your request:",
                recommendations: recommendations,
                needsUserInput: false
            )
        }
    }

    private func provideBookDetails(_ bookTitle: String) async throws -> DiscoveryResponse {
        // Placeholder - would fetch details from Google Books
        let text = "Details about \(bookTitle) coming soon..."

        return DiscoveryResponse(
            text: text,
            recommendations: [],
            needsUserInput: false
        )
    }

    // MARK: - Prompt Building

    private func buildRecommendationPrompt(from criteria: RecommendationCriteria) -> String {
        var prompt = "Recommend 3 books for a reader who wants:\n"
        prompt += "\(criteria.specificRequest)\n\n"

        if let genre = criteria.genre {
            prompt += "Genre: \(genre)\n"
        }
        if let mood = criteria.mood {
            prompt += "Mood: \(mood)\n"
        }

        prompt += "\nFor each book provide:\n"
        prompt += "1. Title and Author\n"
        prompt += "2. Brief description (2-3 sentences, no spoilers)\n"
        prompt += "3. Why it fits their request (specific, personalized)\n\n"
        prompt += "Format as:\n"
        prompt += "BOOK: [Title] by [Author]\n"
        prompt += "DESCRIPTION: [Description]\n"
        prompt += "WHY: [Reasoning]\n\n"

        return prompt
    }

    // MARK: - Response Parsing

    private func parseRecommendationsFromText(_ text: String) -> [BookRecommendation] {
        var recommendations: [BookRecommendation] = []
        let lines = text.split(separator: "\n").map { String($0) }

        var currentTitle: String?
        var currentAuthor: String?
        var currentDescription: String?
        var currentReasoning: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.starts(with: "BOOK:") {
                let bookLine = trimmed.replacingOccurrences(of: "BOOK:", with: "").trimmingCharacters(in: .whitespaces)
                if let byRange = bookLine.range(of: " by ", options: .caseInsensitive) {
                    currentTitle = String(bookLine[..<byRange.lowerBound])
                    currentAuthor = String(bookLine[byRange.upperBound...])
                }
            }

            if trimmed.starts(with: "DESCRIPTION:") {
                currentDescription = trimmed.replacingOccurrences(of: "DESCRIPTION:", with: "").trimmingCharacters(in: .whitespaces)
            }

            if trimmed.starts(with: "WHY:") {
                currentReasoning = trimmed.replacingOccurrences(of: "WHY:", with: "").trimmingCharacters(in: .whitespaces)

                // Save complete recommendation
                if let title = currentTitle,
                   let author = currentAuthor,
                   let description = currentDescription,
                   let reasoning = currentReasoning {
                    recommendations.append(BookRecommendation(
                        title: title,
                        author: author,
                        description: description,
                        reasoning: reasoning
                    ))

                    // Reset
                    currentTitle = nil
                    currentAuthor = nil
                    currentDescription = nil
                    currentReasoning = nil
                }
            }
        }

        return recommendations
    }
}

// MARK: - Data Models

struct ConversationMessage {
    let role: String  // "user" or "assistant"
    let content: String
}

struct DiscoveryResponse {
    let text: String
    let recommendations: [BookRecommendation]
    let needsUserInput: Bool
}

struct BookRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let author: String
    let description: String
    let reasoning: String
    var coverURL: String?
    var year: String?

    init(title: String, author: String, description: String, reasoning: String) {
        self.title = title
        self.author = author
        self.description = description
        self.reasoning = reasoning
    }

    init(from recEngine: RecommendationEngine.Recommendation) {
        self.title = recEngine.title
        self.author = recEngine.author
        self.description = recEngine.reasoning  // Using reasoning as description
        self.reasoning = recEngine.reasoning
        self.coverURL = recEngine.coverURL
        self.year = recEngine.year
    }
}
