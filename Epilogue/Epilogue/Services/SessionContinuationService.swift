import SwiftUI
import SwiftData
import Combine

// MARK: - Session Continuation Service
@MainActor
class SessionContinuationService: ObservableObject {
    static let shared = SessionContinuationService()
    
    @Published var continuingSession: AmbientSession?
    @Published var sessionContext: SessionContext?
    
    private init() {}
    
    // MARK: - Continue Session
    func continueSession(_ session: AmbientSession, with modelContext: ModelContext) {
        continuingSession = session
        
        // Build context from session
        let questions: [SessionMessage] = (session.capturedQuestions ?? []).map { question in
            SessionMessage(
                role: .user,
                content: question.content ?? "",
                timestamp: question.timestamp ?? Date()
            )
        }
        
        let quotes: [SessionMessage] = (session.capturedQuotes ?? []).map { quote in
            SessionMessage(
                role: .system,
                content: "Quote captured: \"\(quote.text ?? "")\"",
                timestamp: quote.timestamp ?? Date()
            )
        }
        
        let notes: [SessionMessage] = (session.capturedNotes ?? []).map { note in
            SessionMessage(
                role: .system,
                content: "Note: \(note.content ?? "")",
                timestamp: note.timestamp ?? Date()
            )
        }
        
        let bookId: String? = session.bookModel?.id
        let bookTitle: String = session.bookModel?.title ?? "Unknown Book"
        let summary: String = generateSessionSummary(session)
        
        sessionContext = SessionContext(
            bookId: bookId,
            bookTitle: bookTitle,
            previousQuestions: questions,
            previousQuotes: quotes,
            previousNotes: notes,
            sessionSummary: summary
        )
    }
    
    // MARK: - Merge Sessions
    func mergeSessions(_ sessions: [AmbientSession]) -> FusedSession {
        let allQuestions: [CapturedQuestion] = sessions.flatMap { $0.capturedQuestions ?? [] }
            .sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        
        let allQuotes: [CapturedQuote] = sessions.flatMap { $0.capturedQuotes ?? [] }
            .sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        
        let allNotes: [CapturedNote] = sessions.flatMap { $0.capturedNotes ?? [] }
            .sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        
        // Extract common themes
        let themes = extractCommonThemes(from: sessions)
        
        // Generate synthesis
        let synthesis = generateSynthesis(
            questions: allQuestions,
            quotes: allQuotes,
            notes: allNotes,
            themes: themes
        )
        
        return FusedSession(
            id: UUID(),
            originalSessions: sessions,
            fusedQuestions: allQuestions,
            fusedQuotes: allQuotes,
            fusedNotes: allNotes,
            commonThemes: themes,
            synthesis: synthesis,
            suggestedQuestions: generateSuggestedQuestions(from: themes)
        )
    }
    
    // MARK: - Helper Functions
    private func generateSessionSummary(_ session: AmbientSession) -> String {
        var summary = "Previous session with \(session.bookModel?.title ?? "unknown book")"
        
        if !(session.capturedQuestions ?? []).isEmpty {
            summary += "\n\nKey questions explored:"
            for question in (session.capturedQuestions ?? []).prefix(3) {
                summary += "\n• \(question.content ?? "")"
            }
        }
        
        if !(session.capturedQuotes ?? []).isEmpty {
            summary += "\n\nQuotes captured:"
            for quote in (session.capturedQuotes ?? []).prefix(2) {
                summary += "\n• \"\(quote.text ?? "")\""
            }
        }
        
        return summary
    }
    
    private func extractCommonThemes(from sessions: [AmbientSession]) -> [String] {
        var themeCounts: [String: Int] = [:]
        
        // Analyze all content
        for session in sessions {
            let questionContent: String = (session.capturedQuestions ?? []).compactMap { $0.content }.joined(separator: " ")
            let noteContent: String = (session.capturedNotes ?? []).compactMap { $0.content }.joined(separator: " ")
            let content: String = questionContent + " " + noteContent
            
            // Simple theme extraction (would use NLP in production)
            let themes = ["identity", "love", "death", "power", "freedom", "time", "nature", "family"]
            for theme in themes {
                if content.lowercased().contains(theme) {
                    themeCounts[theme, default: 0] += 1
                }
            }
        }
        
        return Array(themeCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key.capitalized })
    }
    
    private func generateSynthesis(
        questions: [CapturedQuestion],
        quotes: [CapturedQuote],
        notes: [CapturedNote],
        themes: [String]
    ) -> String {
        var synthesis = "Synthesis of \(questions.count) questions, \(quotes.count) quotes, and \(notes.count) notes.\n\n"
        
        if !themes.isEmpty {
            synthesis += "Common themes: \(themes.joined(separator: ", "))\n\n"
        }
        
        synthesis += "This reading journey explores fundamental questions about \(themes.first ?? "literature") "
        synthesis += "through careful attention to both the text and your evolving understanding."
        
        return synthesis
    }
    
    private func generateSuggestedQuestions(from themes: [String]) -> [String] {
        var suggestions: [String] = []
        
        let topThemes: ArraySlice<String> = themes.prefix(3)
        for theme in topThemes {
            switch theme.lowercased() {
            case "identity":
                suggestions.append("How do the characters' identities evolve throughout the narrative?")
            case "love":
                suggestions.append("What different forms of love are portrayed in these works?")
            case "power":
                suggestions.append("How is power gained, maintained, and lost in these stories?")
            case "time":
                suggestions.append("How does the treatment of time affect the narrative structure?")
            default:
                suggestions.append("What deeper insights about \(theme) emerge from these readings?")
            }
        }
        
        return suggestions
    }
}

// MARK: - Session Context
struct SessionContext {
    let bookId: String?
    let bookTitle: String
    let previousQuestions: [SessionMessage]
    let previousQuotes: [SessionMessage]
    let previousNotes: [SessionMessage]
    let sessionSummary: String
    
    var allMessages: [SessionMessage] {
        let combined: [SessionMessage] = previousQuestions + previousQuotes + previousNotes
        return combined.sorted { $0.timestamp < $1.timestamp }
    }
}

// MARK: - Session Message
struct SessionMessage {
    enum Role {
        case user
        case assistant
        case system
    }
    
    let role: Role
    let content: String
    let timestamp: Date
}

// MARK: - Fused Session
struct FusedSession: Identifiable {
    let id: UUID
    let originalSessions: [AmbientSession]
    let fusedQuestions: [CapturedQuestion]
    let fusedQuotes: [CapturedQuote]
    let fusedNotes: [CapturedNote]
    let commonThemes: [String]
    let synthesis: String
    let suggestedQuestions: [String]
    
    var sessionCount: Int { originalSessions.count }
    var totalDuration: TimeInterval {
        originalSessions.map(\.duration).reduce(0, +)
    }
}