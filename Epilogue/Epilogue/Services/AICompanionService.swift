import Foundation
import Combine
import SwiftData

// MARK: - AI Service Protocol
protocol AIServiceProtocol {
    func chat(with message: String, bookContext: Book?) async throws -> String
    func streamChat(message: String, bookContext: Book?) async throws -> AsyncThrowingStream<String, Error>
}

// MARK: - AI Companion Service
class AICompanionService: ObservableObject {
    static let shared = AICompanionService()
    
    // Published properties for UI binding
    @Published var currentProvider: AIProvider = .smart
    @Published var isProcessing = false
    
    // Smart AI instance for intelligent routing (lazy to avoid initialization issues)
    private lazy var smartAI = SmartEpilogueAI.shared
    
    // Available AI providers
    enum AIProvider: String, CaseIterable {
        case smart = "Smart (Auto-routing)"
        case perplexity = "Perplexity Only"
        case appleIntelligence = "Apple Intelligence Only"
        
        var isAvailable: Bool {
            switch self {
            case .smart:
                return true // Always available - routes intelligently
            case .perplexity:
                return true // Available if API key is configured
            case .appleIntelligence:
                // Check if Foundation Models is available
                #if canImport(FoundationModels)
                if #available(iOS 26.0, *) {
                    return true // Foundation Models available on iOS 26+
                } else {
                    return false
                }
                #else
                return false
                #endif
            }
        }
        
        var requiresAPIKey: Bool {
            switch self {
            case .smart, .perplexity:
                return true // Perplexity needs API key
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

        // Set active book context for smart AI
        if let book = bookContext {
            await MainActor.run {
                smartAI.setActiveBook(book.toBookModel())
            }
        }

        // Build context from conversation history
        let contextualMessage = buildContextualMessage(
            message: message,
            bookContext: bookContext,
            history: conversationHistory
        )

        // Add retry logic with exponential backoff
        var lastError: Error?
        let maxRetries = 3
        let baseDelay: UInt64 = 1_000_000_000 // 1 second in nanoseconds

        for attempt in 0..<maxRetries {
            do {
                switch currentProvider {
                case .smart:
                    // Use SmartEpilogueAI for intelligent routing
                    return await smartAI.smartQuery(contextualMessage)

                case .perplexity:
                    // Force Perplexity only
                    await MainActor.run {
                        smartAI.currentMode = .externalOnly
                    }
                    return await smartAI.smartQuery(contextualMessage)

                case .appleIntelligence:
                    // Force local Foundation Models only
                    await MainActor.run {
                        smartAI.currentMode = .localOnly
                    }
                    return await smartAI.smartQuery(contextualMessage)
                }
            } catch {
                lastError = error

                // Check if error is retryable
                let isRetryable = isRetryableError(error)

                if !isRetryable {
                    // Don't retry for non-retryable errors
                    throw error
                }

                // If not the last attempt, wait with exponential backoff
                if attempt < maxRetries - 1 {
                    let delay = baseDelay * UInt64(pow(2.0, Double(attempt)))
                    try? await Task.sleep(nanoseconds: delay)

                    #if DEBUG
                    print("🔄 Retrying AI request (attempt \(attempt + 2)/\(maxRetries)) after \(Double(delay) / 1_000_000_000)s delay")
                    #endif
                }
            }
        }

        // If we've exhausted all retries, throw the last error
        throw lastError ?? NSError(domain: "AICompanionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed after \(maxRetries) attempts"])
    }

    private func isRetryableError(_ error: Error) -> Bool {
        // Check for network errors that are worth retrying
        let nsError = error as NSError

        // Network-related errors
        if nsError.domain == NSURLErrorDomain {
            let retryableCodes = [
                NSURLErrorTimedOut,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorCannotConnectToHost,
                NSURLErrorCannotFindHost,
                NSURLErrorDNSLookupFailed
            ]
            return retryableCodes.contains(nsError.code)
        }

        // HTTP status codes that are worth retrying
        if let httpResponse = nsError.userInfo["HTTPResponse"] as? HTTPURLResponse {
            let retryableStatusCodes = [408, 429, 500, 502, 503, 504] // Timeout, Rate limit, Server errors
            return retryableStatusCodes.contains(httpResponse.statusCode)
        }

        // API-specific errors
        let errorDescription = error.localizedDescription.lowercased()
        if errorDescription.contains("rate limit") ||
           errorDescription.contains("timeout") ||
           errorDescription.contains("temporarily unavailable") ||
           errorDescription.contains("connection") {
            return true
        }

        return false
    }
    
    func streamMessage(_ message: String, bookContext: Book?, conversationHistory: [UnifiedChatMessage] = []) async throws -> AsyncThrowingStream<String, Error> {
        isProcessing = true
        defer { 
            Task { @MainActor in
                self.isProcessing = false
            }
        }
        
        // Set active book context for smart AI
        if let book = bookContext {
            await MainActor.run {
                smartAI.setActiveBook(book.toBookModel())
            }
        }
        
        let contextualMessage = buildContextualMessage(
            message: message,
            bookContext: bookContext,
            history: conversationHistory
        )
        
        // For streaming, we'll use OptimizedPerplexityService
        // TODO: Implement streaming for SmartEpilogueAI
        let model = UserDefaults.standard.string(forKey: "perplexityModel") ?? "sonar"
        
        // Create an adapter stream that converts PerplexityResponse to String
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await response in OptimizedPerplexityService.shared.streamSonarResponse(contextualMessage, bookContext: bookContext) {
                        // Extract text content from the response
                        continuation.yield(response.text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
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
        case .smart, .perplexity:
            // We now have a built-in API key in PerplexityService
            // No need to check KeychainManager or Info.plist
            #if DEBUG
            print("🔑 AI Service configured: true (using built-in API key)")
            #endif
            return true
            
        case .appleIntelligence:
            return true // Foundation Models doesn't need API key
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
        #if DEBUG
        print("AI Service Debug")
        #if DEBUG
        print("Message: \(message)")
        #endif
        #if DEBUG
        print("Book: \(bookContext?.title ?? "None")")
        #endif
        #if DEBUG
        print("🔧 Provider: \(currentProvider.rawValue)")
        #endif
        #if DEBUG
        print("Configured: \(isConfigured())")
        #endif
        #endif
        
        do {
            switch currentProvider {
            case .smart:
                #if DEBUG
                print("🧠 Testing Smart AI with automatic routing...")
                #endif
                if isConfigured() {
                    #if DEBUG
                    print("Smart AI is configured (Perplexity API key found)")
                    #endif
                    let response = try await processMessage(message, bookContext: bookContext)
                    #if DEBUG
                    print("📤 Response received [\(response.count) characters]")
                    #endif
                } else {
                    #if DEBUG
                    print("Smart AI requires Perplexity API key for external queries")
                    #endif
                }
                
            case .perplexity:
                #if DEBUG
                print("🌐 Testing Perplexity service...")
                if isConfigured() {
                    #if DEBUG
                    print("Perplexity API key is configured")
                    #endif
                    let response = try await processMessage(message, bookContext: bookContext)
                    #if DEBUG
                    print("📤 Response received [\(response.count) characters]")
                    #endif
                } else {
                    #if DEBUG
                    print("Perplexity API key NOT configured")
                    #endif
                    if Bundle.main.object(forInfoDictionaryKey: "PERPLEXITY_API_KEY") is String {
                        #if DEBUG
                        print("🔑 API Key validation failed")
                        #endif
                    } else {
                        #if DEBUG
                        print("🔑 No API key found in Info.plist")
                        #endif
                    }
                }
                #endif
                
            case .appleIntelligence:
                #if DEBUG
                print("🍎 Testing Apple Intelligence (Foundation Models)...")
                let response = try await processMessage(message, bookContext: bookContext)
                #if DEBUG
                print("📤 Response received [\(response.count) characters]")
                #endif
                #endif
            }
            
        } catch {
            #if DEBUG
            print("Error during debug: \(error)")
            #if DEBUG
            print("Error details: \(error.localizedDescription)")
            #endif
            #endif
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
