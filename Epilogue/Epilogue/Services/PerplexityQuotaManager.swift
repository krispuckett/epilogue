import Foundation
import SwiftUI
import Combine

class PerplexityQuotaManager: ObservableObject {
    static let shared = PerplexityQuotaManager()

    // Daily quota limits
    private let dailyQuotaLimit = 10

    // Published properties for UI
    @Published var remainingQuestions: Int = 10
    @Published var showQuotaExceededSheet = false

    // Storage keys
    private let questionsUsedKey = "perplexity_questions_used_today"
    private let lastResetDateKey = "perplexity_quota_last_reset"

    private init() {
        checkAndResetIfNeeded()
        loadRemainingQuestions()
    }

    // Check if quota needs to be reset (new day)
    private func checkAndResetIfNeeded() {
        let calendar = Calendar.current
        let now = Date()

        if let lastResetDate = UserDefaults.standard.object(forKey: lastResetDateKey) as? Date {
            // Check if it's a new day
            if !calendar.isDate(lastResetDate, inSameDayAs: now) {
                resetDailyQuota()
            }
        } else {
            // First time, set the reset date
            resetDailyQuota()
        }
    }

    // Reset the daily quota
    private func resetDailyQuota() {
        UserDefaults.standard.set(0, forKey: questionsUsedKey)
        UserDefaults.standard.set(Date(), forKey: lastResetDateKey)
        remainingQuestions = dailyQuotaLimit
        print("📊 Daily Perplexity quota reset. Questions remaining: \(remainingQuestions)")
    }

    // Load remaining questions
    private func loadRemainingQuestions() {
        let questionsUsed = UserDefaults.standard.integer(forKey: questionsUsedKey)
        remainingQuestions = max(0, dailyQuotaLimit - questionsUsed)
    }

    // Check if user can ask a question
    var canAskQuestion: Bool {
        // Check Gandalf mode
        if UserDefaults.standard.bool(forKey: "gandalfMode") {
            print("🧙‍♂️ Gandalf mode active - unlimited questions")
            return true
        }

        checkAndResetIfNeeded()
        return remainingQuestions > 0
    }

    // Track a question usage
    func trackQuestionUsage() -> Bool {
        // Skip tracking in Gandalf mode
        if UserDefaults.standard.bool(forKey: "gandalfMode") {
            return true
        }

        checkAndResetIfNeeded()

        if remainingQuestions > 0 {
            let questionsUsed = UserDefaults.standard.integer(forKey: questionsUsedKey)
            UserDefaults.standard.set(questionsUsed + 1, forKey: questionsUsedKey)
            remainingQuestions = max(0, dailyQuotaLimit - (questionsUsed + 1))

            print("📊 Perplexity question tracked. Remaining: \(remainingQuestions)/\(dailyQuotaLimit)")

            // Show sheet if quota exhausted
            if remainingQuestions == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.showQuotaExceededSheet = true
                }
            }

            return true
        } else {
            // Quota exceeded
            print("⚠️ Daily Perplexity quota exceeded")
            showQuotaExceededSheet = true
            return false
        }
    }

    // Get quota reset time (midnight local time)
    var nextResetTime: Date {
        let calendar = Calendar.current
        return calendar.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? Date()
    }

    // Get time until reset as a formatted string
    var timeUntilReset: String {
        let interval = nextResetTime.timeIntervalSinceNow
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // Get percentage of quota used
    var quotaUsedPercentage: Double {
        Double(dailyQuotaLimit - remainingQuestions) / Double(dailyQuotaLimit)
    }
}