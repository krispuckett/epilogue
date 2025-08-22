import Foundation
import Combine
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "OptimizedAIResponse")

// MARK: - AI Response Models

struct AIResponse {
    let id: UUID = UUID()
    let question: String
    let answer: String
    let confidence: Float
    let timestamp: Date
    let bookContext: Book?
    let model: AIModel
    let responseTime: TimeInterval
    let isStreaming: Bool
    
    enum AIModel: String, CaseIterable {
        case sonar = "sonar"
        case sonarPro = "sonar-pro"
        
        var displayName: String {
            switch self {
            case .sonar:
                return "Sonar (Fast)"
            case .sonarPro:
                return "Sonar Pro (Detailed)"
            }
        }
        
        var maxTokens: Int {
            switch self {
            case .sonar:
                return 100  // Ultra-fast responses
            case .sonarPro:
                return 250  // More detailed but still quick
            }
        }
        
        var isOptimalForRealTime: Bool {
            switch self {
            case .sonar:
                return true
            case .sonarPro:
                return false
            }
        }
    }
}

struct StreamingResponse {
    let id: UUID
    let question: String
    var accumulatedText: String = ""
    var isComplete: Bool = false
    let timestamp: Date
    let bookContext: Book?
    let model: AIResponse.AIModel
}

// MARK: - Optimized AI Response Service

@MainActor
class OptimizedAIResponseService: ObservableObject {
    static let shared = OptimizedAIResponseService()
    
    @Published var activeStreams: [UUID: StreamingResponse] = [:]
    @Published var recentResponses: [AIResponse] = []
    @Published var isProcessing = false
    
    private let perplexityService = PerplexityService()
    private let responseCache = ResponseCache.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Performance tracking
    private var responseTimes: [TimeInterval] = []
    private let maxHistorySize = 100
    
    init() {
        setupNotificationObservers()
    }
    
    // MARK: - Public Methods
    
    /// Process immediate question with streaming response - FIXED to return response directly
    func processImmediateQuestion(_ question: String, bookContext: Book? = nil) async -> AIResponse? {
        let startTime = Date()
        
        // Check cache first for instant response
        if let cachedResponse = await responseCache.getResponse(for: question, bookTitle: bookContext?.title) {
            logger.info("📦 Instant cached response for: \(question)")
            
            let aiResponse = AIResponse(
                question: question,
                answer: cachedResponse,
                confidence: 1.0,
                timestamp: Date(),
                bookContext: bookContext,
                model: .sonar,
                responseTime: Date().timeIntervalSince(startTime),
                isStreaming: false
            )
            
            addToHistory(aiResponse)
            
            // Post immediate response (for backward compatibility)
            NotificationCenter.default.post(
                name: Notification.Name("AIResponseReady"),
                object: aiResponse
            )
            return aiResponse
        }
        
        // Determine optimal model based on question complexity
        let model = selectOptimalModel(for: question)
        logger.info("🤖 Selected model: \(model.displayName) for question: \(question)")
        
        // Create streaming response
        let streamId = UUID()
        let streamingResponse = StreamingResponse(
            id: streamId,
            question: question,
            timestamp: Date(),
            bookContext: bookContext,
            model: model
        )
        
        activeStreams[streamId] = streamingResponse
        
        do {
            // Start streaming response
            let stream = try await perplexityService.streamChat(
                message: question,
                bookContext: bookContext,
                model: model.rawValue
            )
            
            var accumulatedText = ""
            
            for try await chunk in stream {
                accumulatedText += chunk
                
                // Update streaming response
                activeStreams[streamId]?.accumulatedText = accumulatedText
                
                // Post partial response for immediate UI update
                NotificationCenter.default.post(
                    name: Notification.Name("AIStreamingUpdate"),
                    object: [
                        "streamId": streamId,
                        "text": accumulatedText,
                        "isComplete": false
                    ]
                )
            }
            
            // Complete the stream
            activeStreams[streamId]?.isComplete = true
            activeStreams[streamId]?.accumulatedText = accumulatedText
            
            let responseTime = Date().timeIntervalSince(startTime)
            recordResponseTime(responseTime)
            
            // Create final AI response
            let aiResponse = AIResponse(
                question: question,
                answer: accumulatedText,
                confidence: 0.9,
                timestamp: Date(),
                bookContext: bookContext,
                model: model,
                responseTime: responseTime,
                isStreaming: true
            )
            
            addToHistory(aiResponse)
            
            // Cache the response with enhanced metadata
            await responseCache.cacheResponse(
                accumulatedText, 
                for: question, 
                bookTitle: bookContext?.title,
                confidence: 0.9,
                model: model.rawValue
            )
            
            // Post final response
            NotificationCenter.default.post(
                name: Notification.Name("AIResponseComplete"),
                object: aiResponse
            )
            
            // Clean up stream
            activeStreams.removeValue(forKey: streamId)
            
            logger.info("✅ Streaming response completed in \(String(format: "%.2f", responseTime))s")
            
            return aiResponse
        } catch {
            logger.error("❌ Streaming response failed: \(error)")
            
            // Fallback to cached or error response
            let errorResponse = AIResponse(
                question: question,
                answer: "I'm having trouble responding right now. Please try asking again.",
                confidence: 0.1,
                timestamp: Date(),
                bookContext: bookContext,
                model: model,
                responseTime: Date().timeIntervalSince(startTime),
                isStreaming: false
            )
            
            addToHistory(errorResponse)
            
            NotificationCenter.default.post(
                name: Notification.Name("AIResponseError"),
                object: errorResponse
            )
            
            activeStreams.removeValue(forKey: streamId)
            return errorResponse
        }
    }
    
    /// Batch process multiple questions (for end-of-session processing)
    func batchProcessQuestions(_ questions: [String], bookContext: Book? = nil) async {
        logger.info("🔄 Batch processing \(questions.count) questions")
        
        for question in questions {
            // Use fast model for batch processing
            await processQuestion(question, bookContext: bookContext, model: .sonar)
            
            // Small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }
    
    /// Process single question with specified model
    private func processQuestion(_ question: String, bookContext: Book? = nil, model: AIResponse.AIModel) async {
        let startTime = Date()
        
        // Check cache first
        if let cachedResponse = await responseCache.getResponse(for: question, bookTitle: bookContext?.title) {
            let aiResponse = AIResponse(
                question: question,
                answer: cachedResponse,
                confidence: 1.0,
                timestamp: Date(),
                bookContext: bookContext,
                model: model,
                responseTime: Date().timeIntervalSince(startTime),
                isStreaming: false
            )
            addToHistory(aiResponse)
            return
        }
        
        do {
            let response = try await perplexityService.chat(
                with: question,
                bookContext: bookContext,
                model: model.rawValue
            )
            
            let responseTime = Date().timeIntervalSince(startTime)
            recordResponseTime(responseTime)
            
            let aiResponse = AIResponse(
                question: question,
                answer: response,
                confidence: 0.85,
                timestamp: Date(),
                bookContext: bookContext,
                model: model,
                responseTime: responseTime,
                isStreaming: false
            )
            
            addToHistory(aiResponse)
            await responseCache.cacheResponse(
                response, 
                for: question, 
                bookTitle: bookContext?.title,
                confidence: 0.85,
                model: model.rawValue
            )
            
        } catch {
            logger.error("Failed to process question: \(error)")
        }
    }
    
    // MARK: - Model Selection
    
    private func selectOptimalModel(for question: String) -> AIResponse.AIModel {
        let questionLower = question.lowercased()
        
        // Use fast model for simple questions
        let simplePatterns = [
            "what is", "who is", "when did", "where is",
            "yes or no", "true or false", "define",
            "how do you spell"
        ]
        
        for pattern in simplePatterns {
            if questionLower.contains(pattern) {
                return .sonar
            }
        }
        
        // Use detailed model for complex analysis
        let complexPatterns = [
            "analyze", "explain why", "compare", "contrast",
            "what do you think", "interpret", "significance",
            "symbolism", "meaning behind", "deeper"
        ]
        
        for pattern in complexPatterns {
            if questionLower.contains(pattern) {
                return .sonarPro
            }
        }
        
        // Default to fast model for real-time responses
        return .sonar
    }
    
    // MARK: - History Management
    
    private func addToHistory(_ response: AIResponse) {
        recentResponses.append(response)
        
        // Maintain history size
        if recentResponses.count > maxHistorySize {
            recentResponses.removeFirst()
        }
    }
    
    private func recordResponseTime(_ time: TimeInterval) {
        responseTimes.append(time)
        
        if responseTimes.count > 50 {
            responseTimes.removeFirst()
        }
        
        let avgResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        logger.info("📊 Avg response time: \(String(format: "%.2f", avgResponseTime))s")
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Listen for immediate questions from voice recognition
        NotificationCenter.default.publisher(for: Notification.Name("ImmediateQuestionDetected"))
            .compactMap { $0.object as? [String: Any] }
            .sink { [weak self] data in
                guard let self = self,
                      let question = data["question"] as? String else { return }
                
                let bookContext = data["bookContext"] as? Book
                
                Task {
                    await self.processImmediateQuestion(question, bookContext: bookContext)
                }
            }
            .store(in: &cancellables)
        
        // Listen for batch processing requests
        NotificationCenter.default.publisher(for: Notification.Name("BatchProcessQuestions"))
            .compactMap { $0.object as? [String: Any] }
            .sink { [weak self] data in
                guard let self = self,
                      let questions = data["questions"] as? [String] else { return }
                
                let bookContext = data["bookContext"] as? Book
                
                Task {
                    await self.batchProcessQuestions(questions, bookContext: bookContext)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Performance Metrics
    
    func getPerformanceMetrics() -> [String: Any] {
        let avgResponseTime = responseTimes.isEmpty ? 0.0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
        let cacheHitRate = Double(recentResponses.filter { !$0.isStreaming }.count) / Double(max(recentResponses.count, 1))
        
        return [
            "avgResponseTime": avgResponseTime,
            "totalResponses": recentResponses.count,
            "activeStreams": activeStreams.count,
            "cacheHitRate": cacheHitRate,
            "fastModelUsage": recentResponses.filter { $0.model == .sonar }.count,
            "detailedModelUsage": recentResponses.filter { $0.model == .sonarPro }.count
        ]
    }
    
    // MARK: - Cache Management
    
    func preloadCommonQuestions(for book: Book) {
        let commonQuestions = [
            "What is this book about?",
            "Who wrote this book?",
            "What genre is this book?",
            "When was this book published?",
            "What are the main themes?",
            "Who are the main characters?",
            "What is the setting?",
            "What happens in this chapter?"
        ]
        
        Task {
            for question in commonQuestions {
                // Only preload if not already cached
                if await responseCache.getResponse(for: question, bookTitle: book.title) == nil {
                    await processQuestion(question, bookContext: book, model: .sonar)
                }
            }
        }
    }
    
    func clearHistory() {
        recentResponses.removeAll()
        responseTimes.removeAll()
        activeStreams.removeAll()
        Task {
            await responseCache.clearCache()
        }
    }
}