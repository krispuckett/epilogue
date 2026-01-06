import Foundation
import SwiftData
import Combine
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

private let logger = Logger(subsystem: "com.epilogue", category: "ThematicInsights")

// MARK: - Thematic Insight
/// A proactively generated insight about the user's reading patterns

struct ThematicInsight: Identifiable, Codable {
    let id: UUID
    let type: InsightType
    let title: String
    let body: String
    let relatedBooks: [String]
    let relatedThemes: [String]
    let evidence: [String]  // Quotes or notes supporting this insight
    let importance: Int  // 1-5
    let createdAt: Date
    let expiresAt: Date?  // Some insights are time-sensitive

    enum InsightType: String, Codable {
        case themePattern = "theme_pattern"
        case characterParallel = "character_parallel"
        case crossBookConnection = "cross_book"
        case readingMilestone = "milestone"
        case emergingInterest = "emerging"
        case favoriteAuthorPattern = "author_pattern"
        case quoteSynthesis = "quote_synthesis"
    }

    var iconName: String {
        switch type {
        case .themePattern: return "sparkle"
        case .characterParallel: return "person.2.fill"
        case .crossBookConnection: return "link"
        case .readingMilestone: return "star.fill"
        case .emergingInterest: return "arrow.up.right"
        case .favoriteAuthorPattern: return "pencil"
        case .quoteSynthesis: return "quote.bubble.fill"
        }
    }
}

// MARK: - Thematic Insight Generator
/// Analyzes the knowledge graph to generate proactive insights for the user.
///
/// Runs periodically in the background to discover:
/// - Theme patterns across books
/// - Character parallels (similar characters in different books)
/// - Cross-book connections
/// - Reading milestones
/// - Emerging interests

@MainActor
final class ThematicInsightGenerator: ObservableObject {
    // MARK: - Singleton

    static let shared = ThematicInsightGenerator()

    // MARK: - Published State

    @Published var latestInsights: [ThematicInsight] = []
    @Published var isGenerating = false
    @Published var lastGenerationDate: Date?

    // MARK: - Dependencies

    private let graphService = KnowledgeGraphService.shared

    #if canImport(FoundationModels)
    private let model = SystemLanguageModel.default
    private var session: LanguageModelSession?
    #endif

    // MARK: - Configuration

    private let maxInsights = 5
    private let generationCooldown: TimeInterval = 3600  // 1 hour between generations

    // MARK: - Cache

    private var insightCache: [ThematicInsight] = []
    private let insightCacheKey = "com.epilogue.thematicInsights"

    // MARK: - Initialization

    private init() {
        loadCachedInsights()
        #if canImport(FoundationModels)
        Task {
            await initializeSession()
        }
        #endif
    }

    #if canImport(FoundationModels)
    private func initializeSession() async {
        guard case .available = model.availability else { return }

        do {
            session = try await LanguageModelSession(
                instructions: """
                You are a literary insight generator. Your job is to discover meaningful patterns
                and connections in a reader's notes, quotes, and book choices.

                Generate insights that are:
                1. SPECIFIC - Reference actual books, quotes, or themes
                2. MEANINGFUL - Reveal something the reader might not have noticed
                3. ACTIONABLE - Suggest what to explore next
                4. PERSONAL - Connect to the reader's demonstrated interests

                Avoid generic observations. Every insight should feel like a discovery.
                """
            )
        } catch {
            logger.error("Failed to initialize insight session: \(error.localizedDescription)")
        }
    }
    #endif

    // MARK: - Generation

    /// Generate new insights based on current graph state
    func generateInsights() async throws {
        // Check cooldown
        if let lastGen = lastGenerationDate,
           Date().timeIntervalSince(lastGen) < generationCooldown {
            logger.info("⏳ Insight generation on cooldown")
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        var newInsights: [ThematicInsight] = []

        // 1. Theme pattern insights
        if let themeInsight = try await generateThemePatternInsight() {
            newInsights.append(themeInsight)
        }

        // 2. Cross-book connection insights
        if let connectionInsight = try await generateCrossBookInsight() {
            newInsights.append(connectionInsight)
        }

        // 3. Quote synthesis insights
        if let quoteInsight = try await generateQuoteSynthesisInsight() {
            newInsights.append(quoteInsight)
        }

        // 4. Character parallel insights
        if let characterInsight = try await generateCharacterParallelInsight() {
            newInsights.append(characterInsight)
        }

        // 5. Emerging interest insights
        if let emergingInsight = try await generateEmergingInterestInsight() {
            newInsights.append(emergingInsight)
        }

        // Update state
        latestInsights = Array(newInsights.prefix(maxInsights))
        lastGenerationDate = Date()

        // Cache insights
        cacheInsights(latestInsights)

        logger.info("✅ Generated \(newInsights.count) new insights")
    }

    // MARK: - Theme Pattern Insight

    private func generateThemePatternInsight() async throws -> ThematicInsight? {
        let topThemes = try graphService.getTopThemes(limit: 5)
        guard let primaryTheme = topThemes.first, primaryTheme.mentionCount >= 3 else {
            return nil
        }

        let bookTitles = primaryTheme.sourceBooks.map { $0.title }
        guard bookTitles.count >= 2 else { return nil }

        #if canImport(FoundationModels)
        guard let session = session else {
            return createFallbackThemeInsight(theme: primaryTheme, books: bookTitles)
        }

        let prompt = """
        Generate an insight about this reading pattern:

        Theme: \(primaryTheme.label)
        Appears in \(bookTitles.count) books: \(bookTitles.joined(separator: ", "))
        Mentioned \(primaryTheme.mentionCount) times in notes/quotes

        Write a 2-3 sentence insight that:
        1. Acknowledges the reader's interest in this theme
        2. Highlights an interesting connection between the books
        3. Suggests what this pattern might reveal about their reading journey
        """

        do {
            let response = try await session.respond(to: prompt)
            return ThematicInsight(
                id: UUID(),
                type: .themePattern,
                title: "A Thread Through Your Reading",
                body: response.content,
                relatedBooks: bookTitles,
                relatedThemes: [primaryTheme.label],
                evidence: [],
                importance: min(5, primaryTheme.mentionCount / 2 + 1),
                createdAt: Date(),
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())
            )
        } catch {
            return createFallbackThemeInsight(theme: primaryTheme, books: bookTitles)
        }
        #else
        return createFallbackThemeInsight(theme: primaryTheme, books: bookTitles)
        #endif
    }

    private func createFallbackThemeInsight(theme: KnowledgeNode, books: [String]) -> ThematicInsight {
        ThematicInsight(
            id: UUID(),
            type: .themePattern,
            title: "A Pattern in Your Reading",
            body: "You've explored '\(theme.label)' across \(books.count) different books. This theme seems to resonate with you—it appears \(theme.mentionCount) times in your notes and highlights.",
            relatedBooks: books,
            relatedThemes: [theme.label],
            evidence: [],
            importance: 3,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date())
        )
    }

    // MARK: - Cross-Book Connection Insight

    private func generateCrossBookInsight() async throws -> ThematicInsight? {
        // Find books that share themes
        let stats = try graphService.getStatistics()
        guard stats.nodesByType[.book] ?? 0 >= 2 else { return nil }

        let themes = try graphService.getTopThemes(limit: 10)
        let sharedTheme = themes.first { $0.sourceBooks.count >= 2 }

        guard let theme = sharedTheme else { return nil }

        let books = theme.sourceBooks.prefix(3)
        let bookTitles = books.map { $0.title }

        return ThematicInsight(
            id: UUID(),
            type: .crossBookConnection,
            title: "Books in Conversation",
            body: "'\(bookTitles[0])' and '\(bookTitles.count > 1 ? bookTitles[1] : "your other reads")' both explore \(theme.label). These books might be speaking to each other in your reading journey.",
            relatedBooks: Array(bookTitles),
            relatedThemes: [theme.label],
            evidence: [],
            importance: 4,
            createdAt: Date(),
            expiresAt: nil
        )
    }

    // MARK: - Quote Synthesis Insight

    private func generateQuoteSynthesisInsight() async throws -> ThematicInsight? {
        // Find quotes that share themes
        let themes = try graphService.getTopThemes(limit: 5)

        for theme in themes {
            let quotes = theme.sourceQuotes
            guard quotes.count >= 2 else { continue }

            let quoteTexts = quotes.compactMap { $0.text }.prefix(3)
            guard quoteTexts.count >= 2 else { continue }

            let bookTitles = Set(quotes.compactMap { $0.book?.title })

            #if canImport(FoundationModels)
            guard let session = session else { continue }

            let prompt = """
            These quotes from different books share a common theme (\(theme.label)):

            1. "\(quoteTexts[0].prefix(200))..."
            2. "\(quoteTexts.count > 1 ? String(quoteTexts[1].prefix(200)) : "")..."

            Write a 2-sentence insight that synthesizes what these quotes say together.
            Focus on what the combination reveals that neither quote says alone.
            """

            do {
                let response = try await session.respond(to: prompt)
                return ThematicInsight(
                    id: UUID(),
                    type: .quoteSynthesis,
                    title: "Voices in Harmony",
                    body: response.content,
                    relatedBooks: Array(bookTitles),
                    relatedThemes: [theme.label],
                    evidence: Array(quoteTexts.map { String($0) }),
                    importance: 4,
                    createdAt: Date(),
                    expiresAt: nil
                )
            } catch {
                continue
            }
            #endif
        }

        return nil
    }

    // MARK: - Character Parallel Insight

    private func generateCharacterParallelInsight() async throws -> ThematicInsight? {
        // Find characters that embody similar themes
        let characters = try graphService.findNodes(matching: "", type: .character, limit: 20)
        guard characters.count >= 2 else { return nil }

        for i in 0..<characters.count {
            for j in (i+1)..<characters.count {
                let char1 = characters[i]
                let char2 = characters[j]

                // Skip characters from the same book
                let books1 = Set(char1.sourceBooks.map { $0.id })
                let books2 = Set(char2.sourceBooks.map { $0.id })
                guard books1.isDisjoint(with: books2) else { continue }

                // Check if they share themes via edges
                let edges1 = try graphService.findEdges(for: char1, relationshipTypes: [.embodies])
                let edges2 = try graphService.findEdges(for: char2, relationshipTypes: [.embodies])

                let themes1 = Set(edges1.compactMap { $0.targetNode?.label })
                let themes2 = Set(edges2.compactMap { $0.targetNode?.label })

                let sharedThemes = themes1.intersection(themes2)
                guard !sharedThemes.isEmpty else { continue }

                let book1 = char1.sourceBooks.first?.title ?? "Unknown"
                let book2 = char2.sourceBooks.first?.title ?? "Unknown"

                return ThematicInsight(
                    id: UUID(),
                    type: .characterParallel,
                    title: "Echoes Across Stories",
                    body: "\(char1.label) from '\(book1)' and \(char2.label) from '\(book2)' both embody \(sharedThemes.first ?? "similar qualities"). You may be drawn to characters who explore this through different contexts.",
                    relatedBooks: [book1, book2],
                    relatedThemes: Array(sharedThemes),
                    evidence: [],
                    importance: 4,
                    createdAt: Date(),
                    expiresAt: nil
                )
            }
        }

        return nil
    }

    // MARK: - Emerging Interest Insight

    private func generateEmergingInterestInsight() async throws -> ThematicInsight? {
        // Find recently created nodes with high engagement
        let allNodes = try graphService.findNodes(matching: "", type: nil, limit: 50)

        // Filter to nodes created in the last 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentNodes = allNodes.filter { $0.createdAt > thirtyDaysAgo }

        // Sort by engagement
        let emerging = recentNodes
            .filter { $0.type == .theme || $0.type == .concept }
            .sorted { $0.engagementScore > $1.engagementScore }
            .first

        guard let node = emerging, node.mentionCount >= 2 else { return nil }

        let bookTitles = node.sourceBooks.map { $0.title }

        return ThematicInsight(
            id: UUID(),
            type: .emergingInterest,
            title: "A New Direction",
            body: "'\(node.label)' is emerging as a new area of interest. You've engaged with it \(node.mentionCount) times recently across \(bookTitles.count) book\(bookTitles.count == 1 ? "" : "s"). This might be worth exploring further.",
            relatedBooks: bookTitles,
            relatedThemes: [node.label],
            evidence: [],
            importance: 3,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    // MARK: - Specific Insights

    /// Generate an insight for a specific book
    func generateInsightForBook(_ book: BookModel) async throws -> ThematicInsight? {
        // Find themes in this book
        let bookId = book.id
        let allNodes = try graphService.findNodes(matching: "", type: .theme, limit: 50)
        let bookThemes = allNodes.filter { node in
            node.sourceBooks.contains { $0.id == bookId }
        }

        guard !bookThemes.isEmpty else { return nil }

        // Find other books sharing these themes
        var relatedBooks: Set<String> = []
        for theme in bookThemes {
            for relatedBook in theme.sourceBooks where relatedBook.id != bookId {
                relatedBooks.insert(relatedBook.title)
            }
        }

        guard !relatedBooks.isEmpty else { return nil }

        let themeNames = bookThemes.prefix(3).map { $0.label }

        return ThematicInsight(
            id: UUID(),
            type: .crossBookConnection,
            title: "Connected to Your Journey",
            body: "'\(book.title)' connects to your reading through themes of \(themeNames.joined(separator: ", ")). You've explored similar ideas in \(relatedBooks.prefix(2).joined(separator: " and ")).",
            relatedBooks: Array(relatedBooks.prefix(3)),
            relatedThemes: Array(themeNames),
            evidence: [],
            importance: 3,
            createdAt: Date(),
            expiresAt: nil
        )
    }

    // MARK: - Cache Management

    private func loadCachedInsights() {
        guard let data = UserDefaults.standard.data(forKey: insightCacheKey),
              let cached = try? JSONDecoder().decode([ThematicInsight].self, from: data) else {
            return
        }

        // Filter out expired insights
        let now = Date()
        insightCache = cached.filter { insight in
            guard let expires = insight.expiresAt else { return true }
            return expires > now
        }

        latestInsights = insightCache
    }

    private func cacheInsights(_ insights: [ThematicInsight]) {
        insightCache = insights
        if let data = try? JSONEncoder().encode(insights) {
            UserDefaults.standard.set(data, forKey: insightCacheKey)
        }
    }

    /// Clear all cached insights
    func clearCache() {
        insightCache = []
        latestInsights = []
        UserDefaults.standard.removeObject(forKey: insightCacheKey)
    }
}
