import Foundation
import SwiftData

/// Enriches books with spoiler-free AI-generated context
/// Improves BookView summaries and Ambient mode understanding
@MainActor
class BookEnrichmentService {
    static let shared = BookEnrichmentService()

    private init() {}

    // MARK: - Enrichment Data

    struct EnrichmentData: Codable {
        let synopsis: String
        let themes: [String]
        let characters: [String]
        let setting: String
        let tone: [String]
        let style: String
        let seriesName: String?
        let seriesOrder: Int?
        let totalBooksInSeries: Int?
    }

    // MARK: - Main Enrichment Function

    func enrichBook(_ book: BookModel) async {
        // Skip if already enriched
        guard !book.isEnriched else {
            #if DEBUG
            print("ℹ️ Book already enriched: \(book.title)")
            #endif
            return
        }

        #if DEBUG
        print("🎨 [ENRICHMENT] Starting for '\(book.title)' by \(book.author)")
        #endif
        #if DEBUG
        print("   Book ID: \(book.id)")
        #endif
        #if DEBUG
        print("   Local ID: \(book.localId)")
        #endif

        do {
            #if DEBUG
            print("🌐 [ENRICHMENT] Fetching from Perplexity API...")
            #endif
            // Fetch enrichment from Perplexity
            let enrichment = try await fetchEnrichment(for: book)

            #if DEBUG
            print("✅ [ENRICHMENT] API call succeeded!")
            #endif
            #if DEBUG
            print("   Synopsis length: \(enrichment.synopsis.count) chars")
            #endif
            #if DEBUG
            print("   Themes count: \(enrichment.themes.count)")
            #endif
            #if DEBUG
            print("   Characters count: \(enrichment.characters.count)")
            #endif

            // Save to BookModel
            await MainActor.run {
                book.smartSynopsis = enrichment.synopsis
                book.keyThemes = enrichment.themes
                book.majorCharacters = enrichment.characters
                book.setting = enrichment.setting
                book.tone = enrichment.tone
                book.literaryStyle = enrichment.style
                book.seriesName = enrichment.seriesName
                book.seriesOrder = enrichment.seriesOrder
                book.totalBooksInSeries = enrichment.totalBooksInSeries
                book.enrichedAt = Date()

                #if DEBUG
                print("💾 [ENRICHMENT] Data saved to BookModel")
                #endif
                #if DEBUG
                print("   isEnriched now: \(book.isEnriched)")
                #endif
                #if DEBUG
                print("   smartSynopsis: \(book.smartSynopsis?.prefix(50) ?? "nil")")
                #endif
                if let series = enrichment.seriesName, let order = enrichment.seriesOrder {
                    #if DEBUG
                    print("   Series: \(series) #\(order)")
                    #endif
                }
            }

            #if DEBUG
            print("✅ [ENRICHMENT] Complete for '\(book.title)'")
            #endif
            #if DEBUG
            print("   Synopsis: \(enrichment.synopsis.prefix(100))...")
            #endif
            #if DEBUG
            print("   Themes: \(enrichment.themes.joined(separator: ", "))")
            #endif
            #if DEBUG
            print("   Characters: \(enrichment.characters.joined(separator: ", "))")
            #endif

        } catch {
            #if DEBUG
            print("❌ [ENRICHMENT] FAILED for '\(book.title)'")
            #endif
            #if DEBUG
            print("   Error: \(error)")
            #endif
            #if DEBUG
            print("   Error details: \(error.localizedDescription)")
            #endif
            if let urlError = error as? URLError {
                #if DEBUG
                print("   URL Error code: \(urlError.code.rawValue)")
                #endif
            }
        }
    }

    // MARK: - Perplexity Integration

    private func fetchEnrichment(for book: BookModel) async throws -> EnrichmentData {
        let prompt = buildSpoilerFreePrompt(title: book.title, author: book.author)

        // Use OptimizedPerplexityService for the actual API call
        let response = try await OptimizedPerplexityService.shared.chat(
            message: prompt,
            bookContext: nil as Book?
        )

        // Parse the response
        return try parseEnrichmentResponse(response)
    }

    // MARK: - Prompt Building

    private func buildSpoilerFreePrompt(title: String, author: String) -> String {
        """
        Analyze '\(title)' by \(author) and provide a sophisticated, literary overview.

        This works for BOTH fiction and non-fiction. Adapt your response accordingly:
        - Fiction: Focus on premise, themes, and atmosphere without spoilers
        - Non-fiction: Focus on central arguments, approach, and intellectual terrain

        Return ONLY a JSON object with these exact fields:
        {
          "synopsis": "A sophisticated 4-6 sentence summary that captures the essence, atmosphere, and intellectual/emotional stakes of the work WITHOUT revealing plot developments or conclusions",
          "themes": ["theme1", "theme2", "theme3", "theme4", "theme5"],
          "characters": ["Name1", "Name2", "Name3"],
          "setting": "Time period and world/location OR subject area in one sentence",
          "tone": ["adjective1", "adjective2", "adjective3", "adjective4"],
          "style": "Genre and writing style in one sentence",
          "seriesName": "Series name if part of a series, otherwise null",
          "seriesOrder": Book number in series (e.g., 1, 2, 3) or null if standalone,
          "totalBooksInSeries": Total number of books in the series or null if unknown/standalone
        }

        SYNOPSIS WRITING GUIDELINES:

        For FICTION:
        - Start with the central situation or dilemma that sets the story in motion
        - Evoke the atmosphere, tone, and emotional landscape
        - Hint at the stakes and conflicts without revealing resolutions
        - Mention the protagonist's situation/predicament
        - Use literary, evocative language
        - NO plot twists, endings, or major story developments
        - Focus on WHAT the book explores, not WHAT happens

        For NON-FICTION:
        - Begin with the central question or thesis
        - Describe the author's approach and methodology
        - Indicate the scope and ambition of the work
        - Suggest what makes this perspective unique or valuable
        - Use sophisticated, intellectual language
        - NO detailed conclusions or final arguments

        ADDITIONAL RULES:
        - Themes: Universal concepts (love, betrayal, power, identity, etc.)
        - Characters: First names only of 3-5 main characters (fiction) or key figures discussed (non-fiction)
        - Write the synopsis as if for a discerning reader who wants to understand the book's essence
        - Aim for 100-150 words for the synopsis

        Return ONLY the JSON object, no additional text.
        """
    }

    // MARK: - Response Parsing

    private func parseEnrichmentResponse(_ response: String) throws -> EnrichmentData {
        // Try to extract JSON from response
        let jsonString: String

        // Check if response contains JSON block
        if let jsonStart = response.range(of: "{"),
           let jsonEnd = response.range(of: "}", options: .backwards) {
            jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
        } else {
            jsonString = response
        }

        // Parse JSON
        guard let data = jsonString.data(using: .utf8) else {
            throw EnrichmentError.invalidResponse("Could not convert response to data")
        }

        do {
            let enrichment = try JSONDecoder().decode(EnrichmentData.self, from: data)
            return enrichment
        } catch {
            #if DEBUG
            print("❌ JSON parsing failed: \(error)")
            #endif
            #if DEBUG
            print("   Response: \(jsonString)")
            #endif

            // Fallback: try to extract fields manually
            return try parseManually(from: response)
        }
    }

    private func parseManually(from response: String) throws -> EnrichmentData {
        // Extract synopsis (look for "synopsis": "...")
        let synopsis = extractField(from: response, fieldName: "synopsis") ?? "No synopsis available."

        // Extract themes (look for array)
        let themes = extractArrayField(from: response, fieldName: "themes") ?? ["literary fiction"]

        // Extract characters
        let characters = extractArrayField(from: response, fieldName: "characters") ?? []

        // Extract setting
        let setting = extractField(from: response, fieldName: "setting") ?? "Contemporary setting"

        // Extract tone
        let tone = extractArrayField(from: response, fieldName: "tone") ?? ["thoughtful"]

        // Extract style
        let style = extractField(from: response, fieldName: "style") ?? "Literary fiction"

        // Extract series metadata
        let seriesName = extractField(from: response, fieldName: "seriesName")
        let seriesOrderString = extractField(from: response, fieldName: "seriesOrder")
        let seriesOrder = seriesOrderString.flatMap { Int($0) }
        let totalBooksString = extractField(from: response, fieldName: "totalBooksInSeries")
        let totalBooks = totalBooksString.flatMap { Int($0) }

        return EnrichmentData(
            synopsis: synopsis,
            themes: themes,
            characters: characters,
            setting: setting,
            tone: tone,
            style: style,
            seriesName: seriesName,
            seriesOrder: seriesOrder,
            totalBooksInSeries: totalBooks
        )
    }

    private func extractField(from text: String, fieldName: String) -> String? {
        // Look for "fieldName": "value"
        let pattern = "\"\(fieldName)\"\\s*:\\s*\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return nil
    }

    private func extractArrayField(from text: String, fieldName: String) -> [String]? {
        // Look for "fieldName": ["item1", "item2", ...]
        let pattern = "\"\(fieldName)\"\\s*:\\s*\\[([^\\]]+)\\]"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            let arrayContent = String(text[range])
            // Split by comma and clean quotes
            return arrayContent
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { $0.replacingOccurrences(of: "\"", with: "") }
                .filter { !$0.isEmpty }
        }
        return nil
    }

    enum EnrichmentError: Error {
        case invalidResponse(String)
    }
}
