import Foundation
import OSLog
import Network

// Ultra-fast query router with intelligent model selection
@MainActor
class IntelligentQueryRouter {
    static let shared = IntelligentQueryRouter()
    private let logger = Logger(subsystem: "com.epilogue", category: "QueryRouter")
    private let networkMonitor = NWPathMonitor()
    private var isOnline = true

    /// Query types mapped to appropriate AI models
    enum QueryType: CustomStringConvertible {
        case companionGuidance  // Claude - literary analysis, reading help, thoughtful discussion
        case webSearch          // Sonar - facts, dates, current events, recommendations
        case quickLookup        // Foundation Models - simple character/plot questions (fast, free)
        case hybrid             // Claude + Sonar - complex queries needing both
        case offline            // Foundation only - no network

        var description: String {
            switch self {
            case .companionGuidance: return "companionGuidance"
            case .webSearch: return "webSearch"
            case .quickLookup: return "quickLookup"
            case .hybrid: return "hybrid"
            case .offline: return "offline"
            }
        }

        var targetModel: String {
            switch self {
            case .companionGuidance: return "Claude"
            case .webSearch: return "Sonar"
            case .quickLookup: return "Foundation"
            case .hybrid: return "Claude+Sonar"
            case .offline: return "Foundation"
            }
        }
    }

    // Legacy support
    enum LegacyQueryType: CustomStringConvertible {
        case bookContent
        case currentEvents
        case hybrid

        var description: String {
            switch self {
            case .bookContent: return "bookContent"
            case .currentEvents: return "currentEvents"
            case .hybrid: return "hybrid"
            }
        }
    }

    private init() {
        setupNetworkMonitoring()
    }

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }
    
    // MARK: - Intelligent Query Analysis

    /// Analyze query and route to appropriate model in <1ms
    func analyzeQuery(_ query: String, bookContext: Book?) -> QueryType {
        let startTime = CFAbsoluteTimeGetCurrent()
        let queryLower = query.lowercased()

        // Check offline status first
        if !isOnline {
            logger.info("Offline - routing to Foundation Models")
            return .offline
        }

        // CLAUDE: Thoughtful companion guidance, literary analysis
        let companionIndicators = [
            "how should i", "what does this mean", "symbolism",
            "i'm confused", "help me understand", "i don't get",
            "what do you think", "why is this important",
            "approach this", "prepare for", "intimidating",
            "feeling overwhelmed", "should i", "recommend",
            "what are the themes", "tell me about the author",
            "significance of", "interpretation", "analysis",
            "deeper meaning", "struggling with", "context for"
        ]

        for indicator in companionIndicators {
            if queryLower.contains(indicator) {
                let analysisTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                logger.info("Companion guidance query → Claude (\(String(format: "%.2f", analysisTime))ms)")
                return .companionGuidance
            }
        }

        // SONAR: Web search, current events, facts
        let webSearchIndicators = [
            "latest", "2024", "2025", "2026", "news", "current",
            "author interview", "movie adaptation", "reviews",
            "recently", "today", "this year", "update",
            "real world", "actually", "in reality",
            "other books by", "published", "awards",
            "similar books", "books like", "sequels"
        ]

        for indicator in webSearchIndicators {
            if queryLower.contains(indicator) {
                let analysisTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                logger.info("Web search query → Sonar (\(String(format: "%.2f", analysisTime))ms)")
                return .webSearch
            }
        }

        // FOUNDATION: Quick lookups - simple factual questions
        let quickLookupIndicators = [
            "who is", "what is", "where is", "when did",
            "what happens in chapter", "name of", "how many",
            "list the", "what's the plot", "quick summary"
        ]

        for indicator in quickLookupIndicators {
            if queryLower.contains(indicator) {
                let analysisTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                logger.info("Quick lookup → Foundation (\(String(format: "%.2f", analysisTime))ms)")
                return .quickLookup
            }
        }

        // HYBRID: Complex queries needing both understanding and facts
        if queryLower.contains("compare") || queryLower.contains("vs") ||
           queryLower.contains("difference between") || queryLower.contains("similar to") ||
           queryLower.contains("research") || queryLower.contains("comprehensive") {
            let analysisTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.info("Complex hybrid query → Claude+Sonar (\(String(format: "%.2f", analysisTime))ms)")
            return .hybrid
        }

        // DEFAULT: With book context in ambient mode, default to Claude for companionship
        // Without book context, default to quickLookup (Foundation) for speed
        let analysisTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        if bookContext != nil {
            logger.info("Default with book → Claude (\(String(format: "%.2f", analysisTime))ms)")
            return .companionGuidance
        } else {
            logger.info("Default no book → Foundation (\(String(format: "%.2f", analysisTime))ms)")
            return .quickLookup
        }
    }

    /// Legacy compatibility
    func analyzeQueryLegacy(_ query: String, bookContext: Book?) -> LegacyQueryType {
        let newType = analyzeQuery(query, bookContext: bookContext)
        switch newType {
        case .companionGuidance, .quickLookup, .offline:
            return .bookContent
        case .webSearch:
            return .currentEvents
        case .hybrid:
            return .hybrid
        }
    }
    
    // MARK: - Query Processing

    /// Process query with intelligent model routing
    func processQuery(_ query: String, bookContext: Book?, systemPrompt: String? = nil) async -> String {
        let queryType = analyzeQuery(query, bookContext: bookContext)
        let startTime = CFAbsoluteTimeGetCurrent()

        switch queryType {
        case .companionGuidance:
            // Claude for thoughtful, literary responses
            logger.info("Using Claude for companion guidance")
            return await processWithClaude(query, bookContext: bookContext, systemPrompt: systemPrompt)

        case .webSearch:
            // Sonar for web-based queries
            logger.info("Using Sonar for web search")
            return await processWithSonar(query, bookContext: bookContext)

        case .quickLookup:
            // Foundation Models for fast local queries
            logger.info("Using Foundation for quick lookup")
            return await processWithFoundation(query, bookContext: bookContext)

        case .hybrid:
            // Both Claude and Sonar in parallel
            logger.info("Using hybrid Claude+Sonar")
            return await processHybrid(query, bookContext: bookContext, systemPrompt: systemPrompt)

        case .offline:
            // Foundation only when offline
            logger.info("Offline mode - Foundation only")
            return await processWithFoundation(query, bookContext: bookContext)
        }
    }

    // MARK: - Model-Specific Processing

    private func processWithClaude(_ query: String, bookContext: Book?, systemPrompt: String?) async -> String {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Build rich system prompt with conversation memory if not provided
        let prompt = systemPrompt ?? buildEnrichedSystemPrompt(for: bookContext, query: query)

        do {
            // Use subscription-aware model selection (Opus for Plus, Sonnet for free)
            let response = try await ClaudeService.shared.subscriberChat(
                message: query,
                systemPrompt: prompt,
                maxTokens: 1024
            )

            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.info("Claude response in \(String(format: "%.1f", duration))ms")
            return response
        } catch {
            logger.error("Claude failed: \(error), falling back to Sonar")
            // Fallback chain: Claude → Sonar → Foundation
            let sonarResult = await processWithSonar(query, bookContext: bookContext)
            if sonarResult.isEmpty || sonarResult.contains("trouble connecting") {
                return await processWithFoundation(query, bookContext: bookContext)
            }
            return sonarResult
        }
    }

    private func processWithSonar(_ query: String, bookContext: Book?) async -> String {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let response = try await withTimeout(seconds: 15) {
                try await OptimizedPerplexityService.shared.chat(message: query, bookContext: bookContext)
            }

            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.info("Sonar response in \(String(format: "%.1f", duration))ms")
            return response
        } catch {
            logger.error("Sonar failed: \(error), falling back to Foundation")
            // Fallback chain: Sonar → Foundation (with disclaimer)
            let foundationResult = await processWithFoundation(query, bookContext: bookContext)
            if !foundationResult.isEmpty {
                return foundationResult + "\n\n(Note: This answer is based on local knowledge and may not include the latest information.)"
            }
            return "I'm having trouble connecting. Please check your internet and try again."
        }
    }

    private func processWithFoundation(_ query: String, bookContext: Book?) async -> String {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Set book context for SmartEpilogueAI
        if let book = bookContext {
            SmartEpilogueAI.shared.setActiveBook(book.toIntelligentBookModel())
        }

        let response = await SmartEpilogueAI.shared.smartQuery(query)

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("Foundation response in \(String(format: "%.1f", duration))ms")
        return response
    }

    private func processHybrid(_ query: String, bookContext: Book?, systemPrompt: String?) async -> String {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Execute Claude and Sonar in parallel
        async let claudeResult = processWithClaude(query, bookContext: bookContext, systemPrompt: systemPrompt)
        async let sonarResult = processWithSonar(query, bookContext: bookContext)

        let (claude, sonar) = await (claudeResult, sonarResult)

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("Hybrid response in \(String(format: "%.1f", duration))ms")

        // Synthesize responses - prefer Claude's analysis with Sonar's facts
        return synthesizeResponses(analysis: claude, facts: sonar, query: query)
    }

    // MARK: - Helpers

    /// Builds an enriched system prompt with conversation memory and context
    private func buildEnrichedSystemPrompt(for book: Book?, query: String) -> String {
        guard let book = book else {
            return """
            You are a thoughtful reading companion. Be warm, insightful, and conversational.
            Avoid being overly formal or academic. Speak like a knowledgeable friend who loves books.
            Keep responses focused and helpful. No emojis.
            """
        }

        // Get conversation memory context
        let contextManager = AmbientContextManager.shared
        let memoryContext = contextManager.buildEnhancedContext(for: query, book: book)

        // Get progress-aware spoiler guidance
        let progressPercent = Int(contextManager.readingProgress * 100)
        let spoilerGuidance = buildSpoilerGuidance(progress: contextManager.readingProgress)

        return """
        You are a thoughtful reading companion helping someone with "\(book.title)" by \(book.author).

        READER CONTEXT:
        \(memoryContext)

        SPOILER PROTECTION:
        Reader is at \(progressPercent)% progress.
        \(spoilerGuidance)

        YOUR ROLE:
        - Be warm and conversational, like a knowledgeable friend who has read this book
        - Provide literary insights without being academic or pompous
        - Reference previous topics naturally ("Earlier you asked about...")
        - Help them understand and appreciate the book deeply
        - If they seem confused, acknowledge that the confusion is normal and help

        STYLE:
        - Direct and clear, not flowery
        - Insightful but accessible
        - No emojis, no sycophantic phrases
        - Answer questions directly before elaborating
        - Adapt length to their preference (check context above)
        """
    }

    /// Builds spoiler guidance based on reading progress
    private func buildSpoilerGuidance(progress: Double) -> String {
        if progress < 0.1 {
            return """
            VERY EARLY in the book. Only discuss:
            - The basic premise and setup
            - Who the main characters are at the start
            - Historical/cultural context
            - Author background
            AVOID any plot development, twists, or character arcs.
            """
        } else if progress < 0.25 {
            return """
            EARLY in the book. Can discuss:
            - Setup and initial conflicts
            - Characters introduced so far
            - Early themes being established
            AVOID mid-book revelations, turning points, or later developments.
            """
        } else if progress < 0.5 {
            return """
            FIRST HALF of the book. Can discuss:
            - Plot developments up to the midpoint
            - Character relationships established
            - Themes that have been clearly introduced
            AVOID second-half revelations, climax, resolution, or ending.
            """
        } else if progress < 0.75 {
            return """
            PAST MIDPOINT. Can discuss:
            - Major developments through this point
            - Character growth and changes so far
            - Deepening themes
            AVOID the climax, resolution, and ending revelations.
            """
        } else if progress < 0.9 {
            return """
            NEARING THE END. Can discuss:
            - Almost all plot developments
            - Character arcs through this point
            - All themes explored so far
            AVOID the final resolution and ending surprises.
            """
        } else {
            return """
            FINISHING the book. Can discuss:
            - Nearly everything, but be careful about the very ending
            - Let them discover the final moments themselves
            - If they've finished, everything is fair game
            """
        }
    }

    private func buildCompanionSystemPrompt(for book: Book?) -> String {
        // Legacy support - redirect to enriched version
        return buildEnrichedSystemPrompt(for: book, query: "")
    }

    private func synthesizeResponses(analysis: String, facts: String, query: String) -> String {
        // If both are meaningful, combine them
        if !analysis.isEmpty && !facts.isEmpty &&
           !analysis.contains("trouble connecting") && !facts.contains("trouble connecting") {
            // Check for substantial overlap
            let analysisWords = Set(analysis.lowercased().split(separator: " "))
            let factsWords = Set(facts.lowercased().split(separator: " "))
            let overlap = analysisWords.intersection(factsWords).count

            // If minimal overlap, combine them
            if overlap < analysisWords.count / 3 {
                return """
                \(analysis)

                Additionally: \(facts)
                """
            } else {
                // High overlap - use the longer, more detailed response
                return analysis.count > facts.count ? analysis : facts
            }
        }

        // Return whichever is valid
        if !analysis.isEmpty && !analysis.contains("trouble connecting") {
            return analysis
        }
        return facts
    }

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CancellationError()
            }

            if let result = try await group.next() {
                group.cancelAll()
                return result
            }
            throw CancellationError()
        }
    }

    // MARK: - Legacy Support

    /// Legacy method for backward compatibility
    func processWithParallelism(_ query: String, bookContext: Book?) async -> String {
        return await processQuery(query, bookContext: bookContext)
    }
    
    // Quick check if a query needs web access
    func needsWebAccess(_ query: String) -> Bool {
        let queryType = analyzeQuery(query, bookContext: nil)
        return queryType == .webSearch || queryType == .hybrid
    }

    // Quick check if a query needs Claude
    func needsClaude(_ query: String, bookContext: Book?) -> Bool {
        let queryType = analyzeQuery(query, bookContext: bookContext)
        return queryType == .companionGuidance || queryType == .hybrid
    }

    // Preload for common questions
    func preloadCommonQuestions(for book: Book) async {
        let commonQuestions = [
            "What are the main themes?",
            "Who is the main character?",
            "What is the significance of the title?"
        ]

        // Preload local AI with book context
        SmartEpilogueAI.shared.setActiveBook(book.toIntelligentBookModel())

        for question in commonQuestions {
            _ = await SmartEpilogueAI.shared.smartQuery(question)
            logger.info("Preloaded: \(question)")
        }
    }
}

// Extension to convert Book to BookModel if needed
extension Book {
    func toIntelligentBookModel() -> BookModel {
        return BookModel(from: self)
    }
}