import Foundation
import SwiftData
import Combine
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

private let logger = Logger(subsystem: "com.epilogue", category: "EntityExtraction")

// MARK: - Extracted Entities Response
/// Structured output from Foundation Models entity extraction
@Generable
struct ExtractedEntities: Codable {
    let characters: [ExtractedCharacter]
    let themes: [ExtractedTheme]
    let concepts: [ExtractedConcept]
    let locations: [String]
    let insights: [ExtractedInsight]
}

@Generable
struct ExtractedCharacter: Codable {
    let name: String
    let role: String?  // protagonist, antagonist, supporting, mentioned
}

@Generable
struct ExtractedTheme: Codable {
    let theme: String
    let confidence: Double  // 0.0 - 1.0
}

@Generable
struct ExtractedConcept: Codable {
    let concept: String
    let category: String?  // philosophy, psychology, science, etc.
}

@Generable
struct ExtractedInsight: Codable {
    let insight: String
    let type: String  // observation, question, connection, realization
}

// MARK: - Extracted Thematic Connection Response
@Generable
struct ExtractedConnections: Codable {
    let connections: [ExtractedConnection]
}

@Generable
struct ExtractedConnection: Codable {
    let entity1: String
    let entity2: String
    let relationship: String
    let explanation: String
    let strength: Double  // 0.0 - 1.0
}

// MARK: - Entity Extraction Service
/// Uses Apple Foundation Models to extract entities from notes and quotes,
/// then populates the knowledge graph with nodes and edges.

@MainActor
final class EntityExtractionService {
    // MARK: - Singleton

    static let shared = EntityExtractionService()

    // MARK: - Dependencies

    #if canImport(FoundationModels)
    private let model = SystemLanguageModel.default
    private var session: LanguageModelSession?
    #endif

    private let graphService = KnowledgeGraphService.shared

    // MARK: - State

    @Published var isProcessing = false
    @Published var lastExtractionDate: Date?

    // MARK: - Initialization

    private init() {
        #if canImport(FoundationModels)
        Task {
            await initializeSession()
        }
        #endif
    }

    #if canImport(FoundationModels)
    private func initializeSession() async {
        guard case .available = model.availability else {
            logger.warning("⚠️ Foundation Models not available for entity extraction")
            return
        }

        do {
            session = try await LanguageModelSession(
                instructions: """
                You are an expert literary analyst. Your job is to extract meaningful entities
                from reading notes and quotes. Focus on:

                1. CHARACTERS: Names of people mentioned (real or fictional)
                2. THEMES: Abstract themes being explored (redemption, love, loss, etc.)
                3. CONCEPTS: Ideas, philosophies, or theories discussed
                4. LOCATIONS: Places mentioned (fictional or real)
                5. INSIGHTS: The user's own observations or realizations

                Be precise. Only extract entities that are clearly present.
                Assign confidence scores honestly - 0.5 for mentioned, 0.8+ for central focus.
                """
            )
            logger.info("✅ EntityExtractionService session initialized")
        } catch {
            logger.error("❌ Failed to initialize extraction session: \(error.localizedDescription)")
        }
    }
    #endif

    // MARK: - Note Extraction

    /// Extract entities from a note and populate the knowledge graph
    func extractAndIndex(
        note: CapturedNote,
        book: BookModel?
    ) async throws {
        isProcessing = true
        defer { isProcessing = false }

        #if canImport(FoundationModels)
        guard let session = session else {
            throw EntityExtractionError.sessionNotAvailable
        }

        let bookContext = book.map { "Book: \"\($0.title)\" by \($0.author)" } ?? "No book context"

        let prompt = """
        Extract entities from this reading note:

        \(bookContext)

        Note content:
        "\(note.content)"

        Extract all characters, themes, concepts, locations, and user insights present in this text.
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: ExtractedEntities.self
            )

            // Index extracted entities
            try await indexEntities(
                response.content,
                source: .note(note),
                book: book
            )

            lastExtractionDate = Date()
            logger.info("✅ Extracted and indexed entities from note")
        } catch {
            logger.error("❌ Entity extraction failed: \(error.localizedDescription)")
            throw error
        }
        #else
        throw EntityExtractionError.notSupported
        #endif
    }

    /// Extract entities from a quote and populate the knowledge graph
    func extractAndIndex(
        quote: CapturedQuote,
        book: BookModel?
    ) async throws {
        isProcessing = true
        defer { isProcessing = false }

        #if canImport(FoundationModels)
        guard let session = session else {
            throw EntityExtractionError.sessionNotAvailable
        }

        guard let quoteText = quote.text else {
            throw EntityExtractionError.emptyContent
        }

        let bookContext = book.map { "Book: \"\($0.title)\" by \($0.author)" } ?? "No book context"
        let authorContext = quote.author.map { "Quoted by: \($0)" } ?? ""
        let userNotes = quote.notes ?? ""

        let prompt = """
        Extract entities from this quote and the reader's notes about it:

        \(bookContext)
        \(authorContext)

        Quote:
        "\(quoteText)"

        Reader's notes about this quote:
        "\(userNotes)"

        Extract all characters, themes, concepts, locations, and user insights.
        Pay special attention to themes the quote explores.
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: ExtractedEntities.self
            )

            try await indexEntities(
                response.content,
                source: .quote(quote),
                book: book
            )

            lastExtractionDate = Date()
            logger.info("✅ Extracted and indexed entities from quote")
        } catch {
            logger.error("❌ Quote entity extraction failed: \(error.localizedDescription)")
            throw error
        }
        #else
        throw EntityExtractionError.notSupported
        #endif
    }

    // MARK: - Book Indexing

    /// Index a book's pre-extracted metadata into the knowledge graph
    func indexBook(_ book: BookModel) async throws {
        // Create book node
        let bookNode = try graphService.findOrCreateNode(
            label: book.title,
            type: .book,
            description: book.smartSynopsis,
            originBookId: book.id
        )

        // Link to author
        if !book.author.isEmpty {
            let authorNode = try graphService.findOrCreateNode(
                label: book.author,
                type: .author
            )
            _ = try graphService.createEdge(
                from: bookNode,
                to: authorNode,
                relationship: .writtenBy,
                weight: 1.0,
                confidence: 1.0
            )
        }

        // Index key themes
        if let themes = book.keyThemes {
            for theme in themes {
                let themeNode = try graphService.findOrCreateNode(
                    label: theme,
                    type: .theme,
                    originBookId: book.id
                )
                themeNode.sourceBooks.append(book)

                _ = try graphService.createEdge(
                    from: bookNode,
                    to: themeNode,
                    relationship: .explores,
                    weight: 0.8,
                    confidence: 0.9
                )
            }
        }

        // Index major characters
        if let characters = book.majorCharacters {
            for character in characters {
                let characterNode = try graphService.findOrCreateNode(
                    label: character,
                    type: .character,
                    originBookId: book.id
                )
                characterNode.sourceBooks.append(book)

                _ = try graphService.createEdge(
                    from: bookNode,
                    to: characterNode,
                    relationship: .mentions,
                    weight: 0.9,
                    confidence: 1.0
                )
            }
        }

        // Index setting as location
        if let setting = book.setting, !setting.isEmpty {
            let locationNode = try graphService.findOrCreateNode(
                label: setting,
                type: .location,
                originBookId: book.id
            )
            locationNode.sourceBooks.append(book)
        }

        logger.info("✅ Indexed book: \(book.title)")
    }

    // MARK: - Connection Discovery

    /// Analyze content for thematic connections between entities
    func discoverConnections(
        in content: String,
        existingEntities: [KnowledgeNode]
    ) async throws -> [ExtractedConnection] {
        #if canImport(FoundationModels)
        guard let session = session else {
            throw EntityExtractionError.sessionNotAvailable
        }

        let entityList = existingEntities.map { "\($0.type.displayName): \($0.label)" }.joined(separator: "\n")

        let prompt = """
        Analyze this content for thematic connections between these entities:

        Known entities:
        \(entityList)

        Content to analyze:
        "\(content)"

        Find meaningful connections between the entities. Look for:
        - Characters who embody certain themes
        - Themes that relate to each other
        - Concepts that parallel other concepts
        - Characters who resemble other characters

        Return only connections you're confident about (strength > 0.5).
        """

        let response = try await session.respond(
            to: prompt,
            generating: ExtractedConnections.self
        )

        return response.content.connections
        #else
        return []
        #endif
    }

    // MARK: - Batch Processing

    /// Process multiple notes/quotes in batch (for initial indexing)
    func batchIndex(
        notes: [CapturedNote],
        quotes: [CapturedQuote],
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        let total = notes.count + quotes.count
        var processed = 0

        // Index notes
        for note in notes {
            do {
                try await extractAndIndex(note: note, book: note.book)
            } catch {
                logger.warning("⚠️ Failed to index note: \(error.localizedDescription)")
            }
            processed += 1
            progressHandler?(Double(processed) / Double(total))

            // Small delay to avoid overwhelming the model
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1s
        }

        // Index quotes
        for quote in quotes {
            do {
                try await extractAndIndex(quote: quote, book: quote.book)
            } catch {
                logger.warning("⚠️ Failed to index quote: \(error.localizedDescription)")
            }
            processed += 1
            progressHandler?(Double(processed) / Double(total))

            try await Task.sleep(nanoseconds: 100_000_000)
        }

        logger.info("✅ Batch indexing complete: \(processed)/\(total) items")
    }

    // MARK: - Private Helpers

    private enum ContentSource {
        case note(CapturedNote)
        case quote(CapturedQuote)
    }

    private func indexEntities(
        _ entities: ExtractedEntities,
        source: ContentSource,
        book: BookModel?
    ) async throws {
        let bookId = book?.id

        // Index characters
        for character in entities.characters {
            let node = try graphService.findOrCreateNode(
                label: character.name,
                type: .character,
                description: character.role,
                originBookId: bookId
            )

            switch source {
            case .note(let note):
                if !node.sourceNotes.contains(where: { $0.id == note.id }) {
                    node.sourceNotes.append(note)
                }
            case .quote(let quote):
                if !node.sourceQuotes.contains(where: { $0.id == quote.id }) {
                    node.sourceQuotes.append(quote)
                }
            }

            if let book = book, !node.sourceBooks.contains(where: { $0.id == book.id }) {
                node.sourceBooks.append(book)
            }
        }

        // Index themes
        for theme in entities.themes {
            let node = try graphService.findOrCreateNode(
                label: theme.theme,
                type: .theme,
                originBookId: bookId
            )

            node.importance = max(node.importance, Int(theme.confidence * 5))

            switch source {
            case .note(let note):
                if !node.sourceNotes.contains(where: { $0.id == note.id }) {
                    node.sourceNotes.append(note)
                }
            case .quote(let quote):
                if !node.sourceQuotes.contains(where: { $0.id == quote.id }) {
                    node.sourceQuotes.append(quote)
                }
            }

            if let book = book, !node.sourceBooks.contains(where: { $0.id == book.id }) {
                node.sourceBooks.append(book)
            }
        }

        // Index concepts
        for concept in entities.concepts {
            let node = try graphService.findOrCreateNode(
                label: concept.concept,
                type: .concept,
                description: concept.category,
                originBookId: bookId
            )

            switch source {
            case .note(let note):
                if !node.sourceNotes.contains(where: { $0.id == note.id }) {
                    node.sourceNotes.append(note)
                }
            case .quote(let quote):
                if !node.sourceQuotes.contains(where: { $0.id == quote.id }) {
                    node.sourceQuotes.append(quote)
                }
            }

            if let book = book, !node.sourceBooks.contains(where: { $0.id == book.id }) {
                node.sourceBooks.append(book)
            }
        }

        // Index locations
        for location in entities.locations {
            let node = try graphService.findOrCreateNode(
                label: location,
                type: .location,
                originBookId: bookId
            )

            if let book = book, !node.sourceBooks.contains(where: { $0.id == book.id }) {
                node.sourceBooks.append(book)
            }
        }

        // Index user insights
        for insight in entities.insights {
            let node = try graphService.findOrCreateNode(
                label: insight.insight,
                type: .insight,
                description: insight.type,
                originBookId: bookId
            )

            switch source {
            case .note(let note):
                if !node.sourceNotes.contains(where: { $0.id == note.id }) {
                    node.sourceNotes.append(note)
                }
            case .quote(let quote):
                if !node.sourceQuotes.contains(where: { $0.id == quote.id }) {
                    node.sourceQuotes.append(quote)
                }
            }

            if let book = book, !node.sourceBooks.contains(where: { $0.id == book.id }) {
                node.sourceBooks.append(book)
            }
        }

        // Create edges between entities from the same content
        try await createIntraContentEdges(entities, book: book)
    }

    /// Create edges between entities that appear in the same content
    private func createIntraContentEdges(
        _ entities: ExtractedEntities,
        book: BookModel?
    ) async throws {
        // Characters embody themes
        for character in entities.characters {
            guard let characterNode = try? graphService.findNodes(
                matching: character.name,
                type: .character,
                limit: 1
            ).first else { continue }

            for theme in entities.themes where theme.confidence > 0.6 {
                guard let themeNode = try? graphService.findNodes(
                    matching: theme.theme,
                    type: .theme,
                    limit: 1
                ).first else { continue }

                _ = try graphService.createEdge(
                    from: characterNode,
                    to: themeNode,
                    relationship: .embodies,
                    weight: theme.confidence,
                    confidence: theme.confidence
                )
            }
        }

        // Connect related themes
        let themes = entities.themes.filter { $0.confidence > 0.5 }
        for i in 0..<themes.count {
            for j in (i+1)..<themes.count {
                guard let node1 = try? graphService.findNodes(
                    matching: themes[i].theme,
                    type: .theme,
                    limit: 1
                ).first,
                      let node2 = try? graphService.findNodes(
                    matching: themes[j].theme,
                    type: .theme,
                    limit: 1
                ).first else { continue }

                // Check if they share a book context
                let sharedBooks = Set(node1.sourceBooks.map { $0.id })
                    .intersection(Set(node2.sourceBooks.map { $0.id }))

                if !sharedBooks.isEmpty {
                    _ = try graphService.createEdge(
                        from: node1,
                        to: node2,
                        relationship: .connectedTheme,
                        weight: 0.5,
                        confidence: 0.7
                    )
                }
            }
        }
    }
}

// MARK: - Errors

enum EntityExtractionError: Error, LocalizedError {
    case sessionNotAvailable
    case emptyContent
    case extractionFailed(String)
    case notSupported

    var errorDescription: String? {
        switch self {
        case .sessionNotAvailable:
            return "Foundation Models session not available"
        case .emptyContent:
            return "Content is empty"
        case .extractionFailed(let reason):
            return "Entity extraction failed: \(reason)"
        case .notSupported:
            return "Entity extraction requires iOS 26+ with Foundation Models"
        }
    }
}
