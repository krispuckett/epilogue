import Foundation
import CryptoKit
import os.log

// MARK: - Secure API Manager for Production
final class SecureAPIManager {
    static let shared = SecureAPIManager()
    
    private let userDefaults = UserDefaults.standard
    private let rateLimitKey = "perplexity_usage"
    private let dailyQuestionLimit = 20  // Matches CloudFlare worker default
    private let logger = Logger(subsystem: "com.epilogue.app", category: "SecureAPIManager")
    
    // MARK: - Proxy Configuration
    private let proxyBaseURL = "https://epilogue-proxy.kris-puckett.workers.dev"

    // Basic client-side auth - NOTE: Can be extracted from binary
    // TODO: Post-launch - Implement StoreKit receipt validation on CloudFlare worker
    private var appSecret: String {
        // Simple obfuscation (not cryptographically secure, just discourages casual extraction)
        let encoded: [UInt8] = [101, 112, 105, 108, 111, 103, 117, 101, 95, 116, 101, 115, 116, 102, 108, 105, 103, 104, 116, 95, 50, 48, 50, 53, 95, 115, 101, 99, 114, 101, 116]
        return String(bytes: encoded, encoding: .utf8) ?? ""
    }
    
    private init() {}
    
    // MARK: - Proxy API Management
    
    enum APIError: LocalizedError {
        case proxyNotConfigured
        case unauthorized
        case rateLimitExceeded(resetTime: Date?)
        case serviceError(String)
        case networkError(String)
        
        var errorDescription: String? {
            switch self {
            case .proxyNotConfigured:
                return "API proxy not configured. Please contact support."
            case .unauthorized:
                return "App authentication failed. Please update the app."
            case .rateLimitExceeded(let resetTime):
                if let reset = resetTime {
                    let formatter = DateFormatter()
                    formatter.timeStyle = .short
                    return "Daily limit reached. Resets at \(formatter.string(from: reset))"
                }
                return "Daily limit reached. Please try again tomorrow."
            case .serviceError(let message):
                return "Service error: \(message)"
            case .networkError(let message):
                return "Network error: \(message)"
            }
        }
    }
    
    /// Get or create a unique user ID for rate limiting
    private func getUserID() -> String {
        if let existingID = userDefaults.string(forKey: "epilogue_user_id") {
            return existingID
        } else {
            let newID = UUID().uuidString
            userDefaults.set(newID, forKey: "epilogue_user_id")
            return newID
        }
    }
    
    /// Create authenticated request to proxy
    func createProxyRequest(endpoint: String = "", body: Data?) -> URLRequest? {
        guard let url = URL(string: proxyBaseURL + endpoint) else {
            logger.error("Invalid proxy URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(appSecret, forHTTPHeaderField: "X-Epilogue-Auth")
        request.setValue(getUserID(), forHTTPHeaderField: "X-User-ID")
        request.httpBody = body
        request.timeoutInterval = 30  // 30 second timeout
        
        return request
    }
    
    /// Call the proxy API with automatic error handling
    func callProxyAPI(body: Data) async throws -> Data {
        guard let request = createProxyRequest(body: body) else {
            throw APIError.proxyNotConfigured
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Invalid response type")
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200:
                // Success - check for rate limit headers
                if let limitStr = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Limit"),
                   let remainingStr = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") {
                    let limit = Int(limitStr) ?? dailyQuestionLimit
                    let remaining = Int(remainingStr) ?? 0
                    logger.info("Rate limit: \(remaining)/\(limit) requests remaining")
                    
                    // Store for local display
                    userDefaults.set(remaining, forKey: "api_requests_remaining")
                    userDefaults.set(limit, forKey: "api_requests_limit")
                }
                return data
                
            case 401:
                logger.error("Unauthorized - check app secret")
                throw APIError.unauthorized
                
            case 429:
                // Rate limit exceeded
                var resetTime: Date?
                if let resetStr = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset") {
                    resetTime = ISO8601DateFormatter().date(from: resetStr)
                }
                logger.warning("Rate limit exceeded, resets at \(resetTime?.description ?? "unknown")")
                throw APIError.rateLimitExceeded(resetTime: resetTime)
                
            case 500...599:
                logger.error("Server error: \(httpResponse.statusCode)")
                throw APIError.serviceError("Server temporarily unavailable")
                
            default:
                // Try to parse error message from response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorData["message"] as? String {
                    throw APIError.serviceError(message)
                }
                throw APIError.serviceError("Unexpected error: \(httpResponse.statusCode)")
            }
            
        } catch let error as APIError {
            throw error
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw APIError.networkError(error.localizedDescription)
        }
    }
    
    /// Check remaining API calls for today
    func getRemainingCalls() -> (remaining: Int, limit: Int) {
        let remaining = userDefaults.integer(forKey: "api_requests_remaining")
        let limit = userDefaults.integer(forKey: "api_requests_limit")
        return (remaining: remaining > 0 ? remaining : dailyQuestionLimit,
                limit: limit > 0 ? limit : dailyQuestionLimit)
    }
    
    // MARK: - Rate Limiting
    
    struct UsageData: Codable {
        let date: Date
        var questionCount: Int
        var deviceID: String
    }
    
    private var deviceID: String {
        // Get or create a unique device ID
        if let existingID = userDefaults.string(forKey: "device_unique_id") {
            return existingID
        } else {
            let newID = UUID().uuidString
            userDefaults.set(newID, forKey: "device_unique_id")
            return newID
        }
    }
    
    func canMakeAPICall() -> (allowed: Bool, remaining: Int, resetTime: Date?) {
        let usage = getCurrentUsage()
        
        // Check if it's a new day
        if !Calendar.current.isDateInToday(usage.date) {
            // Reset for new day
            resetUsage()
            return (true, dailyQuestionLimit - 1, nil)
        }
        
        // Check current day's limit
        let remaining = max(0, dailyQuestionLimit - usage.questionCount)
        let allowed = usage.questionCount < dailyQuestionLimit
        
        // Calculate reset time (midnight)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let resetTime = Calendar.current.startOfDay(for: tomorrow)
        
        return (allowed, remaining, resetTime)
    }
    
    func recordAPICall() {
        var usage = getCurrentUsage()
        
        // Reset if new day
        if !Calendar.current.isDateInToday(usage.date) {
            usage = UsageData(date: Date(), questionCount: 1, deviceID: deviceID)
        } else {
            usage.questionCount += 1
        }
        
        saveUsage(usage)
        
        logger.info("Rate Limit: \(usage.questionCount)/\(self.dailyQuestionLimit) questions used today")
    }
    
    private func getCurrentUsage() -> UsageData {
        guard let data = userDefaults.data(forKey: rateLimitKey),
              let usage = try? JSONDecoder().decode(UsageData.self, from: data) else {
            return UsageData(date: Date(), questionCount: 0, deviceID: deviceID)
        }
        return usage
    }
    
    private func saveUsage(_ usage: UsageData) {
        if let data = try? JSONEncoder().encode(usage) {
            userDefaults.set(data, forKey: rateLimitKey)
        }
    }
    
    private func resetUsage() {
        let usage = UsageData(date: Date(), questionCount: 0, deviceID: deviceID)
        saveUsage(usage)
    }
    
    // MARK: - Premium/Testing Override
    
    func enableUnlimitedQuestions(enabled: Bool) {
        // For TestFlight testers or premium users
        userDefaults.set(enabled, forKey: "unlimited_questions")
    }
    
    var hasUnlimitedQuestions: Bool {
        userDefaults.bool(forKey: "unlimited_questions")
    }
    
    // MARK: - Analytics (for monitoring abuse)
    
    func logUsageAnalytics() {
        let usage = getCurrentUsage()
        
        // In production, send this to your analytics service
        logger.info("Analytics - Device: \(self.deviceID.prefix(8))..., Questions today: \(usage.questionCount)")
    }
}
