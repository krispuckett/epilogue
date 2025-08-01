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
    
    func startReadingSession(for book: Book) {
        let sessionKey = "reading_session_\(book.id)"
        UserDefaults.standard.set(Date(), forKey: sessionKey)
    }
    
    func updateReadingProgress(for book: Book, page: Int) {
        let progressKey = "reading_progress_\(book.id)"
        UserDefaults.standard.set(page, forKey: progressKey)
    }
    
    func endReadingSession(for book: Book) {
        let sessionKey = "reading_session_\(book.id)"
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
    
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
        var contextParts: [String] = []
        
        // Add reading session context
        if let sessionContext = getCurrentReadingSession(for: bookContext) {
            contextParts.append(sessionContext)
        }
        
        // Add time-based context
        contextParts.append(getTimeBasedContext())
        
        // Add recent content from book
        if let book = bookContext,
           let recentContent = getRecentContentForBook(book, from: history) {
            contextParts.append(recentContent)
        }
        
        // Add recent ambient captures
        if let ambientContext = getRecentAmbientCaptures(from: history) {
            contextParts.append(ambientContext)
        }
        
        // Build the final context message
        var finalContext = message
        
        if !contextParts.isEmpty {
            let contextSummary = contextParts.joined(separator: " | ")
            
            // Keep context concise (under 500 chars)
            let trimmedContext = String(contextSummary.prefix(490))
            
            if let book = bookContext {
                finalContext = "[Context: \(trimmedContext)] Currently discussing '\(book.title)': \(message)"
            } else {
                finalContext = "[Context: \(trimmedContext)] \(message)"
            }
        }
        
        return finalContext
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
            
            // Look for note indicators (note prefixes removed in new version)
            // Notes are now unprefixed plain text
            notes.append(content)
        }
        
        return notes
    }
    
    // MARK: - Context Awareness Methods
    
    private func getCurrentReadingSession(for book: Book?) -> String? {
        guard let book = book else { return nil }
        
        // Check if there's an active reading session
        let sessionKey = "reading_session_\(book.id)"
        let progressKey = "reading_progress_\(book.id)"
        
        if let sessionStart = UserDefaults.standard.object(forKey: sessionKey) as? Date {
            let duration = Int(Date().timeIntervalSince(sessionStart) / 60) // minutes
            let currentPage = UserDefaults.standard.integer(forKey: progressKey)
            
            if duration > 0 {
                let pageInfo = currentPage > 0 ? "Page \(currentPage) of " : ""
                return "Reading session: \(duration) min, \(pageInfo)\(book.title)"
            }
        }
        
        // Return last known progress if no active session
        let lastPage = UserDefaults.standard.integer(forKey: progressKey)
        if lastPage > 0 {
            return "Progress: Page \(lastPage) of \(book.title)"
        }
        
        return nil
    }
    
    private func getTimeBasedContext() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        
        switch hour {
        case 5..<12:
            timeOfDay = "Morning reading"
        case 12..<17:
            timeOfDay = "Afternoon reading"
        case 17..<22:
            timeOfDay = "Evening reading"
        default:
            timeOfDay = "Late night reading"
        }
        
        // Add day of week for additional context
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayOfWeek = formatter.string(from: Date())
        
        return "\(timeOfDay) on \(dayOfWeek)"
    }
    
    private func getRecentAmbientCaptures(from history: [UnifiedChatMessage]) -> String? {
        // Look for ambient session messages (voice notes, reflections)
        let recentThoughts = history
            .suffix(10) // Last 10 messages
            .filter { msg in
                msg.isUser && (
                    msg.content.contains("🎙️") || // Voice note indicator
                    msg.content.lowercased().contains("note:") ||
                    msg.content.lowercased().contains("thought:")
                )
            }
            .map { $0.content }
        
        if !recentThoughts.isEmpty {
            let thoughts = recentThoughts
                .prefix(2)
                .map { thought in
                    // Truncate long thoughts
                    thought.count > 50 ? String(thought.prefix(47)) + "..." : thought
                }
                .joined(separator: ", ")
            
            return "Recent thoughts: \(thoughts)"
        }
        
        return nil
    }
    
    private func getRecentContentForBook(_ book: Book, from history: [UnifiedChatMessage]) -> String? {
        var highlights: [String] = []
        
        // Extract quotes and notes from history
        for message in history.suffix(20) where message.isUser {
            let content = message.content
            
            // Check for quotes (with quote marks)
            if (content.contains("\"") || content.contains("\u{201C}") || content.contains("\u{201D}")) &&
               content.count > 20 && content.count < 200 {
                highlights.append(content)
            }
            // Check for notes about the book
            else if content.count > 15 && content.count < 150 &&
                    (content.lowercased().contains("note:") ||
                     content.lowercased().contains("thought:") ||
                     content.lowercased().contains("reflection:")) {
                highlights.append(content)
            }
        }
        
        if !highlights.isEmpty {
            let recentHighlights = highlights
                .suffix(3)
                .map { highlight in
                    // Clean and truncate
                    let cleaned = highlight
                        .replacingOccurrences(of: "Note:", with: "")
                        .replacingOccurrences(of: "Thought:", with: "")
                        .replacingOccurrences(of: "Reflection:", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    return cleaned.count > 60 ? String(cleaned.prefix(57)) + "..." : cleaned
                }
            
            return "Recent highlights: \(recentHighlights.joined(separator: "; "))"
        }
        
        return nil
    }
    
    // MARK: - Debug Methods
    
    func debugProcessMessage(_ message: String, bookContext: Book?) async {
        print("AI Service Debug")
        print("Message: \(message)")
        print("Book: \(bookContext?.title ?? "None")")
        print("🔧 Provider: \(currentProvider.rawValue)")
        print("Configured: \(isConfigured())")
        
        do {
            switch currentProvider {
            case .perplexity:
                print("🌐 Testing Perplexity service...")
                if isConfigured() {
                    print("Perplexity API key is configured")
                    let response = try await processMessage(message, bookContext: bookContext)
                    print("📤 Response received: \(response.prefix(100))...")
                } else {
                    print("Perplexity API key NOT configured")
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
            print("Error during debug: \(error)")
            print("Error details: \(error.localizedDescription)")
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