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
        
        // Extract quotes and notes from conversation history
        let recentQuotes = extractQuotesFromHistory(history)
        let recentNotes = extractNotesFromHistory(history)
        
        // Build enhanced context with quotes and notes
        var enhancedContext = ""
        
        if !recentQuotes.isEmpty {
            enhancedContext += "\n\nRecent quotes from the book:\n"
            for quote in recentQuotes.prefix(3) {
                enhancedContext += "- \(quote)\n"
            }
        }
        
        if !recentNotes.isEmpty {
            enhancedContext += "\n\nReader's notes and reflections:\n"
            for note in recentNotes.prefix(3) {
                enhancedContext += "- \(note)\n"
            }
        }
        
        // Add recent conversation context (last 3 exchanges)
        if history.count > 1 {
            let recentHistory = history.suffix(6) // Last 3 exchanges
            var conversationContext = "\n\nRecent conversation:\n"
            for msg in recentHistory {
                let role = msg.isUser ? "User" : "Assistant"
                conversationContext += "\(role): \(msg.content)\n"
            }
            enhancedContext += conversationContext
        }
        
        // Combine everything
        if !enhancedContext.isEmpty {
            context = enhancedContext + "\n\nUser: " + context
        }
        
        return context
    }
    
    private func extractQuotesFromHistory(_ history: [UnifiedChatMessage]) -> [String] {
        var quotes: [String] = []
        
        for message in history where message.isUser {
            let content = message.content
            
            // Look for quoted text patterns
            if content.starts(with: "\u{201C}") && content.contains("\u{201D}") {
                quotes.append(content)
            } else if content.starts(with: "\"") && content.contains("\"") {
                quotes.append(content)
            }
        }
        
        return quotes
    }
    
    private func extractNotesFromHistory(_ history: [UnifiedChatMessage]) -> [String] {
        var notes: [String] = []
        
        for message in history where message.isUser {
            let content = message.content
            
            // Look for note indicators (emojis used in ambient session)
            if content.starts(with: "💡") || // Insight
               content.starts(with: "🔗") || // Connection
               content.starts(with: "💭") {  // Reflection
                notes.append(content)
            }
        }
        
        return notes
    }
    
    // MARK: - Debug Methods
    
    func debugProcessMessage(_ message: String, bookContext: Book?) async {
        print("🤖 AI Service Debug")
        print("📝 Message: \(message)")
        print("📚 Book: \(bookContext?.title ?? "None")")
        print("🔧 Provider: \(currentProvider.rawValue)")
        print("✅ Configured: \(isConfigured())")
        
        do {
            switch currentProvider {
            case .perplexity:
                print("🌐 Testing Perplexity service...")
                if isConfigured() {
                    print("✅ Perplexity API key is configured")
                    let response = try await processMessage(message, bookContext: bookContext)
                    print("📤 Response received: \(response.prefix(100))...")
                } else {
                    print("❌ Perplexity API key NOT configured")
                    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "PERPLEXITY_API_KEY") as? String {
                        print("🔑 API Key found but invalid: \(apiKey.prefix(10))...")
                    } else {
                        print("🔑 No API key found in Info.plist")
                    }
                }
                
            case .appleIntelligence:
                print("🍎 Apple Intelligence not yet implemented")
            }
            
        } catch {
            print("❌ Error during debug: \(error)")
            print("📋 Error details: \(error.localizedDescription)")
        }
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