import Foundation
import SwiftData
import OSLog
import Combine

// MARK: - Search Result Model
struct SearchResult: Codable, Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let snippet: String
    let date: String?
    let lastUpdated: String?
    
    enum CodingKeys: String, CodingKey {
        case title, url, snippet, date
        case lastUpdated = "last_updated"
    }
}

// MARK: - Search Response
struct SearchResponse: Codable {
    let results: [SearchResult]
}

// MARK: - Cached Search Result for SwiftData
@Model
final class CachedSearchResult {
    @Attribute(.unique) var cacheKey: String
    var query: String
    var domains: String // JSON encoded array
    var results: Data // JSON encoded SearchResult array
    var createdAt: Date
    var expiresAt: Date
    var searchType: String // "book", "trending", "general"
    
    init(query: String, domains: [String], results: [SearchResult], searchType: String, cacheDuration: TimeInterval) {
        self.cacheKey = CachedSearchResult.generateCacheKey(query: query, domains: domains)
        self.query = query

        // Safely encode domains to JSON string
        if let domainsData = try? JSONEncoder().encode(domains),
           let domainsString = String(data: domainsData, encoding: .utf8) {
            self.domains = domainsString
        } else {
            self.domains = "[]"
        }

        self.results = (try? JSONEncoder().encode(results)) ?? Data()
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(cacheDuration)
        self.searchType = searchType
    }
    
    static func generateCacheKey(query: String, domains: [String]) -> String {
        let sortedDomains = domains.sorted().joined(separator: ",")
        return "\(query.lowercased())|\(sortedDomains)"
    }
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    func getResults() -> [SearchResult] {
        (try? JSONDecoder().decode([SearchResult].self, from: results)) ?? []
    }
}

// MARK: - Perplexity Search Service
@MainActor
final class PerplexitySearchService: ObservableObject {
    static let shared = PerplexitySearchService()
    
    private let logger = Logger(subsystem: "com.epilogue.app", category: "PerplexitySearch")
    private let session: URLSession
    private var apiKey: String?
    private let searchEndpoint = "https://api.perplexity.ai/search"
    
    // Cache durations
    private let bookDataCacheDuration: TimeInterval = 14 * 24 * 60 * 60 // 14 days
    private let trendingDataCacheDuration: TimeInterval = 3 * 24 * 60 * 60 // 3 days
    private let generalCacheDuration: TimeInterval = 24 * 60 * 60 // 1 day
    
    // Trusted book sources
    static let trustedBookDomains = [
        "goodreads.com",
        "amazon.com",
        "barnesandnoble.com",
        "bookshop.org",
        "nytimes.com",
        "theguardian.com",
        "publishersweekly.com",
        "kirkusreviews.com",
        "bookpage.com",
        "npr.org",
        "penguinrandomhouse.com",
        "harpercollins.com",
        "simonandschuster.com"
    ]
    
    // Rate limiting
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 1.0 // 1 second between requests
    
    @Published var isSearching = false
    @Published var searchError: Error?
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        
        self.session = URLSession(configuration: configuration)
        
        // Load API key from settings
        if let storedKey = UserDefaults.standard.string(forKey: "perplexityAPIKey") {
            self.apiKey = storedKey
        }
    }
    
    func configure(apiKey: String) {
        self.apiKey = apiKey
        UserDefaults.standard.set(apiKey, forKey: "perplexityAPIKey")
        logger.info("Perplexity Search API configured")
    }
    
    // MARK: - Public Search Methods
    
    /// Search for book-related content with automatic domain filtering
    func searchBooks(
        query: String,
        additionalDomains: [String] = [],
        modelContext: ModelContext
    ) async throws -> [SearchResult] {
        let domains = Self.trustedBookDomains + additionalDomains
        return try await search(
            query: query,
            domains: domains,
            searchType: "book",
            cacheDuration: bookDataCacheDuration,
            modelContext: modelContext
        )
    }
    
    /// Search for trending books and bestseller lists
    func searchTrending(
        query: String = "bestseller books \(Calendar.current.component(.year, from: Date()))",
        modelContext: ModelContext
    ) async throws -> [SearchResult] {
        let domains = [
            "nytimes.com",
            "amazon.com",
            "goodreads.com",
            "publishersweekly.com",
            "usatoday.com"
        ]
        
        return try await search(
            query: query,
            domains: domains,
            searchType: "trending",
            cacheDuration: trendingDataCacheDuration,
            modelContext: modelContext
        )
    }
    
    /// General search without domain filtering
    func searchGeneral(
        query: String,
        domains: [String] = [],
        modelContext: ModelContext
    ) async throws -> [SearchResult] {
        return try await search(
            query: query,
            domains: domains,
            searchType: "general",
            cacheDuration: generalCacheDuration,
            modelContext: modelContext
        )
    }
    
    // MARK: - Core Search Implementation
    
    private func search(
        query: String,
        domains: [String],
        searchType: String,
        cacheDuration: TimeInterval,
        modelContext: ModelContext
    ) async throws -> [SearchResult] {
        // Check cache first
        let cacheKey = CachedSearchResult.generateCacheKey(query: query, domains: domains)
        let currentDate = Date()
        
        let descriptor = FetchDescriptor<CachedSearchResult>(
            predicate: #Predicate { result in
                result.cacheKey == cacheKey && result.expiresAt > currentDate
            }
        )
        
        if let cached = try? modelContext.fetch(descriptor).first {
            logger.info("Returning cached search results for query: \(query)")
            return cached.getResults()
        }
        
        // Perform new search
        guard let apiKey = apiKey else {
            throw PerplexitySearchError.missingAPIKey
        }
        
        // Rate limiting
        if let lastRequest = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < minRequestInterval {
                try await Task.sleep(nanoseconds: UInt64((minRequestInterval - timeSinceLastRequest) * 1_000_000_000))
            }
        }
        
        isSearching = true
        defer {
            isSearching = false
            lastRequestTime = Date()
        }

        guard let url = URL(string: searchEndpoint) else {
            throw PerplexitySearchError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "query": query,
            "max_results": 10,
            "return_snippets": true,
            "search_recency_filter": searchType == "trending" ? "month" : nil
        ].compactMapValues { $0 }
        
        if !domains.isEmpty {
            body["search_domain_filter"] = domains
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PerplexitySearchError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw PerplexitySearchError.rateLimitExceeded
            }
            throw PerplexitySearchError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        
        // Cache the results
        let cachedResult = CachedSearchResult(
            query: query,
            domains: domains,
            results: searchResponse.results,
            searchType: searchType,
            cacheDuration: cacheDuration
        )
        
        modelContext.insert(cachedResult)
        try? modelContext.save()
        
        logger.info("Cached \(searchResponse.results.count) search results for query: \(query)")
        
        return searchResponse.results
    }
    
    // MARK: - Cache Management
    
    func clearExpiredCache(modelContext: ModelContext) async {
        let currentDate = Date()
        let descriptor = FetchDescriptor<CachedSearchResult>(
            predicate: #Predicate { result in
                result.expiresAt < currentDate
            }
        )
        
        do {
            let expiredResults = try modelContext.fetch(descriptor)
            for result in expiredResults {
                modelContext.delete(result)
            }
            try modelContext.save()
            logger.info("Cleared \(expiredResults.count) expired search cache entries")
        } catch {
            logger.error("Failed to clear expired cache: \(error)")
        }
    }
    
    func clearAllCache(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<CachedSearchResult>()
        
        do {
            let allResults = try modelContext.fetch(descriptor)
            for result in allResults {
                modelContext.delete(result)
            }
            try modelContext.save()
            logger.info("Cleared all search cache entries")
        } catch {
            logger.error("Failed to clear cache: \(error)")
        }
    }
}

// MARK: - Errors
enum PerplexitySearchError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(statusCode: Int)
    case rateLimitExceeded
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Perplexity API key not configured"
        case .invalidResponse:
            return "Invalid response from search API"
        case .httpError(let code):
            return "Search failed with HTTP error \(code)"
        case .rateLimitExceeded:
            return "Search rate limit exceeded. Please try again later."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Search Result Extensions
extension SearchResult {
    var displayDate: String? {
        guard let date = date else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let parsedDate = formatter.date(from: date) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: parsedDate)
        }
        
        return date
    }
    
    var isRecent: Bool {
        guard let lastUpdated = lastUpdated else { return false }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let parsedDate = formatter.date(from: lastUpdated) {
            return parsedDate.timeIntervalSinceNow > -30 * 24 * 60 * 60 // Within 30 days
        }
        
        return false
    }
}