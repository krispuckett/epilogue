import Foundation

// MARK: - Perplexity Service
class PerplexityService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.perplexity.ai/chat/completions"
    
    init() {
        // Load API key from Info.plist
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "PERPLEXITY_API_KEY") as? String,
              !apiKey.isEmpty,
              apiKey != "your_actual_api_key_here",
              !apiKey.contains("$(") else {
            fatalError("""
                ⚠️ Perplexity API key not found or invalid!
                
                Please ensure:
                1. Config.xcconfig contains your actual API key
                2. Your project is configured to use Config.xcconfig
                3. Clean build folder and rebuild
                """)
        }
        
        self.apiKey = apiKey
        print("✅ Perplexity Service initialized")
    }
    
    // MARK: - Simple Chat Method
    static func staticChat(message: String, bookContext: Book? = nil) async throws -> String {
        let service = PerplexityService()
        return try await service.chat(with: message, bookContext: bookContext)
    }
    
    func chat(with message: String, bookContext: Book? = nil) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw PerplexityError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create system prompt
        let systemPrompt = bookContext != nil ? 
            "You are a thoughtful literary companion discussing '\(bookContext!.title)' by \(bookContext!.author). Be warm, insightful, and engaging." :
            "You are a thoughtful literary companion. Be warm, insightful, and engaging in discussing books and literature."
        
        // Build request body
        let requestBody: [String: Any] = [
            "model": "sonar-pro",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": message]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
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