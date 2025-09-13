import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Reading Context Manager
@MainActor
class ReadingContextManager: ObservableObject {
    static let shared = ReadingContextManager()
    
    // MARK: - Published Properties
    @Published var currentBook: Book?
    @Published var currentChapter: String?
    @Published var readingPace: ReadingPace = .normal
    @Published var emotionalJourney: [EmotionalState] = []
    @Published var currentMood: EmotionalState = .neutral
    @Published var sessionStartTime: Date?
    @Published var conversationThreads: [ConversationThread] = []
    
    // MARK: - Context Storage
    private var recentQuotes: [CapturedQuote] = []
    private var recentNotes: [CapturedNote] = []
    private var recentQuestions: [String] = []
    private var recentAIResponses: [AIResponse] = []
    private var readingPatterns: ReadingPattern = ReadingPattern()
    
    // Configuration
    private let maxRecentItems = 10
    private let contextWindowSize = 5
    private let threadTimeoutInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Types
    
    struct AIContext {
        let book: Book?
        let chapter: String?
        let recentQuotes: [CapturedQuote]
        let recentNotes: [CapturedNote]
        let recentQuestions: [String]
        let readingDuration: TimeInterval
        let emotionalState: EmotionalState
        let readingPace: ReadingPace
        let conversationHistory: [ConversationTurn]
        let followUpContext: FollowUpContext?
        let metadata: [String: Any]
        
        var enrichedPrompt: String {
            var prompt = ""
            
            // Add book context
            if let book = book {
                prompt += "Currently reading: \"\(book.title)\" by \(book.author)\n"
                if let chapter = chapter {
                    prompt += "Chapter: \(chapter)\n"
                }
            }
            
            // Add emotional context
            prompt += "Reader's current mood: \(emotionalState.description)\n"
            prompt += "Reading pace: \(readingPace.description)\n"
            
            // Add recent activity context
            if !recentQuotes.isEmpty {
                prompt += "\nRecent quotes the reader found interesting:\n"
                for (index, quote) in recentQuotes.prefix(3).enumerated() {
                    prompt += "\(index + 1). \"\((quote.text ?? "").prefix(100))...\"\n"
                }
            }
            
            if !recentNotes.isEmpty {
                prompt += "\nReader's recent notes:\n"
                for (index, note) in recentNotes.prefix(3).enumerated() {
                    prompt += "\(index + 1). \((note.content ?? "").prefix(100))...\n"
                }
            }
            
            // Add follow-up context if applicable
            if let followUp = followUpContext {
                prompt += "\n[This is a follow-up to: \(followUp.previousQuestion)]\n"
                prompt += "[Previous response summary: \(followUp.previousResponseSummary)]\n"
            }
            
            return prompt
        }
    }
    
    struct ConversationThread {
        let id = UUID()
        let startTime: Date
        var lastUpdateTime: Date
        let topic: String
        var turns: [ConversationTurn]
        var isActive: Bool
        
        var duration: TimeInterval {
            lastUpdateTime.timeIntervalSince(startTime)
        }
        
        mutating func addTurn(_ turn: ConversationTurn) {
            turns.append(turn)
            lastUpdateTime = Date()
        }
    }
    
    struct ConversationTurn {
        let id = UUID()
        let timestamp: Date
        let speaker: Speaker
        let content: String
        let intent: ConversationIntent?
        let sentiment: EmotionalState?
        
        enum Speaker {
            case user
            case ai
            case system
        }
    }
    
    enum ConversationIntent {
        case question
        case followUp
        case clarification
        case exploration
        case reaction
        case summary
        
        var requiresPreviousContext: Bool {
            switch self {
            case .followUp, .clarification, .exploration:
                return true
            default:
                return false
            }
        }
    }
    
    struct FollowUpContext {
        let previousQuestion: String
        let previousResponse: String
        let previousResponseSummary: String
        let previousIntent: ConversationIntent
        let relatedQuotes: [CapturedQuote]
        let relatedNotes: [CapturedNote]
    }
    
    struct AIResponse {
        let id = UUID()
        let question: String
        let response: String
        let timestamp: Date
        let bookContext: Book?
        let confidence: Float
    }
    
    enum ReadingPace: String, CaseIterable {
        case slow = "slow"
        case normal = "normal"
        case fast = "fast"
        case skimming = "skimming"
        case deepReading = "deep_reading"
        
        var description: String {
            switch self {
            case .slow: return "Taking time to absorb"
            case .normal: return "Regular reading pace"
            case .fast: return "Quick reading"
            case .skimming: return "Skimming through"
            case .deepReading: return "Deep, contemplative reading"
            }
        }
        
        var contextModifier: String {
            switch self {
            case .slow, .deepReading:
                return "The reader is taking their time, likely wanting deeper insights"
            case .fast, .skimming:
                return "The reader is moving quickly, provide concise responses"
            case .normal:
                return "The reader is at a comfortable pace"
            }
        }
    }
    
    enum EmotionalState: String, CaseIterable {
        case excited = "excited"
        case curious = "curious"
        case contemplative = "contemplative"
        case confused = "confused"
        case inspired = "inspired"
        case neutral = "neutral"
        case frustrated = "frustrated"
        case engaged = "engaged"
        case moved = "moved"
        
        var description: String {
            switch self {
            case .excited: return "Excited and energized"
            case .curious: return "Curious and questioning"
            case .contemplative: return "Deep in thought"
            case .confused: return "Seeking clarity"
            case .inspired: return "Feeling inspired"
            case .neutral: return "Neutral"
            case .frustrated: return "Slightly frustrated"
            case .engaged: return "Fully engaged"
            case .moved: return "Emotionally moved"
            }
        }
        
        var aiToneModifier: String {
            switch self {
            case .excited:
                return "Match their excitement with enthusiasm"
            case .curious:
                return "Provide detailed, informative responses"
            case .contemplative:
                return "Offer thoughtful, philosophical insights"
            case .confused:
                return "Clarify and simplify explanations"
            case .inspired:
                return "Build on their inspiration with creative connections"
            case .frustrated:
                return "Be patient and break things down clearly"
            case .engaged:
                return "Maintain engagement with rich content"
            case .moved:
                return "Acknowledge the emotional impact respectfully"
            case .neutral:
                return "Provide balanced, informative responses"
            }
        }
    }
    
    struct ReadingPattern {
        var averageSessionDuration: TimeInterval = 0
        var preferredTimeOfDay: DateComponents?
        var typicalReadingSpeed: Int = 250 // words per minute
        var breakFrequency: TimeInterval = 1800 // 30 minutes
        var annotationFrequency: Float = 0.0 // notes per minute
        
        mutating func update(with session: ReadingSession) {
            // Update patterns based on session data
            let sessions = [session] // In real app, would fetch historical sessions
            
            // Calculate average duration
            let totalDuration = sessions.reduce(0) { $0 + $1.duration }
            averageSessionDuration = totalDuration / Double(sessions.count)
            
            // Update annotation frequency
            let totalNotes = sessions.reduce(0) { $0 + $1.notesCount }
            let totalMinutes = totalDuration / 60
            annotationFrequency = Float(totalNotes) / Float(totalMinutes)
        }
    }
    
    struct ReadingSession {
        let startTime: Date
        let endTime: Date?
        let book: Book
        let notesCount: Int
        let quotesCount: Int
        let questionsCount: Int
        
        var duration: TimeInterval {
            (endTime ?? Date()).timeIntervalSince(startTime)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Listen for session events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBookChanged),
            name: Notification.Name("CurrentBookChanged"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQuoteCaptured),
            name: Notification.Name("QuoteCaptured"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNoteCaptured),
            name: Notification.Name("NoteCaptured"),
            object: nil
        )
    }
    
    // MARK: - Session Management
    
    func startReadingSession(book: Book) {
        currentBook = book
        sessionStartTime = Date()
        emotionalJourney = [.neutral]
        currentMood = .neutral
        conversationThreads = []
        
        #if DEBUG
        print("📚 Started reading session for: \(book.title)")
        #endif
    }
    
    func endReadingSession() {
        guard let startTime = sessionStartTime else { return }
        
        // Create session record
        let session = ReadingSession(
            startTime: startTime,
            endTime: Date(),
            book: currentBook!,
            notesCount: recentNotes.count,
            quotesCount: recentQuotes.count,
            questionsCount: recentQuestions.count
        )
        
        // Update reading patterns
        readingPatterns.update(with: session)
        
        // Archive conversation threads
        archiveConversationThreads()
        
        // Reset session
        currentBook = nil
        currentChapter = nil
        sessionStartTime = nil
        
        #if DEBUG
        print("📚 Ended reading session. Duration: \(session.duration)s")
        #endif
    }
    
    // MARK: - Context Building
    
    func buildAIContext(for question: String) -> AIContext {
        let followUpContext = detectFollowUpContext(for: question)
        let conversationHistory = getRecentConversationHistory()
        
        return AIContext(
            book: currentBook,
            chapter: currentChapter,
            recentQuotes: Array(recentQuotes.prefix(contextWindowSize)),
            recentNotes: Array(recentNotes.prefix(contextWindowSize)),
            recentQuestions: Array(recentQuestions.prefix(contextWindowSize)),
            readingDuration: sessionStartTime?.timeIntervalSinceNow ?? 0,
            emotionalState: currentMood,
            readingPace: readingPace,
            conversationHistory: conversationHistory,
            followUpContext: followUpContext,
            metadata: buildMetadata()
        )
    }
    
    private func buildMetadata() -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        metadata["sessionDuration"] = sessionStartTime?.timeIntervalSinceNow ?? 0
        metadata["quotesCount"] = recentQuotes.count
        metadata["notesCount"] = recentNotes.count
        metadata["questionsCount"] = recentQuestions.count
        metadata["activeThreads"] = conversationThreads.filter { $0.isActive }.count
        metadata["emotionalJourneyLength"] = emotionalJourney.count
        metadata["annotationFrequency"] = readingPatterns.annotationFrequency
        
        return metadata
    }
    
    // MARK: - Smart Follow-ups
    
    private func detectFollowUpContext(for question: String) -> FollowUpContext? {
        let lowercased = question.lowercased()
        
        // Check for explicit follow-up patterns
        let followUpPatterns = [
            "tell me more",
            "what about",
            "why",
            "how come",
            "can you explain",
            "elaborate",
            "go deeper",
            "what do you mean",
            "continue",
            "and then",
            "but why",
            "so what",
            "for example"
        ]
        
        let isFollowUp = followUpPatterns.contains { lowercased.contains($0) }
        
        // Check for pronouns referring to previous context
        let referencePatterns = ["that", "this", "it", "they", "those", "these"]
        let hasReference = referencePatterns.contains { lowercased.contains($0) }
        
        if (isFollowUp || hasReference) && !recentAIResponses.isEmpty {
            let lastResponse = recentAIResponses.last!
            
            // Check if within timeout window
            if Date().timeIntervalSince(lastResponse.timestamp) < threadTimeoutInterval {
                return FollowUpContext(
                    previousQuestion: lastResponse.question,
                    previousResponse: lastResponse.response,
                    previousResponseSummary: summarizeResponse(lastResponse.response),
                    previousIntent: determineIntent(for: lastResponse.question),
                    relatedQuotes: findRelatedQuotes(to: lastResponse.question),
                    relatedNotes: findRelatedNotes(to: lastResponse.question)
                )
            }
        }
        
        return nil
    }
    
    private func summarizeResponse(_ response: String) -> String {
        // Simple summarization - take first 100 characters
        // In production, would use NLP summarization
        let cleaned = response
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.count > 100 {
            return String(cleaned.prefix(100)) + "..."
        }
        return cleaned
    }
    
    private func determineIntent(for question: String) -> ConversationIntent {
        let lowercased = question.lowercased()
        
        if lowercased.contains("tell me more") || lowercased.contains("elaborate") {
            return .followUp
        } else if lowercased.contains("what do you mean") || lowercased.contains("clarify") {
            return .clarification
        } else if lowercased.contains("what about") || lowercased.contains("how about") {
            return .exploration
        } else if lowercased.contains("interesting") || lowercased.contains("wow") {
            return .reaction
        } else if lowercased.contains("summary") || lowercased.contains("summarize") {
            return .summary
        } else {
            return .question
        }
    }
    
    // MARK: - Conversation Threading
    
    func addConversationTurn(_ content: String, speaker: ConversationTurn.Speaker) {
        let intent = speaker == .user ? determineIntent(for: content) : nil
        let sentiment = speaker == .user ? analyzeEmotionalTone(content) : nil
        
        let turn = ConversationTurn(
            timestamp: Date(),
            speaker: speaker,
            content: content,
            intent: intent,
            sentiment: sentiment
        )
        
        // Find or create appropriate thread
        if let activeThread = findActiveThread(for: content) {
            if let index = conversationThreads.firstIndex(where: { $0.id == activeThread.id }) {
                conversationThreads[index].addTurn(turn)
            }
        } else {
            // Create new thread
            var newThread = ConversationThread(
                startTime: Date(),
                lastUpdateTime: Date(),
                topic: extractTopic(from: content),
                turns: [turn],
                isActive: true
            )
            conversationThreads.append(newThread)
        }
        
        // Deactivate old threads
        deactivateOldThreads()
        
        // Track question if from user
        if speaker == .user {
            recentQuestions.append(content)
            if recentQuestions.count > maxRecentItems {
                recentQuestions.removeFirst()
            }
        }
    }
    
    private func findActiveThread(for content: String) -> ConversationThread? {
        // Find thread based on topic similarity and recency
        let activeThreads = conversationThreads.filter { $0.isActive }
        
        for thread in activeThreads {
            // Check if within timeout window
            if Date().timeIntervalSince(thread.lastUpdateTime) < threadTimeoutInterval {
                // Check topic relevance (simple keyword matching for now)
                if isTopicRelated(content, to: thread.topic) {
                    return thread
                }
            }
        }
        
        return nil
    }
    
    private func isTopicRelated(_ content: String, to topic: String) -> Bool {
        // Simple keyword overlap check
        let contentWords = Set(content.lowercased().split(separator: " ").map(String.init))
        let topicWords = Set(topic.lowercased().split(separator: " ").map(String.init))
        
        let overlap = contentWords.intersection(topicWords)
        return overlap.count >= 2 || (overlap.count == 1 && topicWords.count <= 3)
    }
    
    private func extractTopic(from content: String) -> String {
        // Extract main topic (simplified - would use NLP in production)
        let words = content.split(separator: " ").map(String.init)
        
        // Remove common words
        let stopWords = Set(["the", "a", "an", "is", "are", "was", "were", "what", "why", "how", "when", "where", "who"])
        let significantWords = words.filter { !stopWords.contains($0.lowercased()) }
        
        // Take first few significant words as topic
        return significantWords.prefix(3).joined(separator: " ")
    }
    
    private func deactivateOldThreads() {
        let now = Date()
        
        for index in conversationThreads.indices {
            if conversationThreads[index].isActive {
                let timeSinceUpdate = now.timeIntervalSince(conversationThreads[index].lastUpdateTime)
                if timeSinceUpdate > threadTimeoutInterval {
                    conversationThreads[index].isActive = false
                }
            }
        }
    }
    
    private func archiveConversationThreads() {
        // Archive threads for future analysis
        // In production, would save to persistent storage
        let threadsToArchive = conversationThreads.filter { !$0.turns.isEmpty }
        
        for thread in threadsToArchive {
            #if DEBUG
            print("📝 Archiving thread: \(thread.topic) with \(thread.turns.count) turns")
            #endif
        }
    }
    
    // MARK: - Context Updates
    
    func addQuote(_ quote: CapturedQuote) {
        recentQuotes.insert(quote, at: 0)
        if recentQuotes.count > maxRecentItems {
            recentQuotes.removeLast()
        }
        
        // Update emotional state based on quote
        updateEmotionalState(basedOn: quote.text ?? "")
    }
    
    func addNote(_ note: CapturedNote) {
        recentNotes.insert(note, at: 0)
        if recentNotes.count > maxRecentItems {
            recentNotes.removeLast()
        }
        
        // Update emotional state based on note
        updateEmotionalState(basedOn: note.content ?? "")
    }
    
    func addAIResponse(_ question: String, response: String, confidence: Float = 0.9) {
        let aiResponse = AIResponse(
            question: question,
            response: response,
            timestamp: Date(),
            bookContext: currentBook,
            confidence: confidence
        )
        
        recentAIResponses.append(aiResponse)
        if recentAIResponses.count > maxRecentItems {
            recentAIResponses.removeFirst()
        }
        
        // Add to conversation
        addConversationTurn(response, speaker: .ai)
    }
    
    // MARK: - Emotional Analysis
    
    private func updateEmotionalState(basedOn text: String) {
        let newState = analyzeEmotionalTone(text)
        
        if newState != currentMood {
            emotionalJourney.append(newState)
            currentMood = newState
        }
    }
    
    private func analyzeEmotionalTone(_ text: String) -> EmotionalState {
        let lowercased = text.lowercased()
        
        // Simple keyword-based analysis
        if lowercased.contains("love") || lowercased.contains("amazing") || lowercased.contains("wonderful") {
            return .excited
        } else if lowercased.contains("why") || lowercased.contains("how") || lowercased.contains("what if") {
            return .curious
        } else if lowercased.contains("think") || lowercased.contains("consider") || lowercased.contains("reflect") {
            return .contemplative
        } else if lowercased.contains("confused") || lowercased.contains("don't understand") || lowercased.contains("unclear") {
            return .confused
        } else if lowercased.contains("inspired") || lowercased.contains("brilliant") || lowercased.contains("genius") {
            return .inspired
        } else if lowercased.contains("frustrated") || lowercased.contains("annoying") || lowercased.contains("difficult") {
            return .frustrated
        } else if lowercased.contains("interesting") || lowercased.contains("fascinating") {
            return .engaged
        } else if lowercased.contains("moved") || lowercased.contains("touched") || lowercased.contains("emotional") {
            return .moved
        } else {
            return .neutral
        }
    }
    
    // MARK: - Reading Pace Detection
    
    func updateReadingPace(wordsRead: Int, timeElapsed: TimeInterval) {
        let wordsPerMinute = Double(wordsRead) / (timeElapsed / 60)
        
        if wordsPerMinute < 150 {
            readingPace = .slow
        } else if wordsPerMinute < 200 {
            readingPace = .deepReading
        } else if wordsPerMinute < 300 {
            readingPace = .normal
        } else if wordsPerMinute < 400 {
            readingPace = .fast
        } else {
            readingPace = .skimming
        }
    }
    
    // MARK: - Helper Methods
    
    private func getRecentConversationHistory() -> [ConversationTurn] {
        let activeThreads = conversationThreads.filter { $0.isActive }
        
        var allTurns: [ConversationTurn] = []
        for thread in activeThreads {
            allTurns.append(contentsOf: thread.turns.suffix(3))
        }
        
        return allTurns.sorted { $0.timestamp < $1.timestamp }.suffix(10)
    }
    
    private func findRelatedQuotes(to question: String) -> [CapturedQuote] {
        // Find quotes that might be related to the question
        let questionWords = Set(question.lowercased().split(separator: " ").map(String.init))
        
        return recentQuotes.filter { quote in
            let quoteWords = Set((quote.text ?? "").lowercased().split(separator: " ").map(String.init))
            let overlap = questionWords.intersection(quoteWords)
            return overlap.count >= 2
        }
    }
    
    private func findRelatedNotes(to question: String) -> [CapturedNote] {
        // Find notes that might be related to the question
        let questionWords = Set(question.lowercased().split(separator: " ").map(String.init))
        
        return recentNotes.filter { note in
            let noteWords = Set((note.content ?? "").lowercased().split(separator: " ").map(String.init))
            let overlap = questionWords.intersection(noteWords)
            return overlap.count >= 2
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleBookChanged(_ notification: Notification) {
        if let book = notification.object as? Book {
            if currentBook?.id != book.id {
                // New book, start new session
                if currentBook != nil {
                    endReadingSession()
                }
                startReadingSession(book: book)
            }
        }
    }
    
    @objc private func handleQuoteCaptured(_ notification: Notification) {
        if let quote = notification.object as? CapturedQuote {
            addQuote(quote)
        }
    }
    
    @objc private func handleNoteCaptured(_ notification: Notification) {
        if let note = notification.object as? CapturedNote {
            addNote(note)
        }
    }
    
    // MARK: - Public Interface
    
    func getCurrentContext() -> AIContext {
        return buildAIContext(for: "")
    }
    
    func processUserQuestion(_ question: String) -> AIContext {
        // Add to conversation
        addConversationTurn(question, speaker: .user)
        
        // Build and return context
        return buildAIContext(for: question)
    }
    
    func getSessionSummary() -> String {
        guard let startTime = sessionStartTime else {
            return "No active reading session"
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration / 60)
        
        var summary = "Reading session: \(minutes) minutes\n"
        
        if let book = currentBook {
            summary += "Book: \(book.title)\n"
        }
        
        summary += "Quotes saved: \(recentQuotes.count)\n"
        summary += "Notes taken: \(recentNotes.count)\n"
        summary += "Questions asked: \(recentQuestions.count)\n"
        summary += "Current mood: \(currentMood.description)\n"
        summary += "Reading pace: \(readingPace.description)\n"
        
        if !conversationThreads.isEmpty {
            let activeCount = conversationThreads.filter { $0.isActive }.count
            summary += "Active conversations: \(activeCount)\n"
        }
        
        return summary
    }
    
    func clearSession() {
        endReadingSession()
        recentQuotes.removeAll()
        recentNotes.removeAll()
        recentQuestions.removeAll()
        recentAIResponses.removeAll()
        conversationThreads.removeAll()
        emotionalJourney.removeAll()
        currentMood = .neutral
    }
}