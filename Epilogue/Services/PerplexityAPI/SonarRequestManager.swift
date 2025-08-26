import Foundation
import Combine
import OSLog

// MARK: - Request Manager with Queuing and Priority

actor SonarRequestManager {
    static let shared = SonarRequestManager()
    
    private let client = SonarAPIClient.shared
    private let tokenCounter = TokenCounter()
    private let logger = Logger(subsystem: "com.epilogue.app", category: "SonarRequestManager")
    
    // Queue Management
    private var requestQueue: [QueuedRequest] = []
    private var activeRequests: Set<UUID> = []
    private let maxConcurrentRequests = 3
    
    // Cost Management
    @Published private(set) var dailyTokensUsed: Int = 0
    @Published private(set) var dailyQueriesUsed: Int = 0
    private var dailyQuota: Int = 20
    private var isPro: Bool = false
    private var isGandalfEnabled: Bool = false // Testing override
    
    // Retry Configuration
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    // Cache
    private let responseCache = ResponseCache()
    
    // Offline Queue
    private var offlineQueue: [OfflineRequest] = []
    
    init() {
        loadDailyUsage()
        setupDailyReset()
    }
    
    // MARK: - Configuration
    
    func configure(apiKey: String, isPro: Bool = false) async {
        await client.setAPIKey(apiKey)
        self.isPro = isPro
        self.dailyQuota = isPro ? Int.max : 20
    }
    
    func enableGandalf(_ enabled: Bool) {
        self.isGandalfEnabled = enabled
        logger.info("Gandalf mode \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Request Submission
    
    func submitRequest(
        messages: [ChatMessage],
        model: SonarModel? = nil,
        priority: RequestPriority = .normal,
        useCache: Bool = true
    ) async throws -> ChatResponse {
        
        // Check quota (unless Gandalf is enabled)
        if !isGandalfEnabled && !isPro && dailyQueriesUsed >= dailyQuota {
            throw SonarError.quotaExceeded(used: dailyQueriesUsed, limit: dailyQuota)
        }
        
        // Check cache
        if useCache {
            let cacheKey = generateCacheKey(messages: messages, model: model)
            if let cached = await responseCache.get(key: cacheKey) {
                logger.debug("Cache hit for request")
                return cached
            }
        }
        
        // Determine model based on user tier
        let selectedModel = model ?? (isPro ? .sonarMedium : .sonarSmall)
        
        // Create queued request
        let request = QueuedRequest(
            id: UUID(),
            messages: messages,
            model: selectedModel,
            priority: priority,
            timestamp: Date()
        )
        
        // Add to queue
        await enqueueRequest(request)
        
        // Process queue
        return try await processRequest(request)
    }
    
    // MARK: - Streaming Request
    
    func streamRequest(
        messages: [ChatMessage],
        model: SonarModel? = nil,
        priority: RequestPriority = .high
    ) -> AsyncThrowingStream<StreamingUpdate, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Check quota (unless Gandalf is enabled)
                    if !isGandalfEnabled && !isPro && dailyQueriesUsed >= dailyQuota {
                        throw SonarError.quotaExceeded(used: dailyQueriesUsed, limit: dailyQuota)
                    }
                    
                    let selectedModel = model ?? (isPro ? .sonarMedium : .sonarSmall)
                    
                    // Track request
                    let requestId = UUID()
                    activeRequests.insert(requestId)
                    defer { activeRequests.remove(requestId) }
                    
                    // Count tokens in prompt
                    let promptTokens = tokenCounter.countTokens(in: messages)
                    
                    // Start streaming
                    var totalContent = ""
                    var totalTokens = 0
                    var citations: [Citation] = []
                    
                    continuation.yield(.started(estimatedTokens: promptTokens))
                    
                    for try await response in client.streamChatCompletion(
                        model: selectedModel,
                        messages: messages,
                        maxTokens: min(selectedModel.maxTokens, 2000)
                    ) {
                        if let content = response.content {
                            totalContent += content
                            
                            let update = StreamingUpdate.content(
                                text: content,
                                totalText: totalContent
                            )
                            continuation.yield(update)
                        }
                        
                        if let newCitations = response.citations {
                            citations.append(contentsOf: newCitations)
                            continuation.yield(.citations(citations))
                        }
                        
                        if let tokens = response.tokenCount {
                            totalTokens = tokens
                        }
                        
                        if response.isComplete {
                            // Update usage
                            if !isGandalfEnabled {
                                await updateUsage(tokens: totalTokens, queries: 1)
                            }
                            
                            continuation.yield(.completed(
                                totalTokens: totalTokens,
                                cost: calculateCost(tokens: totalTokens, model: selectedModel)
                            ))
                            
                            // Cache response
                            let chatResponse = ChatResponse(
                                content: totalContent,
                                citations: citations,
                                tokenCount: totalTokens,
                                model: selectedModel,
                                cached: false
                            )
                            
                            let cacheKey = generateCacheKey(messages: messages, model: selectedModel)
                            await responseCache.set(key: cacheKey, value: chatResponse)
                            
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
    }
    
    private func processRequest(_ request: QueuedRequest) async throws -> ChatResponse {
        // Wait for available slot
        while activeRequests.count >= maxConcurrentRequests {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        activeRequests.insert(request.id)
        defer { activeRequests.remove(request.id) }
        
        // Remove from queue
        requestQueue.removeAll { $0.id == request.id }
        
        // Perform request with retry
        return try await performRequestWithRetry(request)
    }
    
    private func performRequestWithRetry(_ request: QueuedRequest) async throws -> ChatResponse {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let response = try await client.chatCompletion(
                    model: request.model,
                    messages: request.messages,
                    maxTokens: min(request.model.maxTokens, 2000)
                )
                
                let chatResponse = ChatResponse(
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
                await responseCache.set(key: cacheKey, value: chatResponse)
                
                return chatResponse
                
            } catch {
                lastError = error
                
                // Calculate retry delay with exponential backoff
                let delay = baseRetryDelay * pow(2.0, Double(attempt))
                logger.warning("Request failed (attempt \(attempt + 1)/\(maxRetries)): \(error.localizedDescription)")
                
                // Add to offline queue if network error
                if isNetworkError(error) && attempt == maxRetries - 1 {
                    await addToOfflineQueue(request)
                }
                
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? SonarError.unknownError
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
        
        logger.info("Added request to offline queue (total: \(offlineQueue.count))")
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
                logger.error("Failed to process offline request: \(error.localizedDescription)")
                break // Stop processing if we hit an error
            }
        }
    }
    
    // MARK: - Token & Cost Management
    
    private func updateUsage(tokens: Int, queries: Int) async {
        dailyTokensUsed += tokens
        dailyQueriesUsed += queries
        saveDailyUsage()
    }
    
    func calculateCost(tokens: Int, model: SonarModel) -> Double {
        return Double(tokens) * model.costPerToken
    }
    
    func getRemainingQueries() -> Int {
        if isGandalfEnabled || isPro {
            return Int.max
        }
        return max(0, dailyQuota - dailyQueriesUsed)
    }
    
    func getDailyUsage() -> (tokens: Int, queries: Int, cost: Double) {
        let cost = Double(dailyTokensUsed) * 0.00002 // Average cost
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
        UserDefaults.standard.set(dailyTokensUsed, forKey: "sonar_daily_tokens")
        UserDefaults.standard.set(dailyQueriesUsed, forKey: "sonar_daily_queries")
        UserDefaults.standard.set(Date(), forKey: "sonar_usage_date")
    }
    
    private func loadDailyUsage() {
        let lastDate = UserDefaults.standard.object(forKey: "sonar_usage_date") as? Date ?? Date()
        
        if Calendar.current.isDateInToday(lastDate) {
            dailyTokensUsed = UserDefaults.standard.integer(forKey: "sonar_daily_tokens")
            dailyQueriesUsed = UserDefaults.standard.integer(forKey: "sonar_daily_queries")
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
            UserDefaults.standard.set(data, forKey: "sonar_offline_queue")
        }
    }
    
    private func loadOfflineQueue() {
        if let data = UserDefaults.standard.data(forKey: "sonar_offline_queue"),
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

struct ChatResponse {
    let content: String
    let citations: [Citation]
    let tokenCount: Int
    let model: SonarModel
    let cached: Bool
}

enum StreamingUpdate {
    case started(estimatedTokens: Int)
    case content(text: String, totalText: String)
    case citations([Citation])
    case completed(totalTokens: Int, cost: Double)
}

// MARK: - Response Cache

actor ResponseCache {
    private var cache: [String: CachedResponse] = [:]
    private let maxCacheSize = 100
    private let cacheExpiration: TimeInterval = 3600 // 1 hour
    
    func get(key: String) -> ChatResponse? {
        guard let cached = cache[key] else { return nil }
        
        if Date().timeIntervalSince(cached.timestamp) > cacheExpiration {
            cache.removeValue(forKey: key)
            return nil
        }
        
        var response = cached.response
        response.cached = true
        return response
    }
    
    func set(key: String, value: ChatResponse) {
        cache[key] = CachedResponse(response: value, timestamp: Date())
        
        // Trim cache if needed
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
    let response: ChatResponse
    let timestamp: Date
}

// MARK: - Token Counter

class TokenCounter {
    // Rough estimation: 1 token ≈ 4 characters
    // More sophisticated implementation would use tiktoken
    
    func countTokens(in messages: [ChatMessage]) -> Int {
        let text = messages.map { $0.content }.joined(separator: " ")
        return estimateTokens(for: text)
    }
    
    func estimateTokens(for text: String) -> Int {
        // Basic estimation
        let words = text.split(separator: " ").count
        let characters = text.count
        
        // Average between word count and character/4
        return (words + (characters / 4)) / 2
    }
}

// MARK: - Errors Extension

extension SonarError {
    static func quotaExceeded(used: Int, limit: Int) -> SonarError {
        .apiError(message: "Daily quota exceeded: \(used)/\(limit) queries used")
    }
    
    static var unknownError: SonarError {
        .apiError(message: "An unknown error occurred")
    }
}