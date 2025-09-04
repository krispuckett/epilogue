import Foundation
import CryptoKit

// MARK: - Secure API Manager for Production
final class SecureAPIManager {
    static let shared = SecureAPIManager()
    
    private let userDefaults = UserDefaults.standard
    private let rateLimitKey = "perplexity_usage"
    private let dailyQuestionLimit = 10
    
    private init() {}
    
    // MARK: - Obfuscated API Key
    // Split and obfuscated for security - reconstructed at runtime
    private var apiKeyComponents: [String] {
        // IMPORTANT: Replace these parts with your actual Perplexity API key
        // Split your key into 4-5 parts for obfuscation
        // Example: if your key is "pplx-abc123def456ghi789"
        // Split it like: ["pplx-abc123", "def456", "ghi789"]
        return [
            "pplx-jb3WZP",       // Part 1 - Replace with your actual key part 1
            "6iivi8Dl78",          // Part 2 - Replace with your actual key part 2
            "S7BuM05HgW",         // Part 3 - Replace with your actual key part 3
            "4M2qMvbFyTc",   // Part 4 - Replace with your actual key part 4
            "ULIObfP61SE"           // Part 5 - Replace with your actual key part 5
        ]
    }
    
    // Reconstruct the API key at runtime
    func getAPIKey() -> String {
        // Join the components to form the complete key
        return apiKeyComponents.joined()
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
        
        print("📊 Rate Limit: \(usage.questionCount)/\(dailyQuestionLimit) questions used today")
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
        print("📈 Analytics - Device: \(deviceID.prefix(8))..., Questions today: \(usage.questionCount)")
    }
}
