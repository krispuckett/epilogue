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
        
        // First try to load from Info.plist
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "PERPLEXITY_API_KEY") as? String,
           !apiKey.isEmpty,
           apiKey != "your_actual_api_key_here",
           !apiKey.contains("$(") {
            self.apiKey = apiKey
            print("✅ Perplexity Service initialized with API key from Info.plist")
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
    func streamChat(message: String, bookContext: Book? = nil) async throws -> AsyncThrowingStream<String, Error> {
        // Check if we have a valid API key
        if apiKey == "PLACEHOLDER_API_KEY" {
            print("Cannot make API request with placeholder key")
            return AsyncThrowingStream { continuation in
                continuation.yield("Chat is currently unavailable. Please configure your Perplexity API key in Info.plist.")
                continuation.finish()
            }
        }
        
        guard let url = URL(string: baseURL) else {
            throw PerplexityError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Optimized for streaming
        let systemPrompt = "Literary assistant. Brief, insightful responses."
        let requestBody: [String: Any] = [
            "model": "sonar",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": message]
            ],
            "stream": true,  // Enable streaming
            "temperature": 0.7,
            "max_tokens": 150
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
    func chat(with message: String, bookContext: Book? = nil) async throws -> String {
        // Check if we have a valid API key
        if apiKey == "PLACEHOLDER_API_KEY" {
            print("Cannot make API request with placeholder key")
            return "Chat is currently unavailable. Please configure your Perplexity API key in Info.plist."
        }
        
        guard let url = URL(string: baseURL) else {
            throw PerplexityError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create concise system prompt for faster responses
        let systemPrompt = bookContext != nil ? 
            "Literary companion discussing '\(bookContext!.title)'. Be concise and insightful. Use *italics* for book titles and **bold** for key concepts." :
            "Literary companion. Be concise and insightful about books. Use *italics* for book titles and **bold** for key concepts."
        
        // Build request body with faster model
        let requestBody: [String: Any] = [
            "model": "sonar",  // Faster model, still high quality
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": message]
            ],
            "temperature": 0.7,
            "max_tokens": 150  // Limit response length for speed
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
