import Foundation

// MARK: - Cached Response Model
struct CachedResponse: Codable {
    let response: String
    let timestamp: Date
    let bookContext: String?
    
    var isExpired: Bool {
        // Cache for 1 hour
        Date().timeIntervalSince(timestamp) > 3600
    }
}

// MARK: - Response Cache Manager
final class ResponseCache {
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
                return nil
            }
            return cached.response
        }
    }
    
    /// Cache a response
    func cacheResponse(_ response: String, for question: String, bookTitle: String?) {
        let key = generateKey(question: question, bookTitle: bookTitle)
        let cached = CachedResponse(
            response: response,
            timestamp: Date(),
            bookContext: bookTitle
        )
        
        cacheQueue.async(flags: .barrier) {
            self.cache[key] = cached
            self.saveCache()
        }
    }
    
    /// Clear all cached responses
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
            self.saveCache()
        }
    }
    
    /// Clean expired entries
    func cleanExpiredEntries() {
        cacheQueue.async(flags: .barrier) {
            self.cache = self.cache.filter { !$0.value.isExpired }
            self.saveCache()
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