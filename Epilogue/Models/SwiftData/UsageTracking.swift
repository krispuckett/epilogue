import SwiftData
import Foundation

@Model
final class UsageTracking {
    @Attribute(.unique) var id: UUID
    var date: Date
    var apiCallCount: Int
    var quotaRemaining: Int
    var quotaLimit: Int
    var tokensUsed: Int
    var costEstimate: Double? // In USD cents
    var model: String
    var endpoint: String?
    
    init(
        apiCallCount: Int = 0,
        quotaRemaining: Int,
        quotaLimit: Int,
        tokensUsed: Int = 0,
        model: String = "gpt-4",
        endpoint: String? = nil
    ) {
        self.id = UUID()
        self.date = Date()
        self.apiCallCount = apiCallCount
        self.quotaRemaining = quotaRemaining
        self.quotaLimit = quotaLimit
        self.tokensUsed = tokensUsed
        self.model = model
        self.endpoint = endpoint
        self.costEstimate = nil
    }
    
    func incrementUsage(tokens: Int, cost: Double? = nil) {
        apiCallCount += 1
        tokensUsed += tokens
        if quotaRemaining > 0 {
            quotaRemaining -= 1
        }
        if let cost = cost {
            costEstimate = (costEstimate ?? 0) + cost
        }
    }
    
    var quotaPercentageUsed: Double {
        guard quotaLimit > 0 else { return 0 }
        return Double(quotaLimit - quotaRemaining) / Double(quotaLimit)
    }
    
    var isQuotaExceeded: Bool {
        quotaRemaining <= 0
    }
    
    static func todaysUsage(context: ModelContext) -> UsageTracking? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        let descriptor = FetchDescriptor<UsageTracking>(
            predicate: #Predicate { tracking in
                tracking.date >= startOfDay
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return try? context.fetch(descriptor).first
    }
}