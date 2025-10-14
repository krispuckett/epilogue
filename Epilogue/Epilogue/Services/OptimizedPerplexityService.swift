import Foundation
import Combine
import OSLog
import SQLite3

// MARK: - Citation Model
struct Citation: Codable, Identifiable {
    let id = UUID()
    let text: String
    let source: String
    let url: String?
    let credibilityScore: Double
    let position: Int  // Position in response text
}

// MARK: - Response with Citations
struct PerplexityResponse {
    let text: String
    let citations: [Citation]
    let model: String
    let confidence: Double
    let cached: Bool
}

// MARK: - Perplexity Error
enum PerplexityError: LocalizedError {
    case rateLimitExceeded(remaining: Int, resetTime: Date)
    case invalidRequest
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case unauthorized
    case authenticationFailed
    case serverError(String)
    case timeout
    case noBookContext
    case tokenLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Taking too long. Try a simpler question."
        case .noBookContext:
            return "Please select a book first."
        case .tokenLimitExceeded:
            return "Question too long. Please shorten."
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment."
        case .invalidRequest:
            return "Invalid request format"
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Connection issue. Please check your internet."
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized, .authenticationFailed:
            return "Authentication failed - check API key configuration"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// MARK: - Optimized Perplexity Service
@MainActor
class OptimizedPerplexityService: ObservableObject {
    static let shared = OptimizedPerplexityService()
    
    private let logger = Logger(subsystem: "com.epilogue", category: "PerplexitySonar")
    private let primaryProxy = "https://epilogue-proxy.kris-puckett.workers.dev"
    private let backupProxy = "https://epilogue-backup.workers.dev"  // Add a backup proxy
    private let perplexityDirectEndpoint = "https://api.perplexity.ai/chat/completions"
    private var currentEndpoint: String = ""
    private var apiKey: String = ""
    
    // Streaming support
    private var eventSource: URLSessionDataTask?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
    
    // Caching
    private var responseCache: PerplexityResponseCache
    private let cacheExpiration: TimeInterval = 3600 // 1 hour
    
    // Rate limiting
    private let rateLimiter = RateLimiter()
    private var requestQueue: [QueuedRequest] = []
    
    // Model selection
    private let complexityAnalyzer = QueryComplexityAnalyzer()
    
    // Token batching for UI
    private let tokenBatcher = TokenBatcher(batchInterval: 0.05) // 50ms batches
    
    private init() {
        self.responseCache = PerplexityResponseCache()
        setupAPIKey()
        Task {
            await responseCache.initialize()
        }
    }
    
    private func setupAPIKey() {
        // First check if user has provided their own API key via Keychain
        if let userKey = KeychainManager.shared.getPerplexityAPIKey(),
           !userKey.isEmpty {
            self.apiKey = userKey
            self.currentEndpoint = perplexityDirectEndpoint
            logger.info("🔑 AI Service configured: using user's Perplexity API key")
        } else {
            // Use proxy authentication
            self.apiKey = "proxy_authenticated"
            self.currentEndpoint = primaryProxy
            logger.info("🔑 AI Service configured: using CloudFlare proxy authentication")
        }
    }
    
    // MARK: - Cerebras-Powered Streaming with SSE
    
    func streamSonarResponse(
        _ query: String,
        bookContext: Book?,
        enrichment: (synopsis: String, characters: [String], themes: [String], setting: String)? = nil,
        sessionHistory: [String]? = nil,
        userNotes: [(content: String, page: Int?)]? = nil,
        userQuotes: [(text: String, page: Int?, notes: String?)]? = nil,
        userQuestions: [(question: String, page: Int?, answer: String?)]? = nil,
        currentPage: Int? = nil
    ) -> AsyncThrowingStream<PerplexityResponse, Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }

                do {
                    // Check cache first
                    let cacheKey = generateCacheKey(query: query, bookContext: bookContext)
                    if let cached = await responseCache.get(key: cacheKey) {
                        logger.info("💨 Cache hit for query")
                        continuation.yield(PerplexityResponse(
                            text: cached.text,
                            citations: cached.citations,
                            model: cached.model,
                            confidence: 1.0,
                            cached: true
                        ))
                        continuation.finish()
                        return
                    }

                    // Check daily quota for TestFlight
                    if !PerplexityQuotaManager.shared.canAskQuestion {
                        logger.warning("⚠️ Daily quota exceeded")
                        await MainActor.run {
                            PerplexityQuotaManager.shared.showQuotaExceededSheet = true
                        }
                        throw PerplexityError.rateLimitExceeded(
                            remaining: 0,
                            resetTime: PerplexityQuotaManager.shared.nextResetTime
                        )
                    }

                    // Track question usage
                    let quotaAllowed = PerplexityQuotaManager.shared.trackQuestionUsage()
                    if !quotaAllowed {
                        throw PerplexityError.rateLimitExceeded(
                            remaining: 0,
                            resetTime: PerplexityQuotaManager.shared.nextResetTime
                        )
                    }

                    // Check rate limits
                    if await rateLimiter.shouldQueue() {
                        logger.info("⏳ Queueing request due to rate limits")
                        await queueRequest(query: query, bookContext: bookContext, continuation: continuation)
                        return
                    }
                    
                    // Use fast model for immediate responses
                    let model = "sonar"  // Always use fast model for real-time responses
                    logger.info("🚀 Using fast sonar model for speed")
                    
                    // Create SSE request
                    let request = try createSonarRequest(
                        query: query,
                        bookContext: bookContext,
                        model: model,
                        stream: true,
                        enrichment: enrichment,
                        sessionHistory: sessionHistory,
                        userNotes: userNotes,
                        userQuotes: userQuotes,
                        userQuestions: userQuestions,
                        currentPage: currentPage
                    )
                    
                    // Start streaming with automatic reconnection
                    try await streamWithReconnection(
                        request: request,
                        query: query,
                        bookContext: bookContext,
                        model: model,
                        continuation: continuation
                    )
                    
                } catch {
                    logger.error("❌ Streaming error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func streamWithReconnection(
        request: URLRequest,
        query: String,
        bookContext: Book?,
        model: String,
        continuation: AsyncThrowingStream<PerplexityResponse, Error>.Continuation
    ) async throws {
        var accumulatedText = ""
        var citations: [Citation] = []
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("❌ Invalid response type")
                throw PerplexityError.invalidResponse
            }
            
            // Handle various HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                // Success - continue processing
                break
            case 401:
                logger.error("❌ Authentication failed - check API key")
                throw PerplexityError.authenticationFailed
            case 429:
                logger.error("⚠️ Rate limit exceeded")
                // Use default values for rate limit since we don't have the headers here
                throw PerplexityError.rateLimitExceeded(remaining: 0, resetTime: Date().addingTimeInterval(60))
            case 500...599:
                logger.error("❌ Server error: \(httpResponse.statusCode)")
                throw PerplexityError.serverError("Server error: \(httpResponse.statusCode)")
            default:
                logger.error("❌ Unexpected status code: \(httpResponse.statusCode)")
                throw PerplexityError.invalidResponse
            }
            
            // Process SSE stream with token batching
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let data = String(line.dropFirst(6))
                    
                    if data == "[DONE]" {
                        // Stream complete
                        let finalResponse = PerplexityResponse(
                            text: accumulatedText,
                            citations: citations,
                            model: model,
                            confidence: calculateConfidence(text: accumulatedText, citations: citations),
                            cached: false
                        )
                        
                        // Cache the response
                        await cacheResponse(
                            query: query,
                            bookContext: bookContext,
                            response: finalResponse
                        )
                        
                        continuation.yield(finalResponse)
                        continuation.finish()
                        
                        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                        logger.info("✅ Stream complete in \(String(format: "%.1f", duration))ms")
                        break
                    }
                    
                    // Parse SSE token
                    if let tokenData = parseSSEData(data) {
                        // Extract text token
                        if let token = tokenData["content"] as? String {
                            accumulatedText += token
                            
                            // Batch tokens for UI (50ms intervals)
                            await tokenBatcher.addToken(token) { batchedTokens in
                                let partialResponse = PerplexityResponse(
                                    text: accumulatedText,
                                    citations: citations,
                                    model: model,
                                    confidence: 0.0,  // Not calculated yet
                                    cached: false
                                )
                                continuation.yield(partialResponse)
                            }
                        }
                        
                        // Extract citations if present
                        if let citationData = tokenData["citations"] as? [[String: Any]] {
                            citations = parseCitations(citationData, in: accumulatedText)
                        }
                    }
                }
            }
            
        } catch {
            // Determine if error is retryable
            let isRetryable: Bool
            let baseDelay: TimeInterval
            
            switch error {
            case let perplexityError as PerplexityError:
                switch perplexityError {
                case .serverError:
                    isRetryable = true
                    baseDelay = 2.0  // Start with 2 seconds for server errors
                case .rateLimitExceeded:
                    isRetryable = true
                    baseDelay = 5.0  // Longer delay for rate limits
                case .networkError:
                    isRetryable = true
                    baseDelay = 1.0  // Quick retry for network issues
                default:
                    isRetryable = false
                    baseDelay = 0
                }
            default:
                // For unknown errors, attempt retry with standard delay
                isRetryable = true
                baseDelay = 1.0
                
                // If proxy is failing, try backup proxy or suggest user add their own key
                if currentEndpoint == primaryProxy && self.reconnectAttempts >= 2 {
                    logger.warning("⚠️ Primary proxy appears down. User can add their own API key in Settings > AI & Intelligence")
                    // Could switch to backup proxy here if available
                    // self.currentEndpoint = backupProxy
                }
            }
            
            // Handle reconnection with exponential backoff
            if isRetryable && self.reconnectAttempts < self.maxReconnectAttempts {
                self.reconnectAttempts += 1
                
                // Calculate exponential backoff with jitter
                let delay = baseDelay * pow(2.0, Double(self.reconnectAttempts - 1))
                let jitter = Double.random(in: 0...0.3) * delay  // Add up to 30% jitter
                let finalDelay = min(delay + jitter, 30.0)  // Cap at 30 seconds
                
                logger.warning("🔄 Reconnecting... (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts)) after \(String(format: "%.1f", finalDelay))s")
                
                try await Task.sleep(nanoseconds: UInt64(finalDelay * 1_000_000_000))
                
                // Reset attempts on successful reconnection
                self.reconnectAttempts = 0
                
                try await streamWithReconnection(
                    request: request,
                    query: query,
                    bookContext: bookContext,
                    model: model,
                    continuation: continuation
                )
            } else {
                logger.error("❌ Max retry attempts reached or non-retryable error: \(error)")
                throw error
            }
        }
    }
    
    // MARK: - Citation Extraction
    
    private func parseCitations(_ citationData: [[String: Any]], in text: String) -> [Citation] {
        var citations: [Citation] = []
        
        for (index, data) in citationData.enumerated() {
            guard let source = data["source"] as? String,
                  let citationText = data["text"] as? String else {
                continue
            }
            
            // Calculate credibility score based on source
            let credibilityScore = calculateCredibilityScore(source: source)
            
            // Find position in text
            let position = findCitationPosition(citationText, in: text)
            
            citations.append(Citation(
                text: citationText,
                source: source,
                url: data["url"] as? String,
                credibilityScore: credibilityScore,
                position: position ?? index * 100
            ))
        }
        
        // Sort by position in text
        return citations.sorted { $0.position < $1.position }
    }
    
    private func calculateCredibilityScore(source: String) -> Double {
        let sourceLower = source.lowercased()
        
        // Academic sources
        if sourceLower.contains(".edu") || sourceLower.contains("scholar") ||
           sourceLower.contains("jstor") || sourceLower.contains("pubmed") {
            return 0.95
        }
        
        // Reputable news sources
        if sourceLower.contains("nytimes") || sourceLower.contains("wsj") ||
           sourceLower.contains("bbc") || sourceLower.contains("reuters") {
            return 0.85
        }
        
        // Wikipedia and encyclopedias
        if sourceLower.contains("wikipedia") || sourceLower.contains("britannica") {
            return 0.75
        }
        
        // Forums and social media
        if sourceLower.contains("reddit") || sourceLower.contains("twitter") ||
           sourceLower.contains("facebook") {
            return 0.4
        }
        
        // Default credibility
        return 0.6
    }
    
    private func findCitationPosition(_ citation: String, in text: String) -> Int? {
        if let range = text.range(of: citation) {
            return text.distance(from: text.startIndex, to: range.lowerBound)
        }
        return nil
    }
    
    // MARK: - Smart Model Selection
    
    private func selectModel(for query: String) -> String {
        let complexity = complexityAnalyzer.analyze(query)
        
        switch complexity {
        case .simple:
            return "sonar"  // Fast, efficient for simple lookups
        case .moderate:
            return query.count > 100 ? "sonar-pro" : "sonar"
        case .complex:
            return "sonar-pro"  // Advanced reasoning capabilities
        }
    }
    
    // MARK: - Response Caching
    
    private func cacheResponse(query: String, bookContext: Book?, response: PerplexityResponse) async {
        let key = generateCacheKey(query: query, bookContext: bookContext)
        await responseCache.set(key: key, response: response, expiration: Date().addingTimeInterval(cacheExpiration))
    }
    
    private func generateCacheKey(query: String, bookContext: Book?) -> String {
        let bookPart = bookContext?.title ?? "general"
        let queryHash = query.hashValue
        return "\(bookPart)_\(queryHash)"
    }
    
    // MARK: - Rate Limiting
    
    private func queueRequest(query: String, bookContext: Book?, continuation: AsyncThrowingStream<PerplexityResponse, Error>.Continuation) async {
        let request = QueuedRequest(
            query: query,
            bookContext: bookContext,
            priority: .userInitiated,
            continuation: continuation
        )
        
        requestQueue.append(request)
        requestQueue.sort { $0.priority.rawValue > $1.priority.rawValue }
        
        // Process queue when rate limit resets
        Task {
            await processQueue()
        }
    }
    
    private func processQueue() async {
        while !requestQueue.isEmpty {
            let shouldQueue = await rateLimiter.shouldQueue()
            if shouldQueue { break }
            guard let request = requestQueue.first else { break }
            requestQueue.removeFirst()
            
            // Process the queued request
            Task {
                do {
                    let model = selectModel(for: request.query)
                    let apiRequest = try createSonarRequest(
                        query: request.query,
                        bookContext: request.bookContext,
                        model: model,
                        stream: true
                    )
                    
                    try await streamWithReconnection(
                        request: apiRequest,
                        query: request.query,
                        bookContext: request.bookContext,
                        model: model,
                        continuation: request.continuation
                    )
                } catch {
                    request.continuation.finish(throwing: error)
                }
            }
            
            // Small delay between requests
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
    
    // MARK: - Request Creation
    
    private func createSonarRequest(
        query: String,
        bookContext: Book?,
        model: String,
        stream: Bool,
        enrichment: (synopsis: String, characters: [String], themes: [String], setting: String)? = nil,
        sessionHistory: [String]? = nil,
        userNotes: [(content: String, page: Int?)]? = nil,
        userQuotes: [(text: String, page: Int?, notes: String?)]? = nil,
        userQuestions: [(question: String, page: Int?, answer: String?)]? = nil,
        currentPage: Int? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: currentEndpoint) else {
            throw PerplexityError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if currentEndpoint == perplexityDirectEndpoint {
            // Direct API authentication with user's key
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else {
            // Proxy authentication
            request.setValue("epilogue_testflight_2025_secret", forHTTPHeaderField: "X-Epilogue-Auth")
        }
        
        // Get or create userId
        let userId: String
        if let existingId = UserDefaults.standard.string(forKey: "userId") {
            userId = existingId
        } else {
            userId = UUID().uuidString
            UserDefaults.standard.set(userId, forKey: "userId")
        }
        request.setValue(userId, forHTTPHeaderField: "X-User-ID")
        
        if stream {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        } else {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = bookContext.map { book in
            buildEnrichedBookContext(
                for: book,
                enrichment: enrichment,
                sessionHistory: sessionHistory,
                userNotes: userNotes,
                userQuotes: userQuotes,
                userQuestions: userQuestions,
                currentPage: currentPage
            )
        } ?? "Be concise and helpful."
        
        // Back to sonar - it was working fine before
        let body: [String: Any] = [
            "model": "sonar",  // Always use sonar for proxy
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": query]
            ],
            "stream": stream,
            "search_recency": "month",
            "return_citations": true,
            "return_images": false,
            "search_domain_filter": [],  // No domain restrictions
            "temperature": 0.7,
            "max_tokens": 500  // Reduced for faster responses
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    // MARK: - Helper Methods
    
    private func parseSSEData(_ data: String) -> [String: Any]? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any] else {
            return nil
        }
        return delta
    }
    
    private func calculateConfidence(text: String, citations: [Citation]) -> Double {
        // Base confidence from response length
        let lengthScore = min(Double(text.count) / 500.0, 1.0)
        
        // Citation quality score
        let citationScore = citations.isEmpty ? 0.0 :
            citations.map { $0.credibilityScore }.reduce(0, +) / Double(citations.count)
        
        // Combined confidence (weighted)
        return lengthScore * 0.3 + citationScore * 0.7
    }
    
    // MARK: - Public Methods
    
    func chat(message: String, bookContext: Book?) async throws -> String {
        // Detect if this is a JSON request (enrichment) - needs full response
        let needsFullResponse = message.contains("JSON") || message.contains("json")

        logger.info("🚀 Starting chat request: \(message.prefix(100))...")
        if needsFullResponse {
            logger.info("📊 JSON response required - waiting for complete response")
        }
        if let book = bookContext {
            logger.info("📚 Book context: \(book.title) by \(book.author)")
        }
        var fullResponse = ""
        var responseCount = 0
        let startTime = Date()

        do {
            for try await response in streamSonarResponse(message, bookContext: bookContext) {
                responseCount += 1
                fullResponse = response.text

                // Log progress every 10 responses
                if responseCount % 10 == 0 {
                    logger.info("📝 Received \(responseCount) streaming chunks, current length: \(fullResponse.count)")
                }

                let elapsed = Date().timeIntervalSince(startTime)

                // For JSON responses (enrichment), wait for complete response
                if needsFullResponse {
                    // Only timeout after 10 seconds for JSON
                    if elapsed > 10.0 {
                        logger.info("⏱️ Timeout at 10s for JSON response, length: \(fullResponse.count)")
                        break
                    }
                    // Continue collecting until stream ends naturally
                    continue
                }

                // For chat responses, use progressive loading thresholds:
                // 1. Return at 200 chars after 1.5 seconds (quick preview)
                // 2. Return at 400 chars after 3 seconds (good response)
                // 3. Return at 600 chars after 4 seconds (comprehensive)
                // 4. Hard stop at 5 seconds regardless

                if (fullResponse.count >= 200 && elapsed > 1.5) ||
                   (fullResponse.count >= 400 && elapsed > 3.0) ||
                   (fullResponse.count >= 600 && elapsed > 4.0) ||
                   elapsed > 5.0 {
                    logger.info("✅ Returning with \(fullResponse.count) chars after \(String(format: "%.1f", elapsed))s")
                    break
                }
            }

            if fullResponse.isEmpty {
                logger.error("❌ Received empty response from Perplexity")
                throw PerplexityError.invalidResponse
            }

            logger.info("✅ Chat completed with \(responseCount) chunks, final length: \(fullResponse.count)")
            return fullResponse
        } catch {
            logger.error("❌ Chat failed: \(error)")
            throw error
        }
    }
    
    func clearCache() async {
        await responseCache.clear()
        logger.info("🧹 Cache cleared")
    }
    
    func getCacheStats() async -> (hits: Int, misses: Int, size: Int) {
        return await responseCache.getStats()
    }

    // MARK: - Enriched Context Building

    private func buildEnrichedBookContext(
        for book: Book,
        enrichment: (synopsis: String, characters: [String], themes: [String], setting: String)? = nil,
        sessionHistory: [String]? = nil,
        userNotes: [(content: String, page: Int?)]? = nil,
        userQuotes: [(text: String, page: Int?, notes: String?)]? = nil,
        userQuestions: [(question: String, page: Int?, answer: String?)]? = nil,
        currentPage: Int? = nil
    ) -> String {
        var context = """
        IMPORTANT: You are answering questions SPECIFICALLY about the book "\(book.title)" by \(book.author).

        ALL answers MUST relate directly to this book. When asked about characters, plot, themes, or any aspect - answer ONLY about "\(book.title)".
        """

        // SERIES SPOILER PROTECTION
        let seriesInfo = detectSeriesInformation(for: book)
        if let (seriesName, bookNumber) = seriesInfo {
            context += """


            CRITICAL SPOILER PROTECTION:
            This book is part of the "\(seriesName)" series (Book \(bookNumber)).

            STRICT RULES:
            1. The user is currently reading Book \(bookNumber). You may discuss:
               ✅ Events from Book \(bookNumber) (current book) - NO RESTRICTIONS
               ✅ Events from Books 1-\(bookNumber - 1) (previous books) - SAFE to reference

            2. You must NEVER reveal or hint at:
               ❌ Plot points from Book \(bookNumber + 1) or later (future books)
               ❌ Character fates that occur after Book \(bookNumber)
               ❌ Major revelations or twists from later books
               ❌ Events, battles, or outcomes from future installments

            3. If asked about the series or future events:
               - Say "I can discuss Books 1-\(bookNumber), but I'll avoid spoiling future books"
               - Suggest they ask again after finishing later books
               - NEVER say "I can't answer that" without explaining why

            4. When discussing connections to previous books:
               - Feel free to reference earlier events that inform the current story
               - Explain callbacks and references to Books 1-\(bookNumber - 1)
            """
        } else {
            // Even for standalone books, add general spoiler awareness
            context += """


            SPOILER AWARENESS:
            - If this book is part of a series, discuss only THIS book and any confirmed prequels
            - Do not reveal plot points beyond what the user is currently reading
            - If unsure about spoilers, err on the side of caution
            """
        }

        // Use enrichment data if provided
        if let enrichment = enrichment {
            context += "\n\n"
            context += "BOOK CONTEXT:\n"

            if !enrichment.synopsis.isEmpty {
                context += "Premise: \(enrichment.synopsis)\n"
            }

            if !enrichment.characters.isEmpty {
                context += "Main Characters: \(enrichment.characters.joined(separator: ", "))\n"
            }

            if !enrichment.themes.isEmpty {
                context += "Key Themes: \(enrichment.themes.joined(separator: ", "))\n"
            }

            if !enrichment.setting.isEmpty {
                context += "Setting: \(enrichment.setting)\n"
            }
        }

        // Add session history for continuity
        if let sessionHistory = sessionHistory, !sessionHistory.isEmpty {
            context += "\n\n"
            context += "PREVIOUS READING SESSIONS:\n"
            context += "The user has had previous reading sessions about this book. Here's what they explored:\n\n"
            for (index, insight) in sessionHistory.enumerated() {
                context += "Session \(index + 1): \(insight)\n"
            }
            context += "\nUse this context to provide continuity and build on previous discussions.\n"
            context += "You can reference previous sessions naturally, e.g., 'Building on what we discussed before...'\n"
        }

        // Add user's current page for context
        if let currentPage = currentPage, let pageCount = book.pageCount, pageCount > 0 {
            let percentage = Int((Double(currentPage) / Double(pageCount)) * 100)
            context += "\n\n"
            context += "READING PROGRESS:\n"
            context += "The user is currently on page \(currentPage) of \(pageCount) (\(percentage)% through the book).\n"
        }

        // Add user's notes - shows what they're thinking and noticing
        if let userNotes = userNotes, !userNotes.isEmpty {
            context += "\n\n"
            context += "USER'S NOTES AND OBSERVATIONS:\n"
            context += "These are the user's own thoughts and observations as they read. Use these to understand what interests them, what they're questioning, and what themes resonate:\n\n"
            for (index, note) in userNotes.enumerated() {
                if let page = note.page {
                    context += "\(index + 1). (Page \(page)): \(note.content)\n"
                } else {
                    context += "\(index + 1). \(note.content)\n"
                }
            }
            context += "\nWhen answering, you can reference their notes naturally, e.g., 'I see you noted that...' or 'Building on your observation about...'\n"
        }

        // Add user's highlighted quotes - shows what resonates with them
        if let userQuotes = userQuotes, !userQuotes.isEmpty {
            context += "\n\n"
            context += "PASSAGES THE USER HIGHLIGHTED:\n"
            context += "These quotes show what resonated with the user emotionally or intellectually:\n\n"
            for (index, quote) in userQuotes.enumerated() {
                var quoteText = "\(index + 1). "
                if let page = quote.page {
                    quoteText += "(Page \(page)) "
                }
                quoteText += "\"\(quote.text)\""
                if let notes = quote.notes, !notes.isEmpty {
                    quoteText += " — User's note: \(notes)"
                }
                context += quoteText + "\n"
            }
            context += "\nUse these to understand the user's interests and values. You can reference specific quotes in your answers.\n"
        }

        // Add user's questions - shows what they're wondering about
        if let userQuestions = userQuestions, !userQuestions.isEmpty {
            context += "\n\n"
            context += "USER'S QUESTIONS:\n"
            context += "The user has asked themselves these questions while reading:\n\n"
            for (index, question) in userQuestions.enumerated() {
                var questionText = "\(index + 1). "
                if let page = question.page {
                    questionText += "(Page \(page)) "
                }
                questionText += question.question
                if let answer = question.answer, !answer.isEmpty {
                    questionText += " [They later noted: \(answer)]"
                }
                context += questionText + "\n"
            }
            context += "\nIf relevant, you can help answer their earlier questions or build on their curiosity.\n"
        }

        context += """


        For example:
        - "Who is the main character?" → Answer about the main character(s) in "\(book.title)"
        - "What happens next?" → Answer about what happens next in "\(book.title)"
        - "What is the theme?" → Answer about the themes in "\(book.title)"

        NEVER give generic definitions. ALWAYS give book-specific answers about "\(book.title)".

        RESPONSE TONE:
        - Be natural and conversational, like a knowledgeable friend
        - Avoid overly formal or literary language ("Thus...", "Indeed...", "One might say...")
        - Use direct, clear sentences
        - Be helpful and informative without being pompous
        - NO emojis in responses
        - NO sycophantic language ("You're right!", "Great question!", "Excellent observation!")
        - NO cliche AI responses ("As an AI...", "I'm here to help...", generic pleasantries)
        - Just answer the question directly and naturally
        """

        return context
    }

    /// Detects if a book is part of a series and returns (seriesName, bookNumber)
    private func detectSeriesInformation(for book: Book) -> (String, Int)? {
        let title = book.title
        let author = book.author

        // Pattern 1: "Series Name: Book N" or "Series Name, Book N"
        if let match = title.range(of: #"(.+?)[\s:,]+Book\s+(\d+)"#, options: .regularExpression) {
            let seriesName = String(title[..<match.lowerBound]).trimmingCharacters(in: .whitespaces)
            if let bookNumberStr = title[match].components(separatedBy: CharacterSet.decimalDigits.inverted).last,
               let bookNumber = Int(bookNumberStr) {
                return (seriesName, bookNumber)
            }
        }

        // Pattern 2: "Title (#N in Series)" or "(Book N)"
        if let match = title.range(of: #"\((?:#|Book\s+)?(\d+)(?:\s+in\s+.+?)?\)"#, options: .regularExpression) {
            let bookNumberStr = title[match].components(separatedBy: CharacterSet.decimalDigits.inverted).first { !$0.isEmpty } ?? ""
            if let bookNumber = Int(bookNumberStr) {
                let seriesName = String(title[..<match.lowerBound]).trimmingCharacters(in: .whitespaces)
                return (seriesName.isEmpty ? "series" : seriesName, bookNumber)
            }
        }

        // Known series patterns by author and title
        let knownSeries: [(pattern: String, series: String, bookMap: [String: Int])] = [
            ("harry potter", "Harry Potter", [
                "philosopher's stone": 1, "sorcerer's stone": 1,
                "chamber of secrets": 2,
                "prisoner of azkaban": 3,
                "goblet of fire": 4,
                "order of the phoenix": 5,
                "half-blood prince": 6,
                "deathly hallows": 7
            ]),
            ("lord of the rings", "Lord of the Rings", [
                "fellowship": 1,
                "two towers": 2,
                "return of the king": 3
            ]),
            ("hunger games", "Hunger Games", [
                "hunger games": 1,
                "catching fire": 2,
                "mockingjay": 3
            ]),
            ("dune", "Dune", [
                "dune": 1,
                "dune messiah": 2,
                "children of dune": 3,
                "god emperor": 4
            ])
        ]

        let lowerTitle = title.lowercased()
        for (pattern, seriesName, bookMap) in knownSeries {
            if lowerTitle.contains(pattern) || author.lowercased().contains(pattern) {
                for (bookKey, bookNum) in bookMap {
                    if lowerTitle.contains(bookKey) {
                        return (seriesName, bookNum)
                    }
                }
            }
        }

        return nil
    }

    private func getEnrichmentData(for book: Book) -> (synopsis: String, characters: [String], themes: [String], setting: String)? {
        // This is a simplified lookup - ideally we'd inject BookModel via dependency
        // For now, we'll return nil and rely on basic context
        // TODO: Enhance by accepting BookModel directly in chat() method
        return nil
    }
}

// MARK: - Query Complexity Analyzer

private class QueryComplexityAnalyzer {
    enum Complexity {
        case simple
        case moderate
        case complex
    }
    
    func analyze(_ query: String) -> Complexity {
        let wordCount = query.split(separator: " ").count
        let hasComplexTerms = checkForComplexTerms(query)
        let requiresReasoning = checkForReasoningIndicators(query)
        
        if wordCount < 10 && !hasComplexTerms && !requiresReasoning {
            return .simple
        } else if wordCount > 30 || requiresReasoning {
            return .complex
        } else {
            return .moderate
        }
    }
    
    private func checkForComplexTerms(_ query: String) -> Bool {
        let complexTerms = [
            "analyze", "compare", "contrast", "evaluate",
            "synthesize", "critique", "examine", "interpret"
        ]
        let queryLower = query.lowercased()
        return complexTerms.contains { queryLower.contains($0) }
    }
    
    private func checkForReasoningIndicators(_ query: String) -> Bool {
        let indicators = [
            "why", "how does", "what if", "explain the relationship",
            "what are the implications", "how would you"
        ]
        let queryLower = query.lowercased()
        return indicators.contains { queryLower.contains($0) }
    }
}

// MARK: - Token Batcher

private actor TokenBatcher {
    private var buffer: String = ""
    private var task: Task<Void, Never>?
    private let batchInterval: TimeInterval
    
    init(batchInterval: TimeInterval) {
        self.batchInterval = batchInterval
    }
    
    func addToken(_ token: String, handler: @escaping (String) -> Void) {
        buffer += token
        
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(batchInterval * 1_000_000_000))
            
            if !buffer.isEmpty {
                let batch = buffer
                buffer = ""
                handler(batch)
            }
        }
    }
}

// MARK: - Rate Limiter

private actor RateLimiter {
    private var requestCount = 0
    private var windowStart = Date()
    private let maxRequests = 50  // Per minute
    private let windowDuration: TimeInterval = 60
    
    func shouldQueue() -> Bool {
        let now = Date()
        
        // Reset window if needed
        if now.timeIntervalSince(windowStart) > windowDuration {
            requestCount = 0
            windowStart = now
        }
        
        // Check if we've hit the limit
        if requestCount >= maxRequests {
            return true
        }
        
        requestCount += 1
        return false
    }
    
    func reset() {
        requestCount = 0
        windowStart = Date()
    }
}

// MARK: - Response Cache

private actor PerplexityResponseCache {
    private var cache: [String: CachedResponse] = [:]
    private var db: OpaquePointer?
    private var hits = 0
    private var misses = 0
    
    struct CachedResponse {
        let response: PerplexityResponse
        let expiration: Date
    }
    
    func initialize() {
        setupSQLiteCache()
        loadFromDisk()
    }
    
    private func setupSQLiteCache() {
        let dbPath = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("perplexity_cache.db")
        
        if sqlite3_open(dbPath.path, &db) == SQLITE_OK {
            let createTable = """
                CREATE TABLE IF NOT EXISTS response_cache (
                    key TEXT PRIMARY KEY,
                    text TEXT,
                    citations TEXT,
                    model TEXT,
                    confidence REAL,
                    expiration REAL
                );
            """
            
            sqlite3_exec(db, createTable, nil, nil, nil)
        }
    }
    
    private func loadFromDisk() {
        guard let db = db else { return }
        
        let query = "SELECT * FROM response_cache WHERE expiration > ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                if let keyData = sqlite3_column_text(statement, 0),
                   let textData = sqlite3_column_text(statement, 1),
                   let citationsData = sqlite3_column_text(statement, 2),
                   let modelData = sqlite3_column_text(statement, 3) {
                    
                    let key = String(cString: keyData)
                    let text = String(cString: textData)
                    let citationsJSON = String(cString: citationsData)
                    let model = String(cString: modelData)
                    let confidence = sqlite3_column_double(statement, 4)
                    let expiration = Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))
                    
                    // Decode citations
                    let citations: [Citation] = (try? JSONDecoder().decode(
                        [Citation].self,
                        from: citationsJSON.data(using: .utf8) ?? Data()
                    )) ?? []
                    
                    cache[key] = CachedResponse(
                        response: PerplexityResponse(
                            text: text,
                            citations: citations,
                            model: model,
                            confidence: confidence,
                            cached: true
                        ),
                        expiration: expiration
                    )
                }
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func get(key: String) -> PerplexityResponse? {
        if let cached = cache[key], cached.expiration > Date() {
            hits += 1
            return cached.response
        }
        
        misses += 1
        cache.removeValue(forKey: key)
        deleteFromDisk(key: key)
        return nil
    }
    
    func set(key: String, response: PerplexityResponse, expiration: Date) {
        cache[key] = CachedResponse(response: response, expiration: expiration)
        saveToDisk(key: key, response: response, expiration: expiration)
    }
    
    private func saveToDisk(key: String, response: PerplexityResponse, expiration: Date) {
        guard let db = db else { return }
        
        let citationsJSON = (try? JSONEncoder().encode(response.citations)) ?? Data()
        let citationsString = String(data: citationsJSON, encoding: .utf8) ?? "[]"
        
        let insert = """
            INSERT OR REPLACE INTO response_cache 
            (key, text, citations, model, confidence, expiration)
            VALUES (?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insert, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, key, -1, nil)
            sqlite3_bind_text(statement, 2, response.text, -1, nil)
            sqlite3_bind_text(statement, 3, citationsString, -1, nil)
            sqlite3_bind_text(statement, 4, response.model, -1, nil)
            sqlite3_bind_double(statement, 5, response.confidence)
            sqlite3_bind_double(statement, 6, expiration.timeIntervalSince1970)
            
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    private func deleteFromDisk(key: String) {
        guard let db = db else { return }
        
        let delete = "DELETE FROM response_cache WHERE key = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, delete, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, key, -1, nil)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
    
    func clear() {
        cache.removeAll()
        hits = 0
        misses = 0
        
        guard let db = db else { return }
        sqlite3_exec(db, "DELETE FROM response_cache;", nil, nil, nil)
    }
    
    func getStats() -> (hits: Int, misses: Int, size: Int) {
        return (hits, misses, cache.count)
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
}

// MARK: - Queued Request

private struct QueuedRequest {
    let query: String
    let bookContext: Book?
    let priority: Priority
    let continuation: AsyncThrowingStream<PerplexityResponse, Error>.Continuation
    
    enum Priority: Int {
        case background = 0
        case utility = 1
        case userInitiated = 2
        case immediate = 3
    }
}