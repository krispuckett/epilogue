import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "TemplateGenerator")

/// Generates spoiler-safe templates using on-device Apple Intelligence
@MainActor
class TemplateGenerator {
    private let intelligence: iOS26FoundationModels
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.intelligence = FoundationModelsManager.shared
        self.modelContext = modelContext
    }

    // MARK: - Template Generation

    func generateCharacterMap(
        for book: Book,
        enrichment: BookEnrichment,
        progress: ReadingProgress,
        mode: UpdateMode = .conservative
    ) async throws -> GeneratedTemplate {

        let filter = SpoilerSafeFilter(enrichment: enrichment, mode: mode)
        let boundary = filter.safeBoundary(for: progress)
        let safeCharacters = filter.getSafeCharacters(boundary: boundary)

        guard !safeCharacters.isEmpty else {
            throw TemplateError.noCharactersYet
        }

        logger.info("🎭 Generating character map for \(book.title) through chapter \(boundary)")

        // Get user highlights mentioning characters
        let highlights = getUserHighlightsAboutCharacters(for: book)

        let prompt = buildCharacterMapPrompt(
            book: book,
            characters: safeCharacters,
            highlights: highlights,
            boundary: boundary
        )

        let response = try await intelligence.generateText(prompt: prompt)
        let sections = try parseCharacterMapResponse(response, characters: safeCharacters)

        let template = GeneratedTemplate(
            bookID: book.id,
            type: .characters,
            revealedThrough: boundary,
            updateMode: mode,
            sections: sections,
            enrichmentBased: true
        )

        return template
    }

    func generateReadingGuide(
        for book: Book,
        enrichment: BookEnrichment,
        progress: ReadingProgress,
        mode: UpdateMode = .conservative
    ) async throws -> GeneratedTemplate {

        let filter = SpoilerSafeFilter(enrichment: enrichment, mode: mode)
        let boundary = filter.safeBoundary(for: progress)
        let safeChapters = filter.getSafeChapters(boundary: boundary)

        logger.info("📖 Generating reading guide for \(book.title) through chapter \(boundary)")

        let prompt = buildReadingGuidePrompt(
            book: book,
            structure: enrichment.structure,
            chapters: safeChapters,
            boundary: boundary
        )

        let response = try await intelligence.generateText(prompt: prompt)
        let sections = try parseReadingGuideResponse(response, boundary: boundary)

        let template = GeneratedTemplate(
            bookID: book.id,
            type: .guide,
            revealedThrough: boundary,
            updateMode: mode,
            sections: sections,
            enrichmentBased: true
        )

        return template
    }

    func generateThemeTracker(
        for book: Book,
        enrichment: BookEnrichment,
        progress: ReadingProgress,
        mode: UpdateMode = .conservative
    ) async throws -> GeneratedTemplate {

        let filter = SpoilerSafeFilter(enrichment: enrichment, mode: mode)
        let boundary = filter.safeBoundary(for: progress)
        let safeThemes = filter.getSafeThemes(boundary: boundary)

        guard !safeThemes.isEmpty else {
            throw TemplateError.noThemesYet
        }

        logger.info("💡 Generating theme tracker for \(book.title) through chapter \(boundary)")

        let highlights = getUserHighlightsByTheme(for: book, themes: safeThemes)

        let prompt = buildThemeTrackerPrompt(
            book: book,
            themes: safeThemes,
            highlights: highlights,
            boundary: boundary
        )

        let response = try await intelligence.generateText(prompt: prompt)
        let sections = try parseThemeTrackerResponse(response, themes: safeThemes)

        let template = GeneratedTemplate(
            bookID: book.id,
            type: .themes,
            revealedThrough: boundary,
            updateMode: mode,
            sections: sections,
            enrichmentBased: true
        )

        return template
    }

    // MARK: - Prompt Building

    private func buildCharacterMapPrompt(
        book: Book,
        characters: [Character],
        highlights: [String],
        boundary: Int
    ) -> String {
        let charactersText = characters.map { char in
            """
            - \(char.name) (Ch \(char.firstMention))
              Role: \(char.role)
              Significance: \(char.significance)
              Connections: \(char.connections.joined(separator: ", "))
            """
        }.joined(separator: "\n")

        let highlightsText = highlights.isEmpty
            ? "None yet"
            : highlights.joined(separator: "\n")

        return """
        Create a character map for "\(book.title)" through Chapter \(boundary).

        Characters introduced so far:
        \(charactersText)

        User's highlights about characters:
        \(highlightsText)

        Organize characters by importance. Prioritize characters the user highlighted.
        For each character provide:
        - Name and role
        - Brief description (2-3 sentences max)
        - Key relationships

        Keep descriptions concise and focused. No spoilers beyond Chapter \(boundary).

        Return structured JSON:
        {
            "characters": [
                {
                    "name": "string",
                    "description": "string",
                    "relationships": ["string"]
                }
            ]
        }
        """
    }

    private func buildReadingGuidePrompt(
        book: Book,
        structure: BookStructure?,
        chapters: [Chapter],
        boundary: Int
    ) -> String {
        let structureText = structure.map { struct in
            """
            Type: \(struct.type.rawValue)
            Total chapters: \(struct.totalChapters)
            Divisions: \(struct.divisions.map { $0.name }.joined(separator: ", "))
            """
        } ?? "Standard chapter structure"

        return """
        Create a reading guide for "\(book.title)" for a reader at Chapter \(boundary).

        Book structure:
        \(structureText)

        Provide:
        1. CONTEXT: Historical/cultural background (2-3 sentences)
        2. STRUCTURE: How the book is organized, where reader is now
        3. WHAT YOU'VE READ: Key points covered so far (3-4 bullets)
        4. WATCH FOR NEXT: What to pay attention to (no spoilers)
        5. REFLECTION: One thought-provoking question

        Keep concise. No spoilers beyond Chapter \(boundary).

        Return structured JSON:
        {
            "sections": [
                {
                    "title": "CONTEXT" | "STRUCTURE" | "WHAT YOU'VE READ" | "WATCH FOR NEXT" | "REFLECTION",
                    "content": "string"
                }
            ]
        }
        """
    }

    private func buildThemeTrackerPrompt(
        book: Book,
        themes: [Theme],
        highlights: [String: [String]],
        boundary: Int
    ) -> String {
        let themesText = themes.map { theme in
            let userHighlights = highlights[theme.name] ?? []
            let highlightsStr = userHighlights.isEmpty
                ? "No highlights yet"
                : userHighlights.joined(separator: "\n")

            return """
            - \(theme.name) (introduced Ch \(theme.firstIntroduced))
              Description: \(theme.description)
              Key chapters: \(theme.keyChapters.map(String.init).joined(separator: ", "))
              User highlights: \(highlightsStr)
            """
        }.joined(separator: "\n\n")

        return """
        Create a theme tracker for "\(book.title)" through Chapter \(boundary).

        Themes introduced so far:
        \(themesText)

        For each theme provide:
        - Introduction summary
        - Development so far (how it's evolved)
        - Connection to user's highlights (if any)

        Keep focused and concise. No spoilers beyond Chapter \(boundary).

        Return structured JSON:
        {
            "themes": [
                {
                    "name": "string",
                    "introduction": "string",
                    "development": "string"
                }
            ]
        }
        """
    }

    // MARK: - Response Parsing

    private func parseCharacterMapResponse(
        _ response: String,
        characters: [Character]
    ) throws -> [TemplateSection] {
        guard let jsonData = response.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(CharacterMapResponse.self, from: jsonData) else {
            throw TemplateError.invalidResponse
        }

        let items = parsed.characters.compactMap { char -> TemplateItem? in
            guard let original = characters.first(where: { $0.name == char.name }) else {
                return nil
            }

            let content = """
            \(char.name)
            \(char.description)

            Relationships:
            \(char.relationships.map { "• \($0)" }.joined(separator: "\n"))
            """

            return TemplateItem(
                content: content,
                revealedAt: original.firstMention
            )
        }

        return [TemplateSection(title: "Characters", items: items)]
    }

    private func parseReadingGuideResponse(
        _ response: String,
        boundary: Int
    ) throws -> [TemplateSection] {
        guard let jsonData = response.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ReadingGuideResponse.self, from: jsonData) else {
            throw TemplateError.invalidResponse
        }

        return parsed.sections.map { section in
            TemplateSection(
                title: section.title,
                items: [TemplateItem(content: section.content, revealedAt: 1)]
            )
        }
    }

    private func parseThemeTrackerResponse(
        _ response: String,
        themes: [Theme]
    ) throws -> [TemplateSection] {
        guard let jsonData = response.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ThemeTrackerResponse.self, from: jsonData) else {
            throw TemplateError.invalidResponse
        }

        return parsed.themes.map { themeData in
            guard let original = themes.first(where: { $0.name == themeData.name }) else {
                return TemplateSection(title: themeData.name, items: [])
            }

            let content = """
            Introduction (Ch \(original.firstIntroduced)):
            \(themeData.introduction)

            Development:
            \(themeData.development)
            """

            let item = TemplateItem(
                content: content,
                revealedAt: original.firstIntroduced
            )

            return TemplateSection(title: themeData.name, items: [item])
        }
    }

    // MARK: - User Content Integration

    private func getUserHighlightsAboutCharacters(for book: Book) -> [String] {
        // TODO: Fetch actual highlights from book
        // For now return empty
        return []
    }

    private func getUserHighlightsByTheme(
        for book: Book,
        themes: [Theme]
    ) -> [String: [String]] {
        // TODO: Fetch and categorize highlights by theme
        // For now return empty
        return [:]
    }
}

// MARK: - Response Types

private struct CharacterMapResponse: Decodable {
    let characters: [CharacterData]

    struct CharacterData: Decodable {
        let name: String
        let description: String
        let relationships: [String]
    }
}

private struct ReadingGuideResponse: Decodable {
    let sections: [SectionData]

    struct SectionData: Decodable {
        let title: String
        let content: String
    }
}

private struct ThemeTrackerResponse: Decodable {
    let themes: [ThemeData]

    struct ThemeData: Decodable {
        let name: String
        let introduction: String
        let development: String
    }
}

// MARK: - Errors

enum TemplateError: LocalizedError {
    case noEnrichment
    case noCharactersYet
    case noThemesYet
    case invalidResponse
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .noEnrichment:
            return "Book hasn't been enriched yet"
        case .noCharactersYet:
            return "No characters have been introduced yet"
        case .noThemesYet:
            return "No themes have been introduced yet"
        case .invalidResponse:
            return "Failed to parse AI response"
        case .generationFailed:
            return "Template generation failed"
        }
    }
}
