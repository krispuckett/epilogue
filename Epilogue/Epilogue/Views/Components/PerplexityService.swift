import Foundation
import Combine

// MARK: - Perplexity Service (Using Secure Proxy)
class PerplexityService: ObservableObject {
    static let shared = PerplexityService()
    
    // Using proxy endpoint
    private let proxyURL = "https://epilogue-proxy.kris-puckett.workers.dev"
    private let appSecret = "epilogue_testflight_2025_secret"
    private let session: URLSession
    private var responseCache = [String: String]()  // Simple cache
    private var isGandalfEnabled = false
    private let secureManager = SecureAPIManager.shared
    
    init() {
        // Configure URLSession for optimal performance
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30  // Increased timeout for reliability
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil  // Disable caching for real-time responses
        self.session = URLSession(configuration: config)
        
        print("✅ Perplexity Service initialized with secure API management")
    }
    
    // MARK: - Gandalf Mode
    func enableGandalf(_ enabled: Bool) {
        isGandalfEnabled = enabled
        print("🧙‍♂️ Gandalf mode \(enabled ? "enabled" : "disabled") - quotas \(enabled ? "bypassed" : "enforced")")
    }
    
    // MARK: - Chat Methods
    static func staticChat(message: String, bookContext: Book? = nil) async throws -> String {
        let service = PerplexityService()
        return try await service.chat(with: message, bookContext: bookContext)
    }
    
    // Fast streaming chat for real-time responses (using proxy)
    func streamChat(message: String, bookContext: Book? = nil, model: String? = nil) async throws -> AsyncThrowingStream<String, Error> {
        // Check local rate limit for UX (proxy will enforce actual limit)
        let (remaining, _) = secureManager.getRemainingCalls()
        guard remaining > 0 || isGandalfEnabled else {
            throw PerplexityError.rateLimitExceeded(remaining: 0, resetTime: Date().addingTimeInterval(86400))
        }
        
        // Create detailed system prompt with book context for streaming
        let systemPrompt: String
        if let book = bookContext {
            systemPrompt = """
            You are discussing the specific book '\(book.title)' by \(book.author).
            IMPORTANT: When the user asks ANY question about characters, plot, themes, or story elements, assume they are asking about THIS SPECIFIC BOOK.
            - If asked "Who is [character name]?" - answer about that character IN \(book.title)
            - If asked about "the main character" - answer about \(book.title)'s main character
            - If asked about plot, ending, themes - answer about \(book.title) specifically
            
            PROVIDE DETAILED, COMPREHENSIVE ANSWERS:
            - Include context and examples from the book
            - Reference specific scenes or chapters when relevant
            - Connect answers to broader themes
            - Aim for responses that are at least 2-3 paragraphs for substantial questions
            - Be thorough but engaging - help the reader understand deeply
            """
        } else {
            systemPrompt = """
            Literary assistant providing detailed, comprehensive responses.
            Give thorough answers with context and examples.
            Aim for responses that are at least 2-3 paragraphs for substantial questions.
            """
        }
        let selectedModel = model ?? UserDefaults.standard.string(forKey: "perplexityModel") ?? "sonar"
        print("🤖 Using Perplexity model: \(selectedModel)")
        let requestBody: [String: Any] = [
            "model": selectedModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": message]
            ],
            "stream": true,  // Enable streaming
            "temperature": 0.7,
            "max_tokens": selectedModel == "sonar-pro" ? 2000 : 1000  // Increased for detailed responses
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Create proxy request instead of direct Perplexity request
        guard let proxyRequest = secureManager.createProxyRequest(body: bodyData) else {
            throw PerplexityError.invalidRequest
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await session.bytes(for: proxyRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: PerplexityError.invalidResponse)
                        return
                    }
                    
                    var hasRecordedCall = false
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: "),
                           let data = line.dropFirst(6).data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            continuation.yield(content)
                            
                            // Proxy handles rate limiting, no need to record locally
                            hasRecordedCall = true  // Mark as recorded for logic flow
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // Original non-streaming method
    func chat(with message: String, bookContext: Book? = nil, model: String? = nil) async throws -> String {
        // Check local rate limit for UX (proxy will enforce actual limit)
        let (remaining, _) = secureManager.getRemainingCalls()
        guard remaining > 0 || isGandalfEnabled else {
            throw PerplexityError.rateLimitExceeded(remaining: 0, resetTime: Date().addingTimeInterval(86400))
        }
        
        // Create detailed system prompt with book context
        let systemPrompt: String
        if let book = bookContext {
            systemPrompt = """
            You are discussing the specific book '\(book.title)' by \(book.author).
            IMPORTANT: When the user asks ANY question about characters, plot, themes, or story elements, assume they are asking about THIS SPECIFIC BOOK.
            - If asked "Who is [character name]?" - answer about that character IN \(book.title)
            - If asked about "the main character" - answer about \(book.title)'s main character
            - If asked about plot, ending, themes - answer about \(book.title) specifically
            
            PROVIDE DETAILED, COMPREHENSIVE ANSWERS:
            - Include context and examples from the book
            - Reference specific scenes or chapters when relevant
            - Connect answers to broader themes
            - Aim for responses that are at least 2-3 paragraphs for substantial questions
            - Be thorough but engaging - help the reader understand deeply
            - Use *italics* for book titles and **bold** for key concepts.
            """
        } else {
            systemPrompt = """
            Literary companion providing detailed, comprehensive responses.
            Give thorough answers with context and examples.
            Aim for responses that are at least 2-3 paragraphs for substantial questions.
            Use *italics* for book titles and **bold** for key concepts.
            """
        }
        
        // Build request body with selected model
        let selectedModel = model ?? UserDefaults.standard.string(forKey: "perplexityModel") ?? "sonar"
        print("🤖 Using Perplexity model: \(selectedModel)")
        let requestBody: [String: Any] = [
            "model": selectedModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": message]
            ],
            "temperature": 0.7,
            "max_tokens": selectedModel == "sonar-pro" ? 2000 : 1000  // Increased for detailed responses
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Use proxy instead of direct API call
        let responseData = try await secureManager.callProxyAPI(body: bodyData)
        
        // Parse response from proxy
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw PerplexityError.invalidResponse
        }
        
        // Proxy handles rate limiting, no need to record locally
        
        return content
    }
}

// MARK: - Errors
enum PerplexityError: LocalizedError {
    case invalidURL
    case invalidRequest
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    case rateLimitExceeded(remaining: Int, resetTime: Date?)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidRequest:
            return "Invalid request format"
        case .invalidResponse:
            return "Invalid response from API"
        case .unauthorized:
            return "Invalid API key - please check your configuration"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .rateLimitExceeded(let remaining, let resetTime):
            if let resetTime = resetTime {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "Daily question limit reached. Resets at \(formatter.string(from: resetTime))"
            }
            return "Daily question limit reached"
        }
    }
}
