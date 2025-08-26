import Foundation
import CoreData
import Combine

class QueryOptimizationService: ObservableObject {
    static let shared = QueryOptimizationService()
    
    @Published var currentQuota: UserQuota?
    @Published var queriesRemainingToday: Int = 20
    @Published var isPro: Bool = false
    @Published var cacheHitRate: Double = 0.0
    
    private let coreDataManager: CoreDataManager
    private let semanticMatcher: SemanticSimilarityMatcher
    private let queryClassifier: QueryClassifier
    private let contextWindower: ContextWindowManager
    private var cancellables = Set<AnyCancellable>()
    
    enum QueryComplexity {
        case simple      // Use cache
        case moderate    // Try cache first, then API with minimal context
        case complex     // Direct API with full context
        case analytical  // Pro only - requires deep analysis
    }
    
    enum OptimizationResult {
        case cached(response: String, confidence: Double)
        case apiRequired(context: String, estimatedTokens: Int)
        case quotaExceeded
        case upgradeRequired
    }
    
    init(coreDataManager: CoreDataManager = .shared) {
        self.coreDataManager = coreDataManager
        self.semanticMatcher = SemanticSimilarityMatcher()
        self.queryClassifier = QueryClassifier()
        self.contextWindower = ContextWindowManager()
        
        loadCurrentQuota()
        setupQuotaMonitoring()
    }
    
    // MARK: - Query Optimization
    
    func optimizeQuery(
        _ query: String,
        for book: Book? = nil,
        allowProgressive: Bool = true
    ) async throws -> OptimizationResult {
        
        // Check quota first
        guard hasAvailableQueries() else {
            if isPro {
                // Pro users always have access
            } else {
                return .quotaExceeded
            }
        }
        
        // Classify query complexity
        let complexity = queryClassifier.classify(query)
        
        // Check if this requires Pro
        if complexity == .analytical && !isPro {
            return .upgradeRequired
        }
        
        // Try cache first for simple/moderate queries
        if complexity == .simple || complexity == .moderate {
            if let cachedResult = await findCachedAnswer(for: query, bookId: book?.id) {
                recordCacheHit()
                return .cached(response: cachedResult.response, confidence: cachedResult.confidence)
            }
        }
        
        // Prepare optimized context
        let optimizedContext = try await prepareOptimizedContext(
            for: query,
            book: book,
            complexity: complexity,
            allowProgressive: allowProgressive
        )
        
        let estimatedTokens = estimateTokenCount(query: query, context: optimizedContext)
        
        return .apiRequired(context: optimizedContext, estimatedTokens: estimatedTokens)
    }
    
    // MARK: - Cache Management
    
    private func findCachedAnswer(for query: String, bookId: UUID?) async -> (response: String, confidence: Double)? {
        let context = coreDataManager.viewContext
        
        // First try exact match
        let hash = CachedQuery.generateHash(for: query, bookId: bookId)
        let exactRequest = CachedQuery.fetchRequest()
        exactRequest.predicate = NSPredicate(format: "queryHash == %@", hash)
        exactRequest.fetchLimit = 1
        
        if let exactMatch = try? context.fetch(exactRequest).first,
           !exactMatch.isStale {
            exactMatch.updateAccess()
            try? context.save()
            return (exactMatch.response ?? "", 1.0)
        }
        
        // Try semantic similarity matching
        let embedding = try? await semanticMatcher.generateEmbedding(for: query)
        if let embedding = embedding {
            let similarQueries = await findSimilarQueries(embedding: embedding, threshold: 0.85)
            
            if let bestMatch = similarQueries.first,
               let response = bestMatch.response {
                bestMatch.updateAccess()
                try? context.save()
                
                let confidence = calculateConfidence(similarity: 0.85, age: bestMatch.cacheAge)
                return (response, confidence)
            }
        }
        
        return nil
    }
    
    private func findSimilarQueries(embedding: [Float], threshold: Double) async -> [CachedQuery] {
        let context = coreDataManager.viewContext
        let request = CachedQuery.fetchRequest()
        request.predicate = NSPredicate(format: "embedding != nil")
        
        guard let allQueries = try? context.fetch(request) else { return [] }
        
        var similarities: [(query: CachedQuery, similarity: Double)] = []
        
        for cachedQuery in allQueries {
            if let cachedEmbedding = cachedQuery.embedding,
               let embeddingArray = try? JSONDecoder().decode([Float].self, from: cachedEmbedding) {
                let similarity = semanticMatcher.cosineSimilarity(embedding, embeddingArray)
                if similarity >= threshold {
                    similarities.append((cachedQuery, similarity))
                }
            }
        }
        
        return similarities
            .sorted { $0.similarity > $1.similarity }
            .map { $0.query }
    }
    
    func cacheResponse(
        query: String,
        response: String,
        bookId: UUID?,
        bookTitle: String?,
        context: String?,
        tokensUsed: Int,
        responseTime: TimeInterval,
        queryType: String
    ) async {
        let context = coreDataManager.viewContext
        
        let cachedQuery = CachedQuery(context: context)
        cachedQuery.query = query
        cachedQuery.queryHash = CachedQuery.generateHash(for: query, bookId: bookId)
        cachedQuery.response = response
        cachedQuery.bookId = bookId
        cachedQuery.bookTitle = bookTitle
        cachedQuery.contextUsed = context
        cachedQuery.tokensUsed = Int32(tokensUsed)
        cachedQuery.responseTime = responseTime
        cachedQuery.queryType = queryType
        
        // Generate and store embedding for semantic matching
        if let embedding = try? await semanticMatcher.generateEmbedding(for: query),
           let embeddingData = try? JSONEncoder().encode(embedding) {
            cachedQuery.embedding = embeddingData
        }
        
        try? context.save()
        
        // Update analytics
        recordAPICall(tokensUsed: tokensUsed, responseTime: responseTime)
    }
    
    // MARK: - Context Optimization
    
    private func prepareOptimizedContext(
        for query: String,
        book: Book?,
        complexity: QueryComplexity,
        allowProgressive: Bool
    ) async throws -> String {
        
        guard let book = book else {
            return "" // No context needed for general queries
        }
        
        switch complexity {
        case .simple:
            // Minimal context - just book metadata
            return contextWindower.prepareMinimalContext(book: book)
            
        case .moderate:
            // Relevant excerpts only
            let relevantContent = try await extractRelevantContent(query: query, book: book, maxChunks: 3)
            return contextWindower.prepareModerateContext(book: book, excerpts: relevantContent)
            
        case .complex, .analytical:
            // Full context with smart windowing
            let relevantContent = try await extractRelevantContent(query: query, book: book, maxChunks: 10)
            return contextWindower.prepareFullContext(book: book, excerpts: relevantContent)
        }
    }
    
    private func extractRelevantContent(query: String, book: Book, maxChunks: Int) async throws -> [String] {
        // Extract relevant quotes and notes
        var excerpts: [String] = []
        
        // Get relevant quotes
        if let quotes = book.quotes {
            let relevantQuotes = quotes
                .filter { quote in
                    guard let text = quote.text else { return false }
                    return isRelevant(text: text, to: query)
                }
                .prefix(maxChunks / 2)
                .map { $0.text ?? "" }
            
            excerpts.append(contentsOf: relevantQuotes)
        }
        
        // Get relevant notes
        if let notes = book.notes {
            let relevantNotes = notes
                .filter { note in
                    let text = (note.title ?? "") + " " + (note.content ?? "")
                    return isRelevant(text: text, to: query)
                }
                .prefix(maxChunks / 2)
                .map { (note.title ?? "") + ": " + (note.content ?? "") }
            
            excerpts.append(contentsOf: relevantNotes)
        }
        
        return Array(excerpts.prefix(maxChunks))
    }
    
    private func isRelevant(text: String, to query: String) -> Bool {
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))
        let textWords = Set(text.lowercased().split(separator: " ").map(String.init))
        
        let overlap = queryWords.intersection(textWords)
        return Double(overlap.count) / Double(queryWords.count) > 0.3
    }
    
    // MARK: - Token Estimation
    
    private func estimateTokenCount(query: String, context: String) -> Int {
        // Rough estimation: 1 token ≈ 4 characters
        let totalCharacters = query.count + context.count
        return totalCharacters / 4
    }
    
    // MARK: - Quota Management
    
    private func loadCurrentQuota() {
        let context = coreDataManager.viewContext
        let request = UserQuota.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@",
            Calendar.current.startOfDay(for: Date()) as NSDate
        )
        request.fetchLimit = 1
        
        if let quota = try? context.fetch(request).first {
            currentQuota = quota
            queriesRemainingToday = Int(quota.freeQueriesLimit - quota.freeQueriesUsed)
            isPro = quota.isPro
        } else {
            createTodaysQuota()
        }
    }
    
    private func createTodaysQuota() {
        let context = coreDataManager.viewContext
        let quota = UserQuota(context: context)
        quota.id = UUID()
        quota.date = Date()
        quota.freeQueriesUsed = 0
        quota.freeQueriesLimit = 20
        quota.isPro = checkProStatus()
        quota.lastResetDate = Date()
        
        try? context.save()
        currentQuota = quota
        queriesRemainingToday = 20
    }
    
    private func checkProStatus() -> Bool {
        // Check if user has active Pro subscription
        UserDefaults.standard.bool(forKey: "isProUser")
    }
    
    func hasAvailableQueries() -> Bool {
        if isPro { return true }
        return queriesRemainingToday > 0
    }
    
    func consumeQuery() {
        guard let quota = currentQuota else { return }
        
        let context = coreDataManager.viewContext
        quota.freeQueriesUsed += 1
        quota.totalQueriesAllTime += 1
        
        try? context.save()
        queriesRemainingToday = max(0, Int(quota.freeQueriesLimit - quota.freeQueriesUsed))
    }
    
    // MARK: - Analytics
    
    private func recordCacheHit() {
        updateAnalytics { analytics in
            analytics.cacheHits += 1
            analytics.totalQueries += 1
            analytics.cacheHitRate = Double(analytics.cacheHits) / Double(analytics.totalQueries)
        }
    }
    
    private func recordAPICall(tokensUsed: Int, responseTime: TimeInterval) {
        updateAnalytics { analytics in
            analytics.apiCalls += 1
            analytics.totalQueries += 1
            analytics.totalTokensUsed += Int32(tokensUsed)
            analytics.averageResponseTime = (analytics.averageResponseTime * Double(analytics.totalQueries - 1) + responseTime) / Double(analytics.totalQueries)
            analytics.cacheHitRate = Double(analytics.cacheHits) / Double(analytics.totalQueries)
            
            // Estimate cost (rough calculation)
            let costPerToken = 0.000002 // $0.002 per 1K tokens
            analytics.totalCost += Double(tokensUsed) * costPerToken
        }
    }
    
    private func updateAnalytics(_ update: (QueryAnalytics) -> Void) {
        let context = coreDataManager.viewContext
        let request = QueryAnalytics.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@",
            Calendar.current.startOfDay(for: Date()) as NSDate
        )
        request.fetchLimit = 1
        
        let analytics: QueryAnalytics
        if let existing = try? context.fetch(request).first {
            analytics = existing
        } else {
            analytics = QueryAnalytics(context: context)
            analytics.id = UUID()
            analytics.date = Date()
        }
        
        update(analytics)
        
        try? context.save()
        
        // Update published cache hit rate
        cacheHitRate = analytics.cacheHitRate
    }
    
    // MARK: - Quota Monitoring
    
    private func setupQuotaMonitoring() {
        // Reset quota daily
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.checkAndResetDailyQuota()
            }
            .store(in: &cancellables)
    }
    
    private func checkAndResetDailyQuota() {
        guard let quota = currentQuota else { return }
        
        let calendar = Calendar.current
        if !calendar.isDateInToday(quota.lastResetDate ?? Date()) {
            createTodaysQuota()
        }
    }
    
    private func calculateConfidence(similarity: Double, age: TimeInterval) -> Double {
        let agePenalty = max(0, 1 - (age / (7 * 24 * 60 * 60))) // Decay over 7 days
        return similarity * agePenalty
    }
}