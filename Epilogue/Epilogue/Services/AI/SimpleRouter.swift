import Foundation

// MARK: - Dead Simple Router for Cost Savings
class SimpleRouter {
    static let shared = SimpleRouter()
    
    private init() {}
    
    enum AIService {
        case foundationModels  // Free, on-device
        case perplexity       // Costs money, has knowledge
    }
    
    func route(_ question: String, hasUserNotes: Bool) -> AIService {
        // Only route to free AI if we're CERTAIN the answer is in user notes
        if hasUserNotes && isAboutUserContent(question) {
            return .foundationModels
        }
        
        // Everything else needs real knowledge from Perplexity
        return .perplexity
    }
    
    private func isAboutUserContent(_ q: String) -> Bool {
        let question = q.lowercased()
        
        // ONLY route if explicitly asking about user's own content
        return question.contains("my notes") ||
               question.contains("what did i highlight") ||
               question.contains("what did i write") ||
               question.contains("my thoughts") ||
               question.contains("i highlighted") ||
               question.contains("i noted")
    }
}