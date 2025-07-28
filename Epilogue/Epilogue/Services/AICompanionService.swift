import Foundation
import Combine

// MARK: - AI Service Protocol
protocol AIServiceProtocol {
    func chat(with message: String, bookContext: Book?) async throws -> String
    func streamChat(message: String, bookContext: Book?) async throws -> AsyncThrowingStream<String, Error>
}

// MARK: - AI Companion Service
class AICompanionService: ObservableObject {
    static let shared = AICompanionService()
    
    // Published properties for UI binding
    @Published var currentProvider: AIProvider = .perplexity
    @Published var isProcessing = false
    
    // Available AI providers
    enum AIProvider: String, CaseIterable {
        case perplexity = "Perplexity"
        case appleIntelligence = "Apple Intelligence"
        
        var isAvailable: Bool {
            switch self {
            case .perplexity:
                return true // Always available if API key is configured
            case .appleIntelligence:
                // Check if Apple Intelligence is available on this device
                if #available(iOS 18.0, *) {
                    // Future: Check for actual Apple Intelligence availability
                    return false // Not yet implemented
                } else {
                    return false
                }
            }
        }
        
        var requiresAPIKey: Bool {
            switch self {
            case .perplexity:
                return true
            case .appleIntelligence:
                return false
            }
        }
    }
    
    private init() {
        // Load saved provider preference
        if let savedProvider = UserDefaults.standard.string(forKey: "preferred_ai_provider"),
           let provider = AIProvider(rawValue: savedProvider),
           provider.isAvailable {
            self.currentProvider = provider
        }
    }
    
    // MARK: - Public Methods
    
    func processMessage(_ message: String, bookContext: Book?, conversationHistory: [UnifiedChatMessage] = []) async throws -> String {
        isProcessing = true
        defer { 
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        // Build context from conversation history
        let contextualMessage = buildContextualMessage(
            message: message,
            bookContext: bookContext,
            history: conversationHistory
        )
        
        switch currentProvider {
        case .perplexity:
            let service = PerplexityService()
            return try await service.chat(with: contextualMessage, bookContext: bookContext)
            
        case .appleIntelligence:
            // Future implementation
            throw AIServiceError.providerNotImplemented
        }
    }
    
    func streamMessage(_ message: String, bookContext: Book?, conversationHistory: [UnifiedChatMessage] = []) async throws -> AsyncThrowingStream<String, Error> {
        isProcessing = true
        defer { 
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        let contextualMessage = buildContextualMessage(
            message: message,
            bookContext: bookContext,
            history: conversationHistory
        )
        
        switch currentProvider {
        case .perplexity:
            let service = PerplexityService()
            return try await service.streamChat(message: contextualMessage, bookContext: bookContext)
            
        case .appleIntelligence:
            throw AIServiceError.providerNotImplemented
        }
    }
    
    // MARK: - Configuration
    
    func setProvider(_ provider: AIProvider) {
        guard provider.isAvailable else { return }
        currentProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "preferred_ai_provider")
    }
    
    func isConfigured() -> Bool {
        switch currentProvider {
        case .perplexity:
            // Check if API key is configured
            if let apiKey = Bundle.main.object(forInfoDictionaryKey: "PERPLEXITY_API_KEY") as? String,
               !apiKey.isEmpty,
               apiKey != "your_actual_api_key_here",
               !apiKey.contains("$("),
               apiKey != "PLACEHOLDER_API_KEY" {
                return true
            }
            return false
            
        case .appleIntelligence:
            return false // Not yet implemented
        }
    }
    
    // MARK: - Private Methods
    
    private func buildContextualMessage(message: String, bookContext: Book?, history: [UnifiedChatMessage]) -> String {
        var context = message
        
        // Add book context if available
        if let book = bookContext {
            context = "Discussing '\(book.title)' by \(book.author): \(message)"
        }
        
        // Add recent conversation context (last 3 exchanges)
        if history.count > 1 {
            let recentHistory = history.suffix(6) // Last 3 exchanges
            var conversationContext = "\n\nRecent conversation:\n"
            for msg in recentHistory {
                let role = msg.isUser ? "User" : "Assistant"
                conversationContext += "\(role): \(msg.content)\n"
            }
            context = conversationContext + "\n\nUser: " + context
        }
        
        return context
    }
}

// MARK: - Errors
enum AIServiceError: LocalizedError {
    case providerNotImplemented
    case notConfigured
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .providerNotImplemented:
            return "This AI provider is not yet implemented"
        case .notConfigured:
            return "AI service is not configured. Please check your settings."
        case .serviceUnavailable:
            return "AI service is currently unavailable"
        }
    }
}