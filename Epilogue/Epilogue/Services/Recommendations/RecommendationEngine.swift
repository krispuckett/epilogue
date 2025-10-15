import Foundation
import SwiftData

/// Generates personalized book recommendations using taste profile + Perplexity AI
@MainActor
class RecommendationEngine {
    static let shared = RecommendationEngine()

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
        #if DEBUG
        print("🎯 Generating recommendations from taste profile...")
        #endif

        // Build Perplexity prompt from taste profile
        let prompt = buildPrompt(from: profile)
        #if DEBUG
        print("📝 Prompt: \(prompt.prefix(200))...")
        #endif

        // Query Perplexity
        let response = try await OptimizedPerplexityService.shared.chat(
            message: prompt,
            bookContext: nil as Book?
        )

        #if DEBUG
        print("✅ Received recommendation response")
        #endif

        // Parse response into structured recommendations
        let recommendations = parseRecommendations(from: response)

        #if DEBUG
        print("📚 Parsed \(recommendations.count) recommendations")
        #endif

        // Enrich with Google Books data (cover images, years)
        let enriched = await enrichRecommendations(recommendations)

        return enriched
    }

    // MARK: - Prompt Building

    private func buildPrompt(from profile: LibraryTasteAnalyzer.TasteProfile) -> String {
        var prompt = "Based on a reader's library, recommend 10 books they would love.\n\n"

        // Add genre preferences
        if !profile.genres.isEmpty {
            let topGenres = profile.genres
                .sorted(by: { $0.value > $1.value })
                .prefix(5)
                .map { $0.key }
            prompt += "Favorite genres: \(topGenres.joined(separator: ", "))\n"
        }

        // Add favorite authors
        if !profile.authors.isEmpty {
            let topAuthors = profile.authors
                .sorted(by: { $0.value > $1.value })
                .prefix(5)
                .map { $0.key }
            prompt += "Authors they've read: \(topAuthors.joined(separator: ", "))\n"
        }

        // Add themes
        if !profile.themes.isEmpty {
            prompt += "Interested in themes: \(profile.themes.prefix(5).joined(separator: ", "))\n"
        }

        // Add reading level
        prompt += "Reading level: \(profile.readingLevel.rawValue)\n"

        // Add era preference
        if let era = profile.preferredEra {
            prompt += "Preferred era: \(era.rawValue)\n"
        }

        prompt += "\nFor each book, provide:\n"
        prompt += "1. Title\n"
        prompt += "2. Author\n"
        prompt += "3. One sentence explaining why they'd love it\n\n"
        prompt += "Format each as:\n"
        prompt += "BOOK: [Title] by [Author]\n"
        prompt += "WHY: [One sentence reason]\n\n"
        prompt += "Recommend books that match their taste but introduce them to new authors and perspectives."

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
            #if DEBUG
            print("⚠️ Structured format not found, trying numbered list...")
            #endif
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
        #if DEBUG
        print("🔍 Enriching \(recommendations.count) recommendations with Google Books data...")
        #endif

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
                #if DEBUG
                print("✅ Enriched: \(rec.title) with cover")
                #endif
            } else {
                // Keep original if no match found
                enriched.append(rec)
                #if DEBUG
                print("⚠️ No Google Books match for: \(rec.title)")
                #endif
            }
        }

        return enriched
    }
}
