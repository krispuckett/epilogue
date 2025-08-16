import Foundation
import Combine

// MARK: - Perplexity Service
class PerplexityService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.perplexity.ai/chat/completions"
    private let session: URLSession
    private var responseCache = [String: String]()  // Simple cache
    
    init() {
        // Configure URLSession for optimal performance
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15  // Faster timeout
        config.timeoutIntervalForResource = 15
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil  // Disable caching for real-time responses
        self.session = URLSession(configuration: config)
        
        // First try KeychainManager, then Info.plist
        let apiKey = KeychainManager.shared.getPerplexityAPIKey() ?? 
                     Bundle.main.object(forInfoDictionaryKey: "PERPLEXITY_API_KEY") as? String
        
        if let apiKey = apiKey,
           !apiKey.isEmpty,
           apiKey != "your_actual_api_key_here",
           !apiKey.contains("$(") {
            self.apiKey = apiKey
            let source = KeychainManager.shared.hasPerplexityAPIKey ? "Settings (Keychain)" : "Info.plist"
            print("✅ Perplexity Service initialized with API key from \(source)")
        } else {
            // Fallback: Use a placeholder key to prevent crashes
            // IMPORTANT: Replace this with your actual API key
            self.apiKey = "PLACEHOLDER_API_KEY"
            print("⚠️ WARNING: Using placeholder API key. Chat functionality will not work!")
            print("⚠️ To fix: Add PERPLEXITY_API_KEY to your Info.plist file")
        }
    }
    
    // MARK: - Chat Methods
    static func staticChat(message: String, bookContext: Book? = nil) async throws -> String {
        let service = PerplexityService()
        return try await service.chat(with: message, bookContext: bookContext)
    }
    
    // Fast streaming chat for real-time responses
    func streamChat(message: String, bookContext: Book? = nil, model: String? = nil) async throws -> AsyncThrowingStream<String, Error> {
        // Check if we have a valid API key
        if apiKey == "PLACEHOLDER_API_KEY" {
            print("Cannot make API request with placeholder key")
            return AsyncThrowingStream { continuation in
                continuation.yield("Chat is currently unavailable. Please configure your Perplexity API key in Info.plist.")
                continuation.finish()
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
            Brief, insightful responses.
            """
        } else {
            systemPrompt = "Literary assistant. Brief, insightful responses."
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
            "max_tokens": selectedModel == "sonar-pro" ? 1000 : 500
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
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: "),
                           let data = line.dropFirst(6).data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            continuation.yield(content)
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
        // Check if we have a valid API key
        if apiKey == "PLACEHOLDER_API_KEY" {
            print("Cannot make API request with placeholder key")
            return "Chat is currently unavailable. Please configure your Perplexity API key in Info.plist."
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
            Be concise and insightful. Use *italics* for book titles and **bold** for key concepts.
            """
        } else {
            systemPrompt = "Literary companion. Be concise and insightful about books. Use *italics* for book titles and **bold** for key concepts."
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
            "max_tokens": selectedModel == "sonar-pro" ? 1000 : 500  // Increased for complete responses
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
        
        return content
    }
}

// MARK: - Errors
enum PerplexityError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int)
    
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
        }
    }
}
