import Foundation
import Combine
import OSLog

// MARK: - Request Manager with Queuing and Cost Controls

actor PerplexityRequestManager {
    static let shared = PerplexityRequestManager()
    
    private let client = PerplexitySonarClient.shared
    private let tokenCounter = TokenCounter()
    private let responseCache = ResponseCache()
    private let logger = Logger(subsystem: "com.epilogue.app", category: "PerplexityManager")
    
    // Queue Management
    private var requestQueue: [QueuedRequest] = []
    private var activeRequests: Set<UUID> = []
    private let maxConcurrentRequests = 3
    
    // Cost Management
    @Published private(set) var dailyTokensUsed: Int = 0
    @Published private(set) var dailyQueriesUsed: Int = 0
    private var dailyQuota: Int = 20
    private var isPro: Bool = false
    private var isGandalfEnabled: Bool = false
    
    // Retry Configuration
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    // Offline Queue
    private var offlineQueue: [OfflineRequest] = []
    
    init() {
        loadDailyUsage()
        setupDailyReset()
        loadOfflineQueue()
    }
    
    // MARK: - Configuration
    
    func configure(apiKey: String, isPro: Bool = false) async {
        await client.configure(apiKey: apiKey)
        self.isPro = isPro
        self.dailyQuota = isPro ? Int.max : 20
        logger.info("Configured: isPro=\(isPro), quota=\(self.dailyQuota)")
    }
    
    func enableGandalf(_ enabled: Bool) {
        self.isGandalfEnabled = enabled
        logger.info("Gandalf mode: \(enabled)")
    }
    
    // MARK: - Request Submission
    
    func submitRequest(
        messages: [ChatMessage],
        model: SonarModel? = nil,
        priority: RequestPriority = .normal,
        useCache: Bool = true
    ) async throws -> PerplexityResponse {
        // Check quota
        if !isGandalfEnabled && !isPro && dailyQueriesUsed >= dailyQuota {
            throw PerplexityError.quotaExceeded(used: dailyQueriesUsed, limit: dailyQuota)
        }
        
        // Check cache
        if useCache {
            let cacheKey = generateCacheKey(messages: messages, model: model)
            if let cached = await responseCache.get(key: cacheKey) {
                logger.debug("Cache hit for request")
                return cached
            }
        }
        
        // Determine model
        let selectedModel = model ?? (isPro ? .medium : .small)
        
        // Create queued request
        let request = QueuedRequest(
            id: UUID(),
            messages: messages,
            model: selectedModel,
            priority: priority,
            timestamp: Date()
        )
        
        // Add to queue with priority
        await enqueueRequest(request)
        
        // Process request
        return try await processRequest(request)
    }
    
    // MARK: - Streaming Request
    
    func streamRequest(
        messages: [ChatMessage],
        model: SonarModel? = nil,
        priority: RequestPriority = .high
    ) -> AsyncThrowingStream<StreamUpdate, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Check quota
                    if !isGandalfEnabled && !isPro && dailyQueriesUsed >= dailyQuota {
                        throw PerplexityError.quotaExceeded(used: dailyQueriesUsed, limit: dailyQuota)
                    }
                    
                    let selectedModel = model ?? (isPro ? .medium : .small)
                    let requestId = UUID()
                    
                    activeRequests.insert(requestId)
                    defer { activeRequests.remove(requestId) }
                    
                    // Count prompt tokens
                    let promptTokens = tokenCounter.countTokens(in: messages)
                    continuation.yield(.started(estimatedTokens: promptTokens))
                    
                    var totalContent = ""
                    var totalTokens = 0
                    var citations: [Citation] = []
                    
                    for try await response in client.streamChat(
                        model: selectedModel,
                        messages: messages,
                        maxTokens: min(selectedModel.maxTokens, 2000)
                    ) {
                        if let content = response.content {
                            totalContent += content
                            continuation.yield(.content(text: content, total: totalContent))
                        }
                        
                        if let newCitations = response.citations {
                            citations.append(contentsOf: newCitations)
                            continuation.yield(.citations(citations))
                        }
                        
                        if let usage = response.usage {
                            totalTokens = usage.totalTokens
                        }
                        
                        if response.isComplete {
                            await updateUsage(tokens: totalTokens, queries: 1)
                            
                            continuation.yield(.completed(
                                totalTokens: totalTokens,
                                cost: calculateCost(tokens: totalTokens, model: selectedModel)
                            ))
                            
                            // Cache response
                            let perplexityResponse = PerplexityResponse(
                                content: totalContent,
                                citations: citations,
                                tokenCount: totalTokens,
                                model: selectedModel,
                                cached: false
                            )
                            
                            let cacheKey = generateCacheKey(messages: messages, model: selectedModel)
                            await responseCache.set(key: cacheKey, value: perplexityResponse)
                            
                            continuation.finish()
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Queue Management
    
    private func enqueueRequest(_ request: QueuedRequest) async {
        requestQueue.append(request)
        requestQueue.sort { $0.priority.rawValue > $1.priority.rawValue }
        logger.debug("Enqueued request with priority \(request.priority)")
    }
    
    private func processRequest(_ request: QueuedRequest) async throws -> PerplexityResponse {
        // Wait for slot
        while activeRequests.count >= maxConcurrentRequests {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        activeRequests.insert(request.id)
        defer {
            activeRequests.remove(request.id)
            requestQueue.removeAll { $0.id == request.id }
        }
        
        return try await performRequestWithRetry(request)
    }
    
    private func performRequestWithRetry(_ request: QueuedRequest) async throws -> PerplexityResponse {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let response = try await client.chat(
                    model: request.model,
                    messages: request.messages,
                    maxTokens: min(request.model.maxTokens, 2000)
                )
                
                let perplexityResponse = PerplexityResponse(
                    content: response.choices.first?.message.content ?? "",
                    citations: response.citations ?? [],
                    tokenCount: response.usage?.totalTokens ?? 0,
                    model: request.model,
                    cached: false
                )
                
                // Update usage
                if !isGandalfEnabled {
                    await updateUsage(
                        tokens: response.usage?.totalTokens ?? 0,
                        queries: 1
                    )
                }
                
                // Cache response
                let cacheKey = generateCacheKey(messages: request.messages, model: request.model)
                await responseCache.set(key: cacheKey, value: perplexityResponse)
                
                return perplexityResponse
                
            } catch {
                lastError = error
                
                let delay = baseRetryDelay * pow(2.0, Double(attempt))
                logger.warning("Request failed (attempt \(attempt + 1)/\(maxRetries)): \(error)")
                
                if isNetworkError(error) && attempt == maxRetries - 1 {
                    await addToOfflineQueue(request)
                }
                
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? PerplexityError.unknownError
    }
    
    // MARK: - Offline Queue
    
    private func addToOfflineQueue(_ request: QueuedRequest) async {
        let offlineRequest = OfflineRequest(
            id: UUID(),
            messages: request.messages,
            model: request.model,
            timestamp: Date()
        )
        
        offlineQueue.append(offlineRequest)
        saveOfflineQueue()
        logger.info("Added to offline queue (total: \(offlineQueue.count))")
    }
    
    func processOfflineQueue() async {
        guard !offlineQueue.isEmpty else { return }
        logger.info("Processing \(offlineQueue.count) offline requests")
        
        for request in offlineQueue {
            do {
                _ = try await submitRequest(
                    messages: request.messages,
                    model: request.model,
                    priority: .low,
                    useCache: false
                )
                
                offlineQueue.removeAll { $0.id == request.id }
                saveOfflineQueue()
            } catch {
                logger.error("Failed to process offline request: \(error)")
                break
            }
        }
    }
    
    // MARK: - Cost Management
    
    private func updateUsage(tokens: Int, queries: Int) async {
        dailyTokensUsed += tokens
        dailyQueriesUsed += queries
        saveDailyUsage()
    }
    
    func calculateCost(tokens: Int, model: SonarModel) -> Double {
        Double(tokens) * model.costPerToken
    }
    
    func getRemainingQueries() -> Int {
        if isGandalfEnabled || isPro {
            return Int.max
        }
        return max(0, dailyQuota - dailyQueriesUsed)
    }
    
    func getDailyUsage() -> (tokens: Int, queries: Int, cost: Double) {
        let cost = Double(dailyTokensUsed) * 0.00002
        return (dailyTokensUsed, dailyQueriesUsed, cost)
    }
    
    // MARK: - Cache Management
    
    private func generateCacheKey(messages: [ChatMessage], model: SonarModel?) -> String {
        let messageContent = messages.map { "\($0.role.rawValue):\($0.content)" }.joined(separator: "|")
        let modelString = model?.rawValue ?? "default"
        return "\(modelString)-\(messageContent.hashValue)"
    }
    
    // MARK: - Persistence
    
    private func saveDailyUsage() {
        UserDefaults.standard.set(dailyTokensUsed, forKey: "perplexity_daily_tokens")
        UserDefaults.standard.set(dailyQueriesUsed, forKey: "perplexity_daily_queries")
        UserDefaults.standard.set(Date(), forKey: "perplexity_usage_date")
    }
    
    private func loadDailyUsage() {
        let lastDate = UserDefaults.standard.object(forKey: "perplexity_usage_date") as? Date ?? Date()
        
        if Calendar.current.isDateInToday(lastDate) {
            dailyTokensUsed = UserDefaults.standard.integer(forKey: "perplexity_daily_tokens")
            dailyQueriesUsed = UserDefaults.standard.integer(forKey: "perplexity_daily_queries")
        } else {
            resetDailyUsage()
        }
    }
    
    private func resetDailyUsage() {
        dailyTokensUsed = 0
        dailyQueriesUsed = 0
        saveDailyUsage()
    }
    
    private func setupDailyReset() {
        Task {
            while true {
                let now = Date()
                let tomorrow = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
                let timeUntilReset = tomorrow.timeIntervalSince(now)
                
                try await Task.sleep(nanoseconds: UInt64(timeUntilReset * 1_000_000_000))
                resetDailyUsage()
            }
        }
    }
    
    private func saveOfflineQueue() {
        if let data = try? JSONEncoder().encode(offlineQueue) {
            UserDefaults.standard.set(data, forKey: "perplexity_offline_queue")
        }
    }
    
    private func loadOfflineQueue() {
        if let data = UserDefaults.standard.data(forKey: "perplexity_offline_queue"),
           let queue = try? JSONDecoder().decode([OfflineRequest].self, from: data) {
            offlineQueue = queue
        }
    }
    
    private func isNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(urlError.code)
        }
        return false
    }
}

// MARK: - Supporting Types

struct QueuedRequest {
    let id: UUID
    let messages: [ChatMessage]
    let model: SonarModel
    let priority: RequestPriority
    let timestamp: Date
}

struct OfflineRequest: Codable {
    let id: UUID
    let messages: [StorableChatMessage]
    let model: String
    let timestamp: Date
    
    init(id: UUID, messages: [ChatMessage], model: SonarModel, timestamp: Date) {
        self.id = id
        self.messages = messages.map { StorableChatMessage(role: $0.role.rawValue, content: $0.content) }
        self.model = model.rawValue
        self.timestamp = timestamp
    }
}

struct StorableChatMessage: Codable {
    let role: String
    let content: String
}

enum RequestPriority: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
    
    static func < (lhs: RequestPriority, rhs: RequestPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct PerplexityResponse {
    let content: String
    let citations: [Citation]
    let tokenCount: Int
    let model: SonarModel
    var cached: Bool
}

enum StreamUpdate {
    case started(estimatedTokens: Int)
    case content(text: String, total: String)
    case citations([Citation])
    case completed(totalTokens: Int, cost: Double)
}

// MARK: - Response Cache

actor ResponseCache {
    private var cache: [String: CachedResponse] = [:]
    private let maxCacheSize = 100
    private let cacheExpiration: TimeInterval = 3600 // 1 hour
    
    func get(key: String) -> PerplexityResponse? {
        guard let cached = cache[key] else { return nil }
        
        if Date().timeIntervalSince(cached.timestamp) > cacheExpiration {
            cache.removeValue(forKey: key)
            return nil
        }
        
        var response = cached.response
        response.cached = true
        return response
    }
    
    func set(key: String, value: PerplexityResponse) {
        cache[key] = CachedResponse(response: value, timestamp: Date())
        
        if cache.count > maxCacheSize {
            let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            cache.removeValue(forKey: sorted.first!.key)
        }
    }
    
    func clear() {
        cache.removeAll()
    }
}

struct CachedResponse {
    let response: PerplexityResponse
    let timestamp: Date
}

// MARK: - Token Counter

class TokenCounter {
    func countTokens(in messages: [ChatMessage]) -> Int {
        let text = messages.map { $0.content }.joined(separator: " ")
        return estimateTokens(for: text)
    }
    
    func estimateTokens(for text: String) -> Int {
        let words = text.split(separator: " ").count
        let characters = text.count
        return (words + (characters / 4)) / 2
    }
}

// MARK: - Errors Extension

extension PerplexityError {
    static func quotaExceeded(used: Int, limit: Int) -> PerplexityError {
        .apiError(message: "Daily quota exceeded: \(used)/\(limit) queries used")
    }
    
    static var unknownError: PerplexityError {
        .apiError(message: "An unknown error occurred")
    }
}