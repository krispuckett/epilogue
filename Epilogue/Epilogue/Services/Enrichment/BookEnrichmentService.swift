import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "BookEnrichment")

/// Service for enriching books with comprehensive data using Sonar LLM
@MainActor
class BookEnrichmentService {
    static let shared = BookEnrichmentService()

    private let sonarAPI: SonarAPIClient
    private var enrichmentTasks: [UUID: Task<BookEnrichment, Error>] = [:]

    private init() {
        self.sonarAPI = SonarAPIClient()
    }

    // MARK: - Public API

    /// Enrich a book in the background
    func enrichBookInBackground(_ book: Book, context: ModelContext) {
        // Check if already enriching
        guard enrichmentTasks[book.id] == nil else {
            logger.info("📚 Already enriching \(book.title)")
            return
        }

        // Check if already enriched
        if let existing = book.getEnrichment(context: context) {
            logger.info("📚 \(book.title) already enriched on \(existing.enrichedDate)")
            return
        }

        logger.info("📚 Starting enrichment for \(book.title)")

        let task = Task.detached(priority: .utility) { [weak self] in
            guard let self = self else {
                throw EnrichmentError.serviceDeallocated
            }
            return try await self.performEnrichment(book)
        }

        enrichmentTasks[book.id] = task

        Task {
            do {
                let enrichment = try await task.value
                context.insert(enrichment)
                try? context.save()
                enrichmentTasks.removeValue(forKey: book.id)
                logger.info("✅ Enriched \(book.title) successfully")
            } catch {
                logger.error("❌ Enrichment failed for \(book.title): \(error.localizedDescription)")
                enrichmentTasks.removeValue(forKey: book.id)
            }
        }
    }

    /// Get enrichment status for a book
    func getEnrichmentStatus(_ bookID: UUID, context: ModelContext) -> EnrichmentStatus {
        // Check if actively enriching
        if let task = enrichmentTasks[bookID] {
            return task.isCancelled ? .failed : .inProgress
        }

        // Check if enrichment exists
        let descriptor = FetchDescriptor<BookEnrichment>(
            predicate: #Predicate { $0.bookID == bookID }
        )
        if let enrichment = try? context.fetch(descriptor).first {
            return enrichment.quality == EnrichmentQuality.unavailable.rawValue ? .failed : .completed
        }

        return .pending
    }

    // MARK: - Private Implementation

    private func performEnrichment(_ book: Book) async throws -> BookEnrichment {
        let prompt = buildEnrichmentPrompt(book)

        let response = try await sonarAPI.chat(
            messages: [.init(role: "user", content: prompt)],
            model: .sonarPro
        )

        let enrichment = try parseEnrichmentResponse(response, bookID: book.id)

        guard validate(enrichment) else {
            throw EnrichmentError.invalidData
        }

        return enrichment
    }

    private func buildEnrichmentPrompt(_ book: Book) -> String {
        """
        Analyze "\(book.title)" by \(book.author) and provide comprehensive enrichment data.

        Provide structured JSON data with:

        1. CHARACTERS:
           - All major and significant minor characters
           - First appearance by chapter number
           - Role and significance
           - Character connections/relationships

        2. CHAPTERS:
           - Chapter number and title (if applicable)
           - Brief summary (2-3 sentences)
           - Characters introduced in this chapter
           - Key plot points
           - Themes explored
           - Approximate page range

        3. THEMES:
           - Major themes
           - Chapter where first introduced
           - Description
           - Key chapters where theme is prominent

        4. STRUCTURE:
           - Book organization (chapters, parts, books, etc.)
           - Total chapter count
           - Major divisions

        CRITICAL REQUIREMENTS:
        - Chapter numbers must be precise
        - Keep summaries spoiler-minimal (focus on what happens, not outcomes)
        - Tag chapter numbers accurately for all data
        - Approximate page ranges should account for typical editions

        Return ONLY valid JSON matching this schema:
        {
            "characters": [
                {
                    "name": "string",
                    "firstMention": number,
                    "role": "string",
                    "significance": "string",
                    "connections": ["string"]
                }
            ],
            "chapters": [
                {
                    "number": number,
                    "title": "string or null",
                    "summary": "string",
                    "charactersIntroduced": ["string"],
                    "plotPoints": ["string"],
                    "themes": ["string"],
                    "approximatePages": {"start": number, "end": number}
                }
            ],
            "themes": [
                {
                    "name": "string",
                    "firstIntroduced": number,
                    "description": "string",
                    "keyChapters": [number]
                }
            ],
            "structure": {
                "type": "chapters|parts|books|mixed",
                "totalChapters": number,
                "divisions": [
                    {
                        "name": "string",
                        "chapterRange": {"start": number, "end": number}
                    }
                ]
            }
        }
        """
    }

    private func parseEnrichmentResponse(_ response: String, bookID: UUID) throws -> BookEnrichment {
        guard let jsonData = response.data(using: .utf8) else {
            throw EnrichmentError.invalidResponse
        }

        let decoder = JSONDecoder()
        let enrichmentData = try decoder.decode(EnrichmentResponseData.self, from: jsonData)

        let characters = enrichmentData.characters.map { char in
            Character(
                name: char.name,
                firstMention: char.firstMention,
                role: char.role,
                significance: char.significance,
                connections: char.connections
            )
        }

        let chapters = enrichmentData.chapters.map { chap in
            Chapter(
                number: chap.number,
                title: chap.title,
                summary: chap.summary,
                charactersIntroduced: chap.charactersIntroduced,
                plotPoints: chap.plotPoints,
                themes: chap.themes,
                approximatePages: chap.approximatePages.map { PageRange(start: $0.start, end: $0.end) }
            )
        }

        let themes = enrichmentData.themes.map { theme in
            Theme(
                name: theme.name,
                firstIntroduced: theme.firstIntroduced,
                description: theme.description,
                keyChapters: theme.keyChapters
            )
        }

        let structure = BookStructure(
            type: StructureType(rawValue: enrichmentData.structure.type) ?? .chapters,
            totalChapters: enrichmentData.structure.totalChapters,
            divisions: enrichmentData.structure.divisions.map { div in
                Division(
                    name: div.name,
                    chapterRange: PageRange(start: div.chapterRange.start, end: div.chapterRange.end)
                )
            }
        )

        return BookEnrichment(
            bookID: bookID,
            characters: characters,
            chapters: chapters,
            themes: themes,
            structure: structure,
            totalChapters: enrichmentData.structure.totalChapters
        )
    }

    private func validate(_ enrichment: BookEnrichment) -> Bool {
        // Basic validation
        guard enrichment.totalChapters > 0 else { return false }
        guard !enrichment.characters.isEmpty else { return false }
        guard !enrichment.chapters.isEmpty else { return false }

        // Validate chapter numbers are sequential
        let chapterNumbers = enrichment.chapters.map { $0.number }.sorted()
        guard chapterNumbers.first == 1 else { return false }

        return true
    }
}

// MARK: - Supporting Types

enum EnrichmentStatus {
    case pending
    case inProgress
    case completed
    case failed
}

enum EnrichmentError: LocalizedError {
    case serviceDeallocated
    case invalidResponse
    case invalidData
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .serviceDeallocated:
            return "Service was deallocated"
        case .invalidResponse:
            return "Invalid response from API"
        case .invalidData:
            return "Enrichment data failed validation"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

// MARK: - Response Decoding

private struct EnrichmentResponseData: Decodable {
    let characters: [CharacterData]
    let chapters: [ChapterData]
    let themes: [ThemeData]
    let structure: StructureData

    struct CharacterData: Decodable {
        let name: String
        let firstMention: Int
        let role: String
        let significance: String
        let connections: [String]
    }

    struct ChapterData: Decodable {
        let number: Int
        let title: String?
        let summary: String
        let charactersIntroduced: [String]
        let plotPoints: [String]
        let themes: [String]
        let approximatePages: PageRangeData?
    }

    struct ThemeData: Decodable {
        let name: String
        let firstIntroduced: Int
        let description: String
        let keyChapters: [Int]
    }

    struct StructureData: Decodable {
        let type: String
        let totalChapters: Int
        let divisions: [DivisionData]
    }

    struct PageRangeData: Decodable {
        let start: Int
        let end: Int
    }

    struct DivisionData: Decodable {
        let name: String
        let chapterRange: PageRangeData
    }
}

// MARK: - Sonar API Client (Placeholder)

private class SonarAPIClient {
    struct Message {
        let role: String
        let content: String
    }

    enum Model {
        case sonarPro
    }

    func chat(messages: [Message], model: Model) async throws -> String {
        // TODO: Implement actual Sonar API integration
        // For now, return mock response for testing
        throw EnrichmentError.apiError("Sonar API not yet implemented")
    }
}
