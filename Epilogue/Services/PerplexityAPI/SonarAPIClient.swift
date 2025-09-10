import Foundation
import OSLog

// MARK: - Sonar API Client

actor SonarAPIClient {
    static let shared = SonarAPIClient()
    
    private let session: URLSession
    private let logger = Logger(subsystem: "com.epilogue.app", category: "SonarAPI")
    
    // Configuration - Using proxy instead of direct API
    private let proxyURL = "https://epilogue-proxy.kris-puckett.workers.dev"
    private let appSecret = "epilogue_testflight_2025_secret"
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        
        self.session = URLSession(configuration: configuration)
    }
    
    private func getUserID() -> String {
        let userDefaults = UserDefaults.standard
        if let existingID = userDefaults.string(forKey: "epilogue_user_id") {
            return existingID
        } else {
            let newID = UUID().uuidString
            userDefaults.set(newID, forKey: "epilogue_user_id")
            return newID
        }
    }
    
    // MARK: - Streaming Chat Completion
    
    func streamChatCompletion(
        model: SonarModel,
        messages: [ChatMessage],
        maxTokens: Int = 1000,
        temperature: Double = 0.7
    ) -> AsyncThrowingStream<StreamingResponse, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await performStreamingRequest(
                        model: model,
                        messages: messages,
                        maxTokens: maxTokens,
                        temperature: temperature,
                        continuation: continuation
                    )
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
        continuation: AsyncThrowingStream<StreamingResponse, Error>.Continuation
    ) async throws {
        guard let apiKey = apiKey else {
            throw SonarError.missingAPIKey
        }
        
        guard let url = URL(string: "\(baseURL)\(streamingEndpoint)") else {
            throw SonarError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        let requestBody = ChatCompletionRequest(
            model: model.rawValue,
            messages: messages.map { $0.toAPIFormat() },
            maxTokens: maxTokens,
            temperature: temperature,
            stream: true,
            returnCitations: true,
            returnImages: false,
            searchDomainFilter: nil,
            searchRecencyFilter: nil
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.debug("Starting streaming request with model: \(model.rawValue)")
        
        let (bytes, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SonarError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SonarError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let responseInitTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.debug("Response initiated in \(responseInitTime * 1000)ms")
        
        var buffer = ""
        var totalTokens = 0
        
        for try await line in bytes.lines {
            if line.isEmpty || line == "data: [DONE]" {
                continue
            }
            
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                do {
                    let chunkData = jsonString.data(using: .utf8) ?? Data()
                    let chunk = try JSONDecoder().decode(StreamChunk.self, from: chunkData)
                    
                    if let delta = chunk.choices.first?.delta {
                        let response = StreamingResponse(
                            content: delta.content,
                            role: delta.role,
                            citations: delta.citations,
                            isComplete: chunk.choices.first?.finishReason != nil,
                            tokenCount: chunk.usage?.totalTokens
                        )
                        
                        if let tokens = chunk.usage?.totalTokens {
                            totalTokens = tokens
                        }
                        
                        continuation.yield(response)
                    }
                } catch {
                    logger.error("Failed to parse chunk: \(error.localizedDescription)")
                }
            }
        }
        
        logger.debug("Streaming complete. Total tokens: \(totalTokens)")
        continuation.finish()
    }
    
    // MARK: - Non-Streaming Request
    
    func chatCompletion(
        model: SonarModel,
        messages: [ChatMessage],
        maxTokens: Int = 1000,
        temperature: Double = 0.7
    ) async throws -> ChatCompletionResponse {
        guard let apiKey = apiKey else {
            throw SonarError.missingAPIKey
        }
        
        guard let url = URL(string: "\(baseURL)\(streamingEndpoint)") else {
            throw SonarError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ChatCompletionRequest(
            model: model.rawValue,
            messages: messages.map { $0.toAPIFormat() },
            maxTokens: maxTokens,
            temperature: temperature,
            stream: false,
            returnCitations: true,
            returnImages: false,
            searchDomainFilter: nil,
            searchRecencyFilter: nil
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SonarError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(APIError.self, from: data) {
                throw SonarError.apiError(message: errorData.error.message)
            }
            throw SonarError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let completionResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        return completionResponse
    }
}

// MARK: - Models

enum SonarModel: String, CaseIterable {
    case sonarSmall = "sonar-small-chat"
    case sonarMedium = "sonar-medium-chat"
    case sonarSmallOnline = "sonar-small-online"
    case sonarMediumOnline = "sonar-medium-online"
    
    var isFree: Bool {
        switch self {
        case .sonarSmall, .sonarSmallOnline:
            return true
        case .sonarMedium, .sonarMediumOnline:
            return false
        }
    }
    
    var maxTokens: Int {
        switch self {
        case .sonarSmall, .sonarSmallOnline:
            return 2048
        case .sonarMedium, .sonarMediumOnline:
            return 4096
        }
    }
    
    var costPerToken: Double {
        switch self {
        case .sonarSmall, .sonarSmallOnline:
            return 0.0 // Free tier
        case .sonarMedium, .sonarMediumOnline:
            return 0.00002 // $0.02 per 1K tokens
        }
    }
}

// MARK: - Request/Response Models

struct ChatCompletionRequest: Codable {
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
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case stream
        case returnCitations = "return_citations"
        case returnImages = "return_images"
        case searchDomainFilter = "search_domain_filter"
        case searchRecencyFilter = "search_recency_filter"
    }
}

struct ChatCompletionResponse: Codable {
    let id: String
    let model: String
    let object: String
    let created: Int
    let choices: [Choice]
    let usage: Usage?
    let citations: [Citation]?
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
}

struct StreamChunk: Codable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [StreamChoice]
    let usage: Usage?
}

struct StreamChoice: Codable {
    let index: Int
    let delta: Delta
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index
        case delta
        case finishReason = "finish_reason"
    }
}

struct Delta: Codable {
    let role: String?
    let content: String?
    let citations: [Citation]?
}

struct Usage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

struct Citation: Codable, Identifiable {
    let id = UUID()
    let url: String
    let title: String?
    let snippet: String?
    let source: String?
    
    enum CodingKeys: String, CodingKey {
        case url, title, snippet, source
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

// MARK: - Chat Message

struct ChatMessage {
    let role: MessageRole
    let content: String
    
    enum MessageRole: String {
        case system
        case user
        case assistant
    }
    
    func toAPIFormat() -> [String: String] {
        ["role": role.rawValue, "content": content]
    }
}

// MARK: - Streaming Response

struct StreamingResponse {
    let content: String?
    let role: String?
    let citations: [Citation]?
    let isComplete: Bool
    let tokenCount: Int?
}

// MARK: - Errors

enum SonarError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(message: String)
    case networkError(Error)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .apiError(let message):
            return "API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}