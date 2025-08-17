import Foundation
import SwiftUI
import Combine
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

private let logger = Logger(subsystem: "com.epilogue", category: "FoundationModels")

// MARK: - Book Response Structure for Guided Generation
@Generable
struct AIBookResponse: Codable {
    let answer: String
    let confidence: Double
    let needsWebSearch: Bool
    let bookContext: String?
    let suggestedFollowUp: String?
}

// MARK: - Partial Response for Streaming
struct PartialAIBookResponse {
    var text: String = ""
    var confidence: Double = 0.0
    var isComplete: Bool = false
}

// MARK: - Model Errors
enum ModelError: LocalizedError {
    case notAvailable
    case modelNotReady
    case sessionExpired
    case tokenLimitExceeded
    case configurationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Foundation Models not available on this device"
        case .modelNotReady:
            return "Model is still loading, please wait"
        case .sessionExpired:
            return "Session expired, creating new session"
        case .tokenLimitExceeded:
            return "Token limit exceeded, chunking required"
        case .configurationFailed:
            return "Failed to configure Foundation Models"
        }
    }
}

// MARK: - AI Foundation Models Manager (Renamed to avoid conflict with iOS26FoundationModels.swift)
@MainActor
class AIFoundationModelsManager: ObservableObject {
    static let shared = AIFoundationModelsManager()
    
    #if canImport(FoundationModels)
    #if canImport(FoundationModels)
    private var model: SystemLanguageModel?
    #else
    private var model: Any?
    #endif
    private var sessions: [String: LanguageModelSession] = [:] // Book-specific sessions
    private var sessionTokenCounts: [String: Int] = [:]
    #endif
    
    @Published var isAvailable = false
    @Published var modelState: ModelState = .checking
    @Published var currentPartialResponse: PartialAIBookResponse?
    
    private let maxTokensPerSession = 4096
    private let sessionTimeout: TimeInterval = 3600 // 1 hour
    private var sessionTimestamps: [String: Date] = [:]
    
    enum ModelState {
        case checking
        case available
        case unavailable(reason: String)
        case modelNotReady
        case loading
    }
    
    private init() {
        Task {
            await initialize()
        }
    }
    
    // MARK: - Initialization
    
    func initialize() async {
        #if canImport(FoundationModels)
        logger.info("🚀 Initializing Foundation Models...")
        
        // Check availability with graceful fallbacks
        guard LanguageModel.isAvailable else {
            modelState = .unavailable(reason: "Foundation Models not available on this device")
            logger.warning("⚠️ Foundation Models not available")
            return
        }
        
        do {
            // Check model availability status
            let availability = try await LanguageModel.checkAvailability()
            
            switch availability {
            case .available:
                logger.info("✅ Foundation Models available")
                modelState = .loading
                try await setupModel()
                
            case .modelNotReady:
                logger.info("⏳ Model not ready, will retry...")
                modelState = .modelNotReady
                // Retry after delay
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    await initialize()
                }
                
            case .unavailable(let reason):
                logger.error("❌ Model unavailable: \(reason)")
                modelState = .unavailable(reason: reason)
                
            @unknown default:
                modelState = .unavailable(reason: "Unknown availability status")
            }
            
        } catch {
            logger.error("❌ Failed to initialize: \(error)")
            modelState = .unavailable(reason: error.localizedDescription)
        }
        #else
        logger.info("⚠️ Foundation Models not available in this build")
        modelState = .unavailable(reason: "Foundation Models not imported")
        #endif
    }
    
    #if canImport(FoundationModels)
    private func setupModel() async throws {
        // Configure for book reading use case
        let config = LanguageModelConfiguration(
            modelType: .onDevice3B,  // Use 3B model for quality
            temperature: 0.7,         // Balanced creativity
            maxTokens: maxTokensPerSession,
            topP: 0.9,
            streamingEnabled: true,
            useCache: true
        )
        
        // Initialize model
        model = try await LanguageModel(configuration: config)
        
        isAvailable = true
        modelState = .available
        logger.info("✅ Foundation Models ready")
    }
    #endif
    
    // MARK: - Session Management
    
    func getOrCreateSession(for bookTitle: String?) async throws -> Any? {
        #if canImport(FoundationModels)
        let sessionKey = bookTitle ?? "default"
        
        // Check if session exists and is still valid
        if let existingSession = sessions[sessionKey],
           let timestamp = sessionTimestamps[sessionKey],
           Date().timeIntervalSince(timestamp) < sessionTimeout {
            logger.info("♻️ Reusing session for: \(sessionKey)")
            return existingSession
        }
        
        // Create new session with book-specific instructions
        logger.info("🆕 Creating session for: \(sessionKey)")
        
        guard let model = model else {
            throw ModelError.notAvailable
        }
        
        let instructions = generateBookSpecificInstructions(bookTitle: bookTitle)
        
        let session = try await LanguageModelSession(
            model: model,
            instructions: instructions,
            options: GenerationOptions(
                temperature: 0.7,
                maxTokens: maxTokensPerSession,
                topP: 0.9
            )
        )
        
        // Enable guided generation for structured responses
        session.enableGuidedGeneration(BookResponse.self)
        
        // Register tool for web search when needed
        session.registerTool(PerplexitySearchTool())
        
        // Cache session
        sessions[sessionKey] = session
        sessionTimestamps[sessionKey] = Date()
        sessionTokenCounts[sessionKey] = 0
        
        return session
        #else
        return nil
        #endif
    }
    
    private func generateBookSpecificInstructions(bookTitle: String?) -> String {
        let baseInstructions = """
        You are an intelligent reading companion helping users understand and explore books.
        
        CRITICAL RULES:
        1. ALWAYS answer questions about book content factually and directly
        2. NEVER give spoiler warnings - users are actively reading these books
        3. Be specific and detailed when discussing plot, characters, and themes
        4. If you need current information (news, updates, reviews), indicate this clearly
        5. Provide thoughtful analysis and insights to enhance the reading experience
        """
        
        if let bookTitle = bookTitle {
            return """
            \(baseInstructions)
            
            Current book context: "\(bookTitle)"
            Focus your responses on this specific book and its content.
            Draw connections to themes, characters, and events within this work.
            """
        }
        
        return baseInstructions
    }
    
    // MARK: - Query Processing
    
    func processQuery(_ query: String, bookContext: Book?) async -> String {
        #if canImport(FoundationModels)
        guard modelState == .available else {
            logger.warning("⚠️ Model not available, falling back")
            return await fallbackToPerplexity(query, bookContext: bookContext)
        }
        
        do {
            let session = try await getOrCreateSession(for: bookContext?.title)
            guard let languageSession = session as? LanguageModelSession else {
                throw ModelError.configurationFailed
            }
            
            // Check token count
            let sessionKey = bookContext?.title ?? "default"
            let currentTokens = sessionTokenCounts[sessionKey] ?? 0
            
            if currentTokens > maxTokensPerSession - 500 { // Leave buffer
                logger.info("🔄 Token limit approaching, creating new session")
                sessions.removeValue(forKey: sessionKey)
                return await processQuery(query, bookContext: bookContext) // Retry with new session
            }
            
            // Generate response with guided generation
            let response = try await languageSession.generate(
                prompt: query,
                responseType: BookResponse.self
            )
            
            // Update token count
            sessionTokenCounts[sessionKey] = currentTokens + response.tokenCount
            
            // Check if web search is needed
            if response.needsWebSearch {
                logger.info("🌐 Web search needed, escalating to Perplexity")
                let webResponse = await fetchWebContext(query, bookContext: bookContext)
                return synthesizeResponses(local: response.answer, web: webResponse)
            }
            
            return response.answer
            
        } catch {
            logger.error("❌ Foundation Models error: \(error)")
            return await fallbackToPerplexity(query, bookContext: bookContext)
        }
        #else
        return await fallbackToPerplexity(query, bookContext: bookContext)
        #endif
    }
    
    // MARK: - Streaming Response
    
    func streamResponse(_ query: String, bookContext: Book?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            #if canImport(FoundationModels)
            Task {
                guard modelState == .available else {
                    // Fallback to non-streaming
                    let response = await fallbackToPerplexity(query, bookContext: bookContext)
                    continuation.yield(response)
                    continuation.finish()
                    return
                }
                
                do {
                    let session = try await getOrCreateSession(for: bookContext?.title)
                    guard let languageSession = session as? LanguageModelSession else {
                        throw ModelError.configurationFailed
                    }
                    
                    // Reset partial response
                    await MainActor.run {
                        currentPartialResponse = PartialAIBookResponse()
                    }
                    
                    // Stream with progressive updates
                    for try await partial in languageSession.streamGeneration(prompt: query) {
                        // Update partial response
                        await MainActor.run {
                            currentPartialResponse?.text = partial.text
                            currentPartialResponse?.confidence = partial.confidence ?? 0.0
                        }
                        
                        // Yield to stream
                        continuation.yield(partial.text)
                        
                        // Check if we need to escalate based on confidence
                        if let confidence = partial.confidence, confidence < 0.5 {
                            logger.info("⚠️ Low confidence (\(confidence)), may need web search")
                        }
                    }
                    
                    // Mark as complete
                    await MainActor.run {
                        currentPartialResponse?.isComplete = true
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            #else
            Task {
                let response = await fallbackToPerplexity(query, bookContext: bookContext)
                continuation.yield(response)
                continuation.finish()
            }
            #endif
        }
    }
    
    // MARK: - Confidence-Based Escalation
    
    func processWithConfidenceEscalation(_ query: String, bookContext: Book?) async -> String {
        #if canImport(FoundationModels)
        guard modelState == .available else {
            return await fallbackToPerplexity(query, bookContext: bookContext)
        }
        
        do {
            let session = try await getOrCreateSession(for: bookContext?.title)
            guard let languageSession = session as? LanguageModelSession else {
                throw ModelError.configurationFailed
            }
            
            // Generate with confidence tracking
            let response = try await languageSession.generate(
                prompt: query,
                responseType: BookResponse.self,
                options: GenerationOptions(
                    temperature: 0.7,
                    includeConfidence: true
                )
            )
            
            logger.info("📊 Response confidence: \(response.confidence)")
            
            // Escalate if confidence is low or web search is needed
            if response.confidence < 0.6 || response.needsWebSearch {
                logger.info("🔄 Escalating to Perplexity (confidence: \(response.confidence))")
                
                let webResponse = await fetchWebContext(query, bookContext: bookContext)
                return synthesizeResponses(
                    local: response.answer,
                    web: webResponse,
                    localConfidence: response.confidence
                )
            }
            
            return response.answer
            
        } catch {
            logger.error("❌ Confidence escalation failed: \(error)")
            return await fallbackToPerplexity(query, bookContext: bookContext)
        }
        #else
        return await fallbackToPerplexity(query, bookContext: bookContext)
        #endif
    }
    
    // MARK: - Helper Methods
    
    private func fallbackToPerplexity(_ query: String, bookContext: Book?) async -> String {
        logger.info("🔄 Falling back to Perplexity")
        
        do {
            let service = PerplexityService()
            return try await service.chat(with: query, bookContext: bookContext)
        } catch {
            logger.error("❌ Perplexity fallback failed: \(error)")
            return "I'm having trouble processing your question. Please try again."
        }
    }
    
    private func fetchWebContext(_ query: String, bookContext: Book?) async -> String? {
        do {
            let service = PerplexityService()
            return try await service.chat(with: query, bookContext: bookContext)
        } catch {
            logger.error("❌ Web context fetch failed: \(error)")
            return nil
        }
    }
    
    private func synthesizeResponses(local: String, web: String?, localConfidence: Double = 1.0) -> String {
        guard let webResponse = web else {
            return local
        }
        
        if localConfidence > 0.8 {
            // High confidence - local is primary
            return """
            \(local)
            
            Additional context: \(webResponse)
            """
        } else {
            // Low confidence - web is primary
            return """
            \(webResponse)
            
            Initial analysis: \(local)
            """
        }
    }
    
    // MARK: - Public Methods
    
    func checkAvailability() -> Bool {
        if case .available = modelState {
            return true
        }
        return false
    }
    
    func enhanceText(_ text: String) async -> String {
        #if canImport(FoundationModels)
        guard modelState == .available else { return text }
        
        do {
            let session = try await getOrCreateSession(for: nil)
            guard let languageSession = session as? LanguageModelSession else {
                return text
            }
            
            let enhanced = try await languageSession.enhance(
                text: text,
                task: .improve
            )
            
            return enhanced
        } catch {
            logger.error("❌ Text enhancement failed: \(error)")
            return text
        }
        #else
        return text
        #endif
    }
    
    func clearSessions() {
        #if canImport(FoundationModels)
        sessions.removeAll()
        sessionTimestamps.removeAll()
        sessionTokenCounts.removeAll()
        logger.info("🧹 Cleared all sessions")
        #endif
    }
}

// MARK: - Perplexity Search Tool for Foundation Models
#if canImport(FoundationModels)
struct PerplexitySearchTool: LanguageModelTool {
    let name = "web_search"
    let description = "Search the web for current information using Perplexity"
    
    func execute(parameters: [String: Any]) async throws -> String {
        guard let query = parameters["query"] as? String else {
            throw ToolError.invalidParameters
        }
        
        let service = PerplexityService()
        return try await service.chat(with: query, bookContext: nil)
    }
    
    enum ToolError: Error {
        case invalidParameters
    }
}
#endif

// MARK: - Extensions for Conditional Compilation
extension AIFoundationModelsManager {
    func smartQuery(_ query: String) async -> String {
        let book = AmbientBookDetector.shared.detectedBook
        return await processWithConfidenceEscalation(query, bookContext: book)
    }
    
    func quickCheck() -> Bool {
        return isAvailable
    }
}