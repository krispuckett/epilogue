import Foundation
import Combine

// MARK: - Perplexity Service
class PerplexityService: ObservableObject {
    static let shared = PerplexityService()
    
    private var apiKey: String {
        // Use secure API manager for production
        SecureAPIManager.shared.getAPIKey()
    }
    private let baseURL = "https://api.perplexity.ai/chat/completions"
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
    
    // Fast streaming chat for real-time responses
    func streamChat(message: String, bookContext: Book? = nil, model: String? = nil) async throws -> AsyncThrowingStream<String, Error> {
        // Check rate limit first (unless unlimited)
        if !secureManager.hasUnlimitedQuestions {
            let (allowed, remaining, resetTime) = secureManager.canMakeAPICall()
            
            guard allowed else {
                throw PerplexityError.rateLimitExceeded(remaining: remaining, resetTime: resetTime)
            }
        }
        
        guard let url = URL(string: baseURL),
              URLValidator.isValidAPIURL(url) else {
            throw PerplexityError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
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
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    
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
                            
                            // Record API call on first successful content
                            if !hasRecordedCall && !secureManager.hasUnlimitedQuestions {
                                secureManager.recordAPICall()
                                hasRecordedCall = true
                            }
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
        // Check rate limit first (unless unlimited)
        if !secureManager.hasUnlimitedQuestions {
            let (allowed, remaining, resetTime) = secureManager.canMakeAPICall()
            
            guard allowed else {
                throw PerplexityError.rateLimitExceeded(remaining: remaining, resetTime: resetTime)
            }
        }
        
        guard let url = URL(string: baseURL),
              URLValidator.isValidAPIURL(url) else {
            throw PerplexityError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
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
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make request with configured session
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PerplexityError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw PerplexityError.unauthorized
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PerplexityError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw PerplexityError.invalidResponse
        }
        
        // Record successful API call for rate limiting
        if !secureManager.hasUnlimitedQuestions {
            secureManager.recordAPICall()
        }
        
        return content
    }
}

// MARK: - Errors
enum PerplexityError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    case rateLimitExceeded(remaining: Int, resetTime: Date?)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
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
