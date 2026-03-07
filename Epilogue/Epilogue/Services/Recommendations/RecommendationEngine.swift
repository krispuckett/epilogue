import Foundation
import SwiftData
import OSLog

/// Generates personalized book recommendations using taste profile + Claude AI
/// Supports vibe-based matching for finding books with similar emotional resonance
@MainActor
class RecommendationEngine {
    static let shared = RecommendationEngine()

    private let logger = Logger(subsystem: "com.epilogue", category: "Recommendations")

    private init() {}

    // MARK: - Recommendation Result

    struct Recommendation: Identifiable, Codable {
        let id: String
        let title: String
        let author: String
        let reasoning: String
        let year: String?
        let coverURL: String?

        init(id: String = UUID().uuidString, title: String, author: String, reasoning: String, year: String? = nil, coverURL: String? = nil) {
            self.id = id
            self.title = title
            self.author = author
            self.reasoning = reasoning
            self.year = year
            self.coverURL = coverURL
        }
    }

    // MARK: - Generate Recommendations

    func generateRecommendations(for profile: LibraryTasteAnalyzer.TasteProfile) async throws -> [Recommendation] {
        logger.info("🎯 Generating recommendations from taste profile...")

        // Build prompt from taste profile
        let prompt = buildPrompt(from: profile)
        logger.info("📝 Prompt: \(prompt.prefix(200).description)...")

        // Use Claude for better quality recommendations
        let response = try await ClaudeService.shared.subscriberChat(
            message: prompt,
            systemPrompt: vibeSystemPrompt,
            maxTokens: 1500
        )

        logger.info("✅ Received recommendation response")

        // Parse response into structured recommendations
        let recommendations = parseRecommendations(from: response)
        logger.info("📚 Parsed \(recommendations.count) recommendations")

        // Enrich with Google Books data (cover images, years)
        let enriched = await enrichRecommendations(recommendations)

        return enriched
    }

    // MARK: - Vibe-Based Recommendations

    /// Find books with similar emotional resonance, themes, and atmosphere to a given book
    /// Uses Claude for deeper understanding of the book's essence
    func findSimilarVibes(to book: Book, count: Int = 5) async throws -> [Recommendation] {
        logger.info("🌊 Finding vibe matches for: \(book.title)")

        let prompt = buildVibePrompt(for: book)

        // Use Claude with subscription-appropriate model
        let response = try await ClaudeService.shared.subscriberChat(
            message: prompt,
            systemPrompt: vibeSystemPrompt,
            maxTokens: 1200
        )

        logger.info("✅ Received vibe recommendations from Claude")

        let recommendations = parseRecommendations(from: response)
        let limited = Array(recommendations.prefix(count))

        return await enrichRecommendations(limited)
    }

    /// Find books that evoke a specific mood or emotional experience
    func findBooksForMood(_ mood: String, context: String? = nil) async throws -> [Recommendation] {
        logger.info("🎭 Finding books for mood: \(mood)")

        let prompt = buildMoodPrompt(mood: mood, context: context)

        let response = try await ClaudeService.shared.subscriberChat(
            message: prompt,
            systemPrompt: vibeSystemPrompt,
            maxTokens: 1200
        )

        let recommendations = parseRecommendations(from: response)
        return await enrichRecommendations(recommendations)
    }

    // MARK: - Vibe Prompt Building

    private var vibeSystemPrompt: String {
        """
        You are a literary companion with deep understanding of books' emotional landscapes, themes, and atmospheres.

        Your superpower: Finding books that FEEL the same, even when they look completely different.

        When recommending, focus on:
        - The emotional journey and what it evokes in the reader
        - Atmosphere and mood - the feeling of being inside the book
        - Pacing and how time moves in the narrative
        - The way the prose feels - lyrical, spare, dense, propulsive
        - What lingers after the last page

        Examples of vibe matches:
        - The Odyssey → The Count of Monte Cristo (epic journeys of resilience and homecoming)
        - 1984 → The Handmaid's Tale (oppressive atmospheres, quiet resistance)
        - Project Hail Mary → The Martian (optimistic problem-solving, scientific wonder)

        NEVER just match by genre or author. Find the emotional thread that connects books across categories.
        The best recommendations surprise readers with unexpected connections.
        """
    }

    private func buildVibePrompt(for book: Book) -> String {
        var prompt = """
        I just finished reading "\(book.title)" by \(book.author) and I loved it.


        """

        // Add description if available for richer context
        if let description = book.description, !description.isEmpty {
            prompt += "About this book:\n\(description.prefix(400))\n\n"
        }

        prompt += """
        Please recommend 5 books that capture a similar VIBE - not necessarily the same genre or author, \
        but books that will make me feel the same way this one did.

        Think about:
        - The emotional journey and atmosphere
        - The pacing and narrative style
        - The thematic depth and what lingers after finishing
        - The overall reading experience

        DO NOT just recommend other books by the same author or obvious genre matches.
        I want surprising connections that will resonate emotionally.

        Format each recommendation as:
        BOOK: [Title] by [Author]
        WHY: [2-3 sentences explaining the emotional/thematic connection - what vibe do they share?]
        """

        return prompt
    }

    private func buildMoodPrompt(mood: String, context: String?) -> String {
        var prompt = """
        I'm looking for a book that will make me feel: \(mood)

        """

        if let context = context {
            prompt += "Context: \(context)\n\n"
        }

        prompt += """
        Recommend 5 books that will evoke this emotional experience. Focus on the reading experience \
        and how the book makes you feel, not just surface-level plot elements.

        Format each recommendation as:
        BOOK: [Title] by [Author]
        WHY: [2-3 sentences explaining how this book creates that feeling]
        """

        return prompt
    }

    // MARK: - Prompt Building

    private func buildPrompt(from profile: LibraryTasteAnalyzer.TasteProfile) -> String {
        var prompt = """
        Based on a reader's library, recommend 10 books they would love.

        IMPORTANT: Focus on VIBE and emotional resonance, not just genre matching.
        Think about:
        - The emotional journey and atmosphere they seem drawn to
        - The pacing and narrative style that works for them
        - Thematic depth and what lingers after finishing
        - The overall reading experience, not surface categories

        Find surprising connections - books that FEEL similar even if they look different on the shelf.


        """

        // Add genre preferences
        if !profile.genres.isEmpty {
            let topGenres = profile.genres
                .sorted(by: { $0.value > $1.value })
                .prefix(5)
                .map { $0.key }
            prompt += "Genres they gravitate toward: \(topGenres.joined(separator: ", "))\n"
        }

        // Add favorite authors
        if !profile.authors.isEmpty {
            let topAuthors = profile.authors
                .sorted(by: { $0.value > $1.value })
                .prefix(5)
                .map { $0.key }
            prompt += "Authors they've connected with: \(topAuthors.joined(separator: ", "))\n"
        }

        // Add themes
        if !profile.themes.isEmpty {
            prompt += "Themes that resonate: \(profile.themes.prefix(5).joined(separator: ", "))\n"
        }

        // Add reading level
        prompt += "Reading level: \(profile.readingLevel.rawValue)\n"

        // Add era preference
        if let era = profile.preferredEra {
            prompt += "Era preference: \(era.rawValue)\n"
        }

        prompt += """

        For each recommendation, explain what emotional or thematic chord it strikes based on their reading history.
        DON'T just recommend the same authors - find new voices that will resonate similarly.
        Think about pacing, atmosphere, and the overall reading experience.

        Format each as:
        BOOK: [Title] by [Author]
        WHY: [2-3 sentences explaining the vibe connection]
        """

        return prompt
    }

    // MARK: - Response Parsing

    private func parseRecommendations(from response: String) -> [Recommendation] {
        var recommendations: [Recommendation] = []

        // Split response into individual book blocks
        let lines = response.split(separator: "\n").map { String($0) }

        var currentTitle: String?
        var currentAuthor: String?
        var currentReasoning: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse "BOOK: Title by Author"
            if trimmed.starts(with: "BOOK:") {
                let bookLine = trimmed.replacingOccurrences(of: "BOOK:", with: "").trimmingCharacters(in: .whitespaces)

                if let byRange = bookLine.range(of: " by ", options: .caseInsensitive) {
                    currentTitle = String(bookLine[..<byRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    currentAuthor = String(bookLine[byRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            // Parse "WHY: Reasoning"
            if trimmed.starts(with: "WHY:") {
                currentReasoning = trimmed.replacingOccurrences(of: "WHY:", with: "").trimmingCharacters(in: .whitespaces)

                // Save complete recommendation
                if let title = currentTitle, let author = currentAuthor, let reasoning = currentReasoning {
                    recommendations.append(Recommendation(
                        title: title,
                        author: author,
                        reasoning: reasoning
                    ))

                    // Reset
                    currentTitle = nil
                    currentAuthor = nil
                    currentReasoning = nil
                }
            }
        }

        // Fallback: Try to parse numbered list format (1. Title by Author - Reason)
        if recommendations.isEmpty {
            logger.debug("Structured format not found, trying numbered list...")
            recommendations = parseNumberedList(from: response)
        }

        return recommendations
    }

    private func parseNumberedList(from response: String) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        let lines = response.split(separator: "\n").map { String($0) }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Match: "1. Title by Author - Reasoning" or "1. Title by Author: Reasoning"
            if let match = trimmed.range(of: #"^\d+\.\s*(.+?)\s+by\s+(.+?)[\s\-:]+(.+)$"#, options: .regularExpression) {
                let matched = String(trimmed[match])

                // Extract components
                let components = matched.components(separatedBy: " by ")
                if components.count >= 2 {
                    let titlePart = components[0].replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                    let rest = components[1]

                    // Split author and reasoning
                    let authorReasoningSplit = rest.components(separatedBy: CharacterSet(charactersIn: "-:"))
                    if authorReasoningSplit.count >= 2 {
                        let author = authorReasoningSplit[0].trimmingCharacters(in: .whitespaces)
                        let reasoning = authorReasoningSplit[1...].joined(separator: "").trimmingCharacters(in: .whitespaces)

                        recommendations.append(Recommendation(
                            title: titlePart,
                            author: author,
                            reasoning: reasoning
                        ))
                    }
                }
            }
        }

        return recommendations
    }

    // MARK: - Enrichment (Google Books Data)

    private func enrichRecommendations(_ recommendations: [Recommendation]) async -> [Recommendation] {
        logger.info("🔍 Enriching \(recommendations.count) recommendations with covers...")

        let booksService = EnhancedGoogleBooksService()
        var enriched: [Recommendation] = []

        for rec in recommendations {
            // Search Google Books for this title + author
            let query = "\(rec.title) \(rec.author)"
            let searchResults = await booksService.searchBooksWithRanking(query: query)

            if let firstResult = searchResults.first {
                // Enrich with cover URL and year
                enriched.append(Recommendation(
                    id: rec.id,
                    title: rec.title,
                    author: rec.author,
                    reasoning: rec.reasoning,
                    year: firstResult.publishedYear,
                    coverURL: firstResult.coverImageURL
                ))
            } else {
                // Keep original if no match found
                enriched.append(rec)
                logger.debug("No Google Books match for: \(rec.title)")
            }
        }

        return enriched
    }
}
