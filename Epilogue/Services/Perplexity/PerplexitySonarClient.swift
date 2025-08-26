import Foundation
import OSLog

// MARK: - Perplexity Sonar API Client

actor PerplexitySonarClient {
    static let shared = PerplexitySonarClient()
    
    private let session: URLSession
    private let logger = Logger(subsystem: "com.epilogue.app", category: "PerplexityAPI")
    private var apiKey: String?
    
    private let baseURL = "https://api.perplexity.ai"
    private let streamingEndpoint = "/chat/completions"
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        self.session = URLSession(configuration: configuration)
    }
    
    func configure(apiKey: String) {
        self.apiKey = apiKey
        logger.info("Perplexity API configured")
    }
    
    // MARK: - Streaming Chat Completion
    
    func streamChat(
        model: SonarModel,
        messages: [ChatMessage],
        maxTokens: Int = 1000,
        temperature: Double = 0.7,
        searchDomainFilter: [String]? = nil,
        searchRecencyFilter: SearchRecency? = nil
    ) -> AsyncThrowingStream<StreamingResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    try await performStreamingRequest(
                        model: model,
                        messages: messages,
                        maxTokens: maxTokens,
                        temperature: temperature,
                        searchDomainFilter: searchDomainFilter,
                        searchRecencyFilter: searchRecencyFilter,
                        continuation: continuation
                    )
                    let responseTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                    logger.debug("Stream initiated in \(responseTime)ms")
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func performStreamingRequest(
        model: SonarModel,
        messages: [ChatMessage],
        maxTokens: Int,
        temperature: Double,
        searchDomainFilter: [String]?,
        searchRecencyFilter: SearchRecency?,
        continuation: AsyncThrowingStream<StreamingResponse, Error>.Continuation
    ) async throws {
        guard let apiKey = apiKey else {
            throw PerplexityError.missingAPIKey
        }
        
        guard let url = URL(string: "\(baseURL)\(streamingEndpoint)") else {
            throw PerplexityError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        let requestBody = ChatRequest(
            model: model.rawValue,
            messages: messages.map { $0.toDict() },
            maxTokens: maxTokens,
            temperature: temperature,
            stream: true,
            returnCitations: true,
            returnImages: false,
            searchDomainFilter: searchDomainFilter,
            searchRecencyFilter: searchRecencyFilter?.rawValue
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (bytes, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PerplexityError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PerplexityError.httpError(statusCode: httpResponse.statusCode)
        }
        
        var buffer = ""
        var totalTokens = 0
        
        for try await line in bytes.lines {
            if line.isEmpty || line == "data: [DONE]" {
                continue
            }
            
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                do {
                    if let data = jsonString.data(using: .utf8) {
                        let chunk = try JSONDecoder().decode(StreamChunk.self, from: data)
                        
                        if let delta = chunk.choices.first?.delta {
                            let response = StreamingResponse(
                                content: delta.content,
                                role: delta.role,
                                citations: delta.citations,
                                isComplete: chunk.choices.first?.finishReason != nil,
                                usage: chunk.usage
                            )
                            
                            if let usage = chunk.usage {
                                totalTokens = usage.totalTokens
                            }
                            
                            continuation.yield(response)
                        }
                    }
                } catch {
                    logger.error("Failed to parse chunk: \(error)")
                }
            }
        }
        
        logger.info("Stream completed with \(totalTokens) tokens")
        continuation.finish()
    }
    
    // MARK: - Non-Streaming Request
    
    func chat(
        model: SonarModel,
        messages: [ChatMessage],
        maxTokens: Int = 1000,
        temperature: Double = 0.7
    ) async throws -> ChatResponse {
        guard let apiKey = apiKey else {
            throw PerplexityError.missingAPIKey
        }
        
        guard let url = URL(string: "\(baseURL)\(streamingEndpoint)") else {
            throw PerplexityError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ChatRequest(
            model: model.rawValue,
            messages: messages.map { $0.toDict() },
            maxTokens: maxTokens,
            temperature: temperature,
            stream: false,
            returnCitations: true,
            returnImages: false
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PerplexityError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw PerplexityError.apiError(message: errorData.error.message)
            }
            throw PerplexityError.httpError(statusCode: httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }
}

// MARK: - Models

enum SonarModel: String, CaseIterable {
    case small = "sonar-small-chat"
    case medium = "sonar-medium-chat"
    case smallOnline = "sonar-small-online"
    case mediumOnline = "sonar-medium-online"
    
    var isFree: Bool {
        switch self {
        case .small, .smallOnline:
            return true
        case .medium, .mediumOnline:
            return false
        }
    }
    
    var maxTokens: Int {
        switch self {
        case .small, .smallOnline:
            return 2048
        case .medium, .mediumOnline:
            return 4096
        }
    }
    
    var costPerToken: Double {
        switch self {
        case .small, .smallOnline:
            return 0.0
        case .medium, .mediumOnline:
            return 0.00002 // $0.02 per 1K tokens
        }
    }
}

enum SearchRecency: String {
    case day
    case week
    case month
    case year
}

// MARK: - Request/Response Models

struct ChatMessage {
    let role: MessageRole
    let content: String
    
    enum MessageRole: String {
        case system
        case user
        case assistant
    }
    
    func toDict() -> [String: String] {
        ["role": role.rawValue, "content": content]
    }
}

struct ChatRequest: Codable {
    let model: String
    let messages: [[String: String]]
    let maxTokens: Int
    let temperature: Double
    let stream: Bool
    let returnCitations: Bool
    let returnImages: Bool
    let searchDomainFilter: [String]?
    let searchRecencyFilter: String?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
        case returnCitations = "return_citations"
        case returnImages = "return_images"
        case searchDomainFilter = "search_domain_filter"
        case searchRecencyFilter = "search_recency_filter"
    }
}

struct ChatResponse: Codable {
    let id: String
    let model: String
    let created: Int
    let choices: [Choice]
    let usage: TokenUsage?
    let citations: [Citation]?
}

struct Choice: Codable {
    let index: Int
    let message: Message
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

struct Message: Codable {
    let role: String
    let content: String
}

struct StreamChunk: Codable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [StreamChoice]
    let usage: TokenUsage?
}

struct StreamChoice: Codable {
    let index: Int
    let delta: Delta
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, delta
        case finishReason = "finish_reason"
    }
}

struct Delta: Codable {
    let role: String?
    let content: String?
    let citations: [Citation]?
}

struct TokenUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

struct Citation: Codable, Identifiable, Hashable {
    let id = UUID()
    let url: String
    let title: String?
    let snippet: String?
    let source: String?
    
    enum CodingKeys: String, CodingKey {
        case url, title, snippet, source
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static func == (lhs: Citation, rhs: Citation) -> Bool {
        lhs.url == rhs.url
    }
}

struct APIError: Codable {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let message: String
        let type: String?
        let code: String?
    }
}

struct StreamingResponse {
    let content: String?
    let role: String?
    let citations: [Citation]?
    let isComplete: Bool
    let usage: TokenUsage?
}

// MARK: - Errors

enum PerplexityError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(message: String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .apiError(let message):
            return message
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}