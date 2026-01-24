import Foundation
import Combine
import OSLog

// MARK: - Claude Response

struct ClaudeResponse {
    let text: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cached: Bool

    init(text: String, model: String, inputTokens: Int = 0, outputTokens: Int = 0, cached: Bool = false) {
        self.text = text
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cached = cached
    }
}

// MARK: - Claude Error

enum ClaudeError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case unauthorized
    case authenticationFailed
    case serverError(String)
    case timeout
    case rateLimitExceeded
    case overloaded

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Taking too long. Try again."
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment."
        case .overloaded:
            return "Claude is busy. Trying backup..."
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Connection issue. Please check your internet."
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized, .authenticationFailed:
            return "Authentication failed - check API key configuration"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// MARK: - Claude Model

enum ClaudeModel: String {
    case sonnet = "claude-sonnet-4-20250514"
    case opus = "claude-opus-4-5-20251101"

    var displayName: String {
        switch self {
        case .sonnet: return "Claude Sonnet"
        case .opus: return "Claude Opus"
        }
    }
}

// MARK: - Claude Service

@MainActor
class ClaudeService: ObservableObject {
    static let shared = ClaudeService()

    private let logger = Logger(subsystem: "com.epilogue", category: "ClaudeAI")
    private let proxyEndpoint = "https://epilogue-proxy.kris-puckett.workers.dev/claude"
    private let directEndpoint = "https://api.anthropic.com/v1/messages"
    private var currentEndpoint: String = ""
    private var apiKey: String = ""

    // Streaming support
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3

    // Default model
    private(set) var defaultModel: ClaudeModel = .sonnet

    private init() {
        setupAPIKey()
    }

    // MARK: - Subscription-Aware Model Selection

    /// Returns Opus for Plus subscribers, Sonnet for free users
    var subscriberModel: ClaudeModel {
        // Check Gandalf mode (developer testing)
        if UserDefaults.standard.bool(forKey: "gandalfMode") {
            logger.info("🧙‍♂️ Gandalf mode: Using Opus")
            return .opus
        }

        // Check Plus subscription
        if SimplifiedStoreKitManager.shared.isPlus {
            logger.info("⭐️ Plus subscriber: Using Opus")
            return .opus
        }

        logger.info("Using Sonnet for free tier")
        return .sonnet
    }

    /// Chat using the subscription-appropriate model
    func subscriberChat(
        message: String,
        systemPrompt: String? = nil,
        maxTokens: Int = 1024
    ) async throws -> String {
        try await chat(
            message: message,
            systemPrompt: systemPrompt,
            model: subscriberModel,
            maxTokens: maxTokens
        )
    }

    /// Stream chat using the subscription-appropriate model
    func subscriberStreamChat(
        message: String,
        systemPrompt: String? = nil,
        maxTokens: Int = 1024
    ) -> AsyncThrowingStream<ClaudeResponse, Error> {
        streamChat(
            message: message,
            systemPrompt: systemPrompt,
            model: subscriberModel,
            maxTokens: maxTokens
        )
    }

    private func setupAPIKey() {
        // Check if user has provided their own Claude API key
        if let userKey = KeychainManager.shared.getAPIKey(for: .claude),
           !userKey.isEmpty {
            self.apiKey = userKey
            self.currentEndpoint = directEndpoint
            logger.info("Claude configured: using user's API key")
        } else {
            // Use proxy authentication
            self.apiKey = "proxy_authenticated"
            self.currentEndpoint = proxyEndpoint
            logger.info("Claude configured: using CloudFlare proxy")
        }
    }

    // MARK: - Streaming Chat

    func streamChat(
        message: String,
        systemPrompt: String? = nil,
        model: ClaudeModel = .sonnet,
        maxTokens: Int = 1024
    ) -> AsyncThrowingStream<ClaudeResponse, Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }

                do {
                    let request = try self.createRequest(
                        message: message,
                        systemPrompt: systemPrompt,
                        model: model,
                        maxTokens: maxTokens,
                        stream: true
                    )

                    try await self.streamWithRetry(
                        request: request,
                        model: model,
                        continuation: continuation
                    )
                } catch {
                    self.logger.error("Claude streaming error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func streamWithRetry(
        request: URLRequest,
        model: ClaudeModel,
        continuation: AsyncThrowingStream<ClaudeResponse, Error>.Continuation
    ) async throws {
        var accumulatedText = ""
        var inputTokens = 0
        var outputTokens = 0
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                break
            case 401:
                logger.error("Claude auth failed")
                throw ClaudeError.authenticationFailed
            case 429:
                logger.warning("Claude rate limited")
                throw ClaudeError.rateLimitExceeded
            case 529:
                logger.warning("Claude overloaded")
                throw ClaudeError.overloaded
            case 500...599:
                throw ClaudeError.serverError("Status \(httpResponse.statusCode)")
            default:
                throw ClaudeError.invalidResponse
            }

            // Process SSE stream
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let data = String(line.dropFirst(6))

                    if data == "[DONE]" {
                        break
                    }

                    if let jsonData = data.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

                        // Handle different event types
                        if let type = json["type"] as? String {
                            switch type {
                            case "content_block_delta":
                                if let delta = json["delta"] as? [String: Any],
                                   let text = delta["text"] as? String {
                                    accumulatedText += text

                                    let partialResponse = ClaudeResponse(
                                        text: accumulatedText,
                                        model: model.rawValue,
                                        inputTokens: inputTokens,
                                        outputTokens: outputTokens,
                                        cached: false
                                    )
                                    continuation.yield(partialResponse)
                                }

                            case "message_delta":
                                if let usage = json["usage"] as? [String: Any] {
                                    outputTokens = usage["output_tokens"] as? Int ?? outputTokens
                                }

                            case "message_start":
                                if let messageData = json["message"] as? [String: Any],
                                   let usage = messageData["usage"] as? [String: Any] {
                                    inputTokens = usage["input_tokens"] as? Int ?? 0
                                }

                            case "message_stop":
                                // Final message
                                let finalResponse = ClaudeResponse(
                                    text: accumulatedText,
                                    model: model.rawValue,
                                    inputTokens: inputTokens,
                                    outputTokens: outputTokens,
                                    cached: false
                                )
                                continuation.yield(finalResponse)
                                continuation.finish()

                                let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                                logger.info("Claude stream complete in \(String(format: "%.1f", duration))ms, \(inputTokens) in / \(outputTokens) out")
                                return

                            default:
                                break
                            }
                        }
                    }
                }
            }

            // If we get here without message_stop, yield final response
            if !accumulatedText.isEmpty {
                let finalResponse = ClaudeResponse(
                    text: accumulatedText,
                    model: model.rawValue,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cached: false
                )
                continuation.yield(finalResponse)
            }
            continuation.finish()

        } catch {
            // Retry logic
            if reconnectAttempts < maxReconnectAttempts {
                reconnectAttempts += 1
                let delay = pow(2.0, Double(reconnectAttempts - 1))
                logger.warning("Claude retry \(self.reconnectAttempts)/\(self.maxReconnectAttempts) after \(delay)s")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                reconnectAttempts = 0

                try await streamWithRetry(
                    request: request,
                    model: model,
                    continuation: continuation
                )
            } else {
                throw error
            }
        }
    }

    // MARK: - Non-Streaming Chat

    func chat(
        message: String,
        systemPrompt: String? = nil,
        model: ClaudeModel = .sonnet,
        maxTokens: Int = 1024
    ) async throws -> String {
        logger.info("Claude chat: \(message.prefix(80))...")

        var fullResponse = ""
        var responseCount = 0

        for try await response in streamChat(
            message: message,
            systemPrompt: systemPrompt,
            model: model,
            maxTokens: maxTokens
        ) {
            responseCount += 1
            fullResponse = response.text
        }

        if fullResponse.isEmpty {
            logger.error("Claude returned empty response")
            throw ClaudeError.invalidResponse
        }

        logger.info("Claude completed with \(responseCount) chunks, length: \(fullResponse.count)")
        return fullResponse
    }

    // MARK: - Request Creation

    private func createRequest(
        message: String,
        systemPrompt: String?,
        model: ClaudeModel,
        maxTokens: Int,
        stream: Bool
    ) throws -> URLRequest {
        guard let url = URL(string: currentEndpoint) else {
            throw ClaudeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if currentEndpoint == directEndpoint {
            // Direct API with user's key
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        } else {
            // Proxy authentication
            let encoded: [UInt8] = [101, 112, 105, 108, 111, 103, 117, 101, 95, 116, 101, 115, 116, 102, 108, 105, 103, 104, 116, 95, 50, 48, 50, 53, 95, 115, 101, 99, 114, 101, 116]
            let proxyToken = String(bytes: encoded, encoding: .utf8) ?? ""
            request.setValue(proxyToken, forHTTPHeaderField: "X-Epilogue-Auth")
        }

        // User ID for rate limiting
        let userId: String
        if let existingId = UserDefaults.standard.string(forKey: "userId") {
            userId = existingId
        } else {
            userId = UUID().uuidString
            UserDefaults.standard.set(userId, forKey: "userId")
        }
        request.setValue(userId, forHTTPHeaderField: "X-User-ID")

        if stream {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        } else {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build request body
        var body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": maxTokens,
            "stream": stream,
            "messages": [
                ["role": "user", "content": message]
            ]
        ]

        if let systemPrompt = systemPrompt {
            body["system"] = systemPrompt
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Configuration

    func setDefaultModel(_ model: ClaudeModel) {
        defaultModel = model
        logger.info("Claude default model set to: \(model.displayName)")
    }

    func configureUserAPIKey(_ key: String) {
        KeychainManager.shared.setAPIKey(key, for: .claude)
        setupAPIKey()
        logger.info("Claude API key configured")
    }

    func clearUserAPIKey() {
        KeychainManager.shared.removeAPIKey(for: .claude)
        setupAPIKey()
        logger.info("Claude API key cleared, using proxy")
    }

    var hasUserAPIKey: Bool {
        KeychainManager.shared.hasAPIKey(for: .claude)
    }
}
