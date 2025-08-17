import Foundation
import SwiftUI
import OSLog
#if canImport(FoundationModels)
import FoundationModels
#endif

private let logger = Logger(subsystem: "com.epilogue", category: "AmbientAI")

/// Orchestrates AI responses with iOS 26 Foundation Models and Perplexity Sonar
/// Provides instant local responses enhanced by cloud AI
actor AmbientAIOrchestrator {
    // MARK: - Properties
    // Note: responseCache access happens through MainActor.run
    private let localAI = LocalAIService()
    private let cloudAI = PerplexitySonarService()
    
    // Response strategy configuration
    private let localResponseTimeout: TimeInterval = 0.5  // 500ms for instant feel
    private let cloudResponseTimeout: TimeInterval = 3.0  // 3s for enhanced response
    
    // Active tasks for deduplication
    private var activeTasks: [String: Task<String?, Never>] = [:]
    
    // MARK: - Public Methods
    
    /// Get AI response with instant local + enhanced cloud strategy
    public func getResponse(for question: String, bookContext: Book? = nil) async -> (instant: String?, enhanced: String?) {
        let cacheKey = "\(question)_\(bookContext?.title ?? "")"
        
        // 1. Check cache first (0ms)
        let cached = await MainActor.run {
            AmbientResponseCache.shared.getCachedResponse(for: question, bookContext: bookContext?.title)
        }
        if let cached = cached {
            logger.info("💨 Cache hit - returning instantly")
            return (instant: cached, enhanced: nil)
        }
        
        // 2. Check if already processing
        if let existingTask = activeTasks[cacheKey] {
            logger.info("⏳ Already processing - waiting for result")
            let result = await existingTask.value
            return (instant: result, enhanced: nil)
        }
        
        // 3. Start parallel processing
        let task = Task<String?, Never> {
            await self.processQuestion(question, bookContext: bookContext)
        }
        activeTasks[cacheKey] = task
        
        // 4. Get local response quickly
        let localResponse = await withTaskGroup(of: String?.self) { group in
            group.addTask {
                await self.getLocalResponse(question, bookContext: bookContext)
            }
            
            // Wait up to 500ms for local response
            if let result = await group.next() {
                return result
            }
            return nil
        }
        
        // 5. Get enhanced cloud response
        let enhancedResponse = await task.value
        
        // Clean up
        activeTasks.removeValue(forKey: cacheKey)
        
        return (instant: localResponse, enhanced: enhancedResponse)
    }
    
    /// Process question with both local and cloud AI
    private func processQuestion(_ question: String, bookContext: Book?) async -> String? {
        async let localTask = getLocalResponse(question, bookContext: bookContext)
        async let cloudTask = getCloudResponse(question, bookContext: bookContext)
        
        // Get both responses
        let (localResponse, cloudResponse) = await (localTask, cloudTask)
        
        // Prefer cloud response if available, fallback to local
        let finalResponse = cloudResponse ?? localResponse
        
        // Cache the result
        if let response = finalResponse {
            await MainActor.run {
                AmbientResponseCache.shared.cacheResponse(
                    response,
                    for: question,
                    bookContext: bookContext?.title,
                    source: cloudResponse != nil ? .cloud : .local
                )
            }
        }
        
        return finalResponse
    }
    
    /// Get instant response from iOS 26 Foundation Models
    private func getLocalResponse(_ question: String, bookContext: Book?) async -> String? {
        let startTime = Date()
        
        do {
            let response = try await localAI.generateResponse(
                for: question,
                context: bookContext,
                timeout: localResponseTimeout
            )
            
            let elapsed = Date().timeIntervalSince(startTime)
            logger.info("⚡ Local AI response in \(String(format: "%.2f", elapsed))s")
            
            return response
        } catch {
            logger.info("⚠️ Local AI not available, will use cloud AI: \(error)")
            return nil
        }
    }
    
    /// Get enhanced response from Perplexity Sonar
    private func getCloudResponse(_ question: String, bookContext: Book?) async -> String? {
        let startTime = Date()
        
        do {
            let response = try await cloudAI.generateEnhancedResponse(
                for: question,
                bookContext: bookContext,
                timeout: cloudResponseTimeout
            )
            
            let elapsed = Date().timeIntervalSince(startTime)
            logger.info("☁️ Cloud AI response in \(String(format: "%.2f", elapsed))s")
            
            return response
        } catch {
            logger.error("❌ Cloud AI failed: \(error)")
            // Return a helpful fallback message
            return "I'm processing your question about \(bookContext?.title ?? "your reading"). Please ensure your Perplexity API key is configured in Settings."
        }
    }
}

// MARK: - Local AI Service (iOS 26 Foundation Models)
@globalActor actor LocalAIActor {
    static let shared = LocalAIActor()
}

final class LocalAIService {
    #if canImport(FoundationModels)
    private var languageModel: SystemLanguageModel?
    private var modelSession: LanguageModelSession?
    private let sessionSemaphore = DispatchSemaphore(value: 1)  // Prevent concurrent requests
    private var isProcessing = false
    #endif
    
    init() {
        setupFoundationModels()
    }
    
    private func setupFoundationModels() {
        #if canImport(FoundationModels)
        Task {
            // Initialize iOS 26 Foundation Models
            self.languageModel = SystemLanguageModel.default
            self.modelSession = LanguageModelSession(
                instructions: """
                You are a helpful AI assistant discussing literature and books.
                ALWAYS answer questions about books factually and helpfully.
                Do NOT refuse to answer questions about book content.
                The user is reading these books and wants to discuss them.
                Be direct, factual, and helpful with all answers.
                """
            )
            logger.info("✅ iOS 26 Foundation Models initialized")
        }
        #else
        logger.info("⚠️ Foundation Models not available, will use cloud AI only")
        #endif
    }
    
    func generateResponse(for question: String, context: Book?, timeout: TimeInterval) async throws -> String? {
        #if canImport(FoundationModels)
        guard let session = modelSession else {
            throw AIError.modelNotAvailable
        }
        
        // Prevent concurrent requests to the same session
        guard sessionSemaphore.wait(timeout: .now() + timeout) == .success else {
            throw AIError.timeout
        }
        defer { sessionSemaphore.signal() }
        
        // Build contextual prompt
        var prompt = question
        if let book = context {
            prompt = "Context: Reading '\(book.title)' by \(book.author ?? "Unknown"). Question: \(question)"
        }
        
        // Generate with timeout
        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            logger.error("⚠️ Foundation Models error: \(error)")
            throw error
        }
        #else
        // When Foundation Models not available, return nil to let cloud AI handle it
        throw AIError.modelNotAvailable
        #endif
    }
    
    enum AIError: Error {
        case modelNotAvailable
        case timeout
    }
}

// MARK: - Perplexity Sonar Service
final class PerplexitySonarService {
    private let apiKey: String?
    private let session = URLSession.shared
    private let sonarEndpoint = "https://api.perplexity.ai/chat/completions"
    
    init() {
        // Load API key from Keychain or Info.plist
        let key = KeychainManager.shared.getPerplexityAPIKey() ??
                  Bundle.main.object(forInfoDictionaryKey: "PERPLEXITY_API_KEY") as? String
        
        // Validate the key isn't a placeholder
        if let key = key,
           !key.isEmpty,
           key != "your_actual_api_key_here",
           !key.contains("$("),
           key != "PLACEHOLDER_API_KEY" {
            self.apiKey = key
            logger.info("🔑 Perplexity API key loaded successfully")
        } else {
            self.apiKey = nil
            logger.warning("⚠️ No valid Perplexity API key found")
        }
    }
    
    func generateEnhancedResponse(for question: String, bookContext: Book?, timeout: TimeInterval) async throws -> String? {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            logger.info("⚠️ Perplexity API key not configured")
            return nil
        }
        
        // Build Sonar request with book context
        var messages: [[String: String]] = []
        
        // System message optimized for literature
        messages.append([
            "role": "system",
            "content": "You are an expert literary companion with deep knowledge of literature, themes, symbolism, and narrative techniques. Provide insightful, thoughtful responses that enhance the reader's understanding and appreciation of their book. Be concise but profound."
        ])
        
        // Add book context if available
        if let book = bookContext {
            messages.append([
                "role": "user",
                "content": "I'm currently reading '\(book.title)' by \(book.author ?? "Unknown Author")."
            ])
        }
        
        // Add the actual question
        messages.append([
            "role": "user",
            "content": question
        ])
        
        // Create request
        let requestBody: [String: Any] = [
            "model": "sonar-pro",  // Latest Perplexity model
            "messages": messages,
            "temperature": 0.7,
            "top_p": 0.9,
            "max_tokens": 1000,
            "stream": false,
            "return_citations": true,  // Include sources
            "search_domain_filter": ["academic", "books", "literature"]  // Focus on quality sources
        ]
        
        guard let url = URL(string: sonarEndpoint) else {
            throw SonarError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = timeout
        
        // Make request
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SonarError.requestFailed
        }
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw SonarError.invalidResponse
        }
        
        return content
    }
    
    enum SonarError: Error {
        case invalidURL
        case requestFailed
        case invalidResponse
    }
}