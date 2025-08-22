import Foundation
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "ResponseCache")

// MARK: - Cached Response Model
struct CachedResponse: Codable {
    let response: String
    let timestamp: Date
    let bookContext: String?
    let confidence: Float
    let model: String
    let accessCount: Int
    let lastAccessed: Date
    
    var isExpired: Bool {
        // Dynamic expiration based on confidence and access patterns
        let baseExpiry: TimeInterval = 3600 // 1 hour
        let confidenceMultiplier = Double(confidence) // Higher confidence = longer cache
        let accessMultiplier = min(Double(accessCount) * 0.1, 2.0) // More access = longer cache
        
        let dynamicExpiry = baseExpiry * confidenceMultiplier * (1.0 + accessMultiplier)
        return Date().timeIntervalSince(timestamp) > dynamicExpiry
    }
    
    var shouldPrefetch: Bool {
        // Prefetch popular responses before they expire
        let timeToExpiry = timestamp.addingTimeInterval(3600).timeIntervalSinceNow
        return accessCount > 3 && timeToExpiry < 600 // 10 minutes before expiry
    }
}

// MARK: - Response Cache Manager
actor ResponseCache {
    static let shared = ResponseCache()
    
    private let cacheKey = "com.epilogue.responseCache"
    private var cache: [String: CachedResponse] = [:]
    private let cacheQueue = DispatchQueue(label: "com.epilogue.responseCache", attributes: .concurrent)
    
    private init() {
        loadCache()
        cleanExpiredEntries()
    }
    
    // MARK: - Public Methods
    
    /// Generate cache key from question and book context
    func generateKey(question: String, bookTitle: String?) -> String {
        let normalizedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let context = bookTitle ?? "general"
        return "\(normalizedQuestion):::\(context)".data(using: .utf8)?.base64EncodedString() ?? normalizedQuestion
    }
    
    /// Get cached response if available and not expired
    func getResponse(for question: String, bookTitle: String?) -> String? {
        let key = generateKey(question: question, bookTitle: bookTitle)
        
        return cacheQueue.sync {
            guard let cached = cache[key], !cached.isExpired else {
                // Clean up expired entry
                cache.removeValue(forKey: key)
                return nil
            }
            
            // Update access tracking
            let updatedCached = CachedResponse(
                response: cached.response,
                timestamp: cached.timestamp,
                bookContext: cached.bookContext,
                confidence: cached.confidence,
                model: cached.model,
                accessCount: cached.accessCount + 1,
                lastAccessed: Date()
            )
            cache[key] = updatedCached
            
            logger.info("📦 Cache hit for question (access count: \(updatedCached.accessCount))")
            return cached.response
        }
    }
    
    /// Cache a response with enhanced metadata
    func cacheResponse(_ response: String, for question: String, bookTitle: String?, confidence: Float = 0.8, model: String = "sonar") {
        let key = generateKey(question: question, bookTitle: bookTitle)
        let cached = CachedResponse(
            response: response,
            timestamp: Date(),
            bookContext: bookTitle,
            confidence: confidence,
            model: model,
            accessCount: 0,
            lastAccessed: Date()
        )
        
        cacheQueue.async(flags: .barrier) {
            self.cache[key] = cached
            self.saveCache()
            logger.info("💾 Cached response for question (confidence: \(confidence))")
        }
    }
    
    /// Clear all cached responses
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
            self.saveCache()
        }
    }
    
    /// Clean expired entries and identify prefetch candidates
    func cleanExpiredEntries() {
        cacheQueue.async(flags: .barrier) {
            let expiredKeys = self.cache.filter { $0.value.isExpired }.map { $0.key }
            let prefetchCandidates = self.cache.filter { $0.value.shouldPrefetch }
            
            // Remove expired entries
            for key in expiredKeys {
                self.cache.removeValue(forKey: key)
            }
            
            // Log prefetch candidates
            if !prefetchCandidates.isEmpty {
                logger.info("🔄 Found \(prefetchCandidates.count) responses that should be prefetched")
                
                // Post notification for prefetch
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: Notification.Name("ShouldPrefetchResponses"),
                        object: prefetchCandidates
                    )
                }
            }
            
            self.saveCache()
            logger.info("🧹 Cleaned cache: removed \(expiredKeys.count) expired entries")
        }
    }
    
    /// Get cache statistics
    func getCacheStatistics() -> [String: Any] {
        return cacheQueue.sync {
            let totalEntries = cache.count
            let highConfidenceEntries = cache.values.filter { $0.confidence > 0.8 }.count
            let frequentlyAccessedEntries = cache.values.filter { $0.accessCount > 3 }.count
            let averageAge = cache.values.isEmpty ? 0 : 
                cache.values.map { Date().timeIntervalSince($0.timestamp) }.reduce(0, +) / Double(cache.count)
            
            return [
                "totalEntries": totalEntries,
                "highConfidenceEntries": highConfidenceEntries,
                "frequentlyAccessedEntries": frequentlyAccessedEntries,
                "averageAgeSeconds": averageAge,
                "hitRate": cache.values.map { $0.accessCount }.reduce(0, +)
            ]
        }
    }
    
    /// Preload common questions for a book
    func preloadBookQuestions(_ book: Book, commonQuestions: [String]) {
        logger.info("🔄 Preloading \(commonQuestions.count) questions for book: \(book.title)")
        
        cacheQueue.async(flags: .barrier) {
            for question in commonQuestions {
                let key = self.generateKey(question: question, bookTitle: book.title)
                
                // Only mark for preload if not already cached
                if self.cache[key] == nil {
                    // Post notification to generate response
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: Notification.Name("ShouldPreloadQuestion"),
                            object: [
                                "question": question,
                                "book": book
                            ]
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode([String: CachedResponse].self, from: data) else {
            return
        }
        
        cacheQueue.async(flags: .barrier) {
            self.cache = decoded
        }
    }
    
    private func saveCache() {
        guard let encoded = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(encoded, forKey: cacheKey)
    }
}

// MARK: - PerplexityService Extension
extension PerplexityService {
    static func cachedChat(message: String, bookContext: Book? = nil) async throws -> String {
        let bookTitle = bookContext?.title
        
        // Check cache first
        if let cachedResponse = ResponseCache.shared.getResponse(for: message, bookTitle: bookTitle) {
            print("📦 Using cached response for: \(message)")
            return cachedResponse
        }
        
        // Generate new response
        print("🔄 Generating new response for: \(message)")
        let response = try await staticChat(message: message, bookContext: bookContext)
        
        // Cache the response
        ResponseCache.shared.cacheResponse(response, for: message, bookTitle: bookTitle)
        
        return response
    }
}