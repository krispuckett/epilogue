import Foundation
import SwiftData
import SwiftUI  // For ObservableObject
import Combine  // For ObservableObject and @Published
import OSLog

@MainActor
final class SessionSummaryGenerator: ObservableObject {
    static let shared = SessionSummaryGenerator()
    
    @Published var isGenerating: Bool = false  // Required for ObservableObject conformance
    
    private let logger = Logger(subsystem: "com.epilogue", category: "SessionSummary")
    private let perplexityService = OptimizedPerplexityService.shared
    
    private init() {}
    
    // MARK: - Smart Session Title Generation
    
    /// Generate an intelligent, contextual title for a chat session
    func generateSessionTitle(
        from messages: [UnifiedChatMessage],
        book: Book? = nil
    ) async -> String {
        isGenerating = true
        defer { isGenerating = false }
        
        // Extract key questions and topics
        let questions = messages
            .filter { $0.isUser }
            .prefix(5) // Use first 5 questions for context
            .map { $0.content }
        
        guard !questions.isEmpty else {
            if let book = book {
                return "Discussion about \(book.title)"
            }
            return "New Conversation"
        }
        
        // Build context for title generation
        let context = buildTitleContext(questions: questions, book: book)
        
        // Generate title using AI
        do {
            let prompt = """
            Generate a concise, engaging title (max 5 words) for this reading session.
            
            Book: \(book?.title ?? "General Reading")
            Topics discussed: \(questions.joined(separator: ", "))
            
            Requirements:
            - Be specific to the actual discussion
            - Capture the essence of what was explored
            - Use active, engaging language
            - No generic titles like "Book Discussion"
            - Maximum 5 words
            
            Return ONLY the title, nothing else.
            """
            
            let title = try await perplexityService.chat(
                message: prompt,
                bookContext: book
            )
            
            // Clean and validate the title
            let cleanedTitle = cleanTitle(title)
            
            logger.info("📝 Generated session title: \(cleanedTitle)")
            return cleanedTitle
            
        } catch {
            logger.error("Failed to generate title: \(error)")
            return fallbackTitle(for: questions, book: book)
        }
    }
    
    /// Generate a comprehensive session summary
    func generateSessionSummary(
        session: OptimizedAmbientSession,
        messages: [UnifiedChatMessage]
    ) async -> ChatSessionSummary {
        isGenerating = true
        defer { isGenerating = false }
        
        let startTime = session.startTime
        let duration = Date().timeIntervalSince(startTime)
        
        // Analyze conversation patterns
        let analysis = analyzeConversation(messages: messages)
        
        // Generate key insights
        let insights = await generateInsights(
            from: messages,
            book: session.bookContext
        )
        
        // Create thematic groupings
        let themes = extractThemes(from: messages)
        
        return ChatSessionSummary(
            title: await generateSessionTitle(from: messages, book: session.bookContext),
            duration: duration,
            messageCount: messages.count,
            questionsAsked: analysis.questionCount,
            topicsExplored: themes,
            keyInsights: insights,
            bookProgress: calculateBookProgress(session: session),
            emotionalTone: analysis.emotionalTone,
            engagementLevel: analysis.engagementLevel
        )
    }
    
    // MARK: - Private Helpers
    
    private func buildTitleContext(questions: [String], book: Book?) -> String {
        var context = ""
        
        if let book = book {
            context += "Book: \(book.title) by \(book.author)\n"
        }
        
        // Identify primary topic
        let topics = identifyTopics(from: questions)
        if !topics.isEmpty {
            context += "Main topics: \(topics.joined(separator: ", "))\n"
        }
        
        return context
    }
    
    private func cleanTitle(_ title: String) -> String {
        // Remove quotes, extra whitespace, and limit length
        var cleaned = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
        
        // Limit to 50 characters
        if cleaned.count > 50 {
            cleaned = String(cleaned.prefix(47)) + "..."
        }
        
        // Ensure it's not empty
        if cleaned.isEmpty {
            cleaned = "Reading Session"
        }
        
        return cleaned
    }
    
    private func fallbackTitle(for questions: [String], book: Book?) -> String {
        // Smart fallback based on question patterns
        let firstQuestion = questions.first?.lowercased() ?? ""
        
        if firstQuestion.contains("character") {
            return "Character Analysis"
        } else if firstQuestion.contains("theme") {
            return "Exploring Themes"
        } else if firstQuestion.contains("plot") || firstQuestion.contains("happen") {
            return "Plot Discussion"
        } else if firstQuestion.contains("ending") {
            return "About the Ending"
        } else if firstQuestion.contains("symbol") {
            return "Symbolism & Meaning"
        } else if let book = book {
            return "Reading \(book.title)"
        } else {
            return "Reading Session"
        }
    }
    
    private func identifyTopics(from questions: [String]) -> [String] {
        var topics: Set<String> = []
        
        for question in questions {
            let lower = question.lowercased()
            
            if lower.contains("character") || lower.contains("who is") {
                topics.insert("Characters")
            }
            if lower.contains("theme") || lower.contains("meaning") {
                topics.insert("Themes")
            }
            if lower.contains("plot") || lower.contains("happen") {
                topics.insert("Plot")
            }
            if lower.contains("symbol") {
                topics.insert("Symbolism")
            }
            if lower.contains("ending") || lower.contains("conclusion") {
                topics.insert("Ending")
            }
            if lower.contains("setting") || lower.contains("where") {
                topics.insert("Setting")
            }
            if lower.contains("style") || lower.contains("writing") {
                topics.insert("Writing Style")
            }
        }
        
        return Array(topics).sorted()
    }
    
    private func analyzeConversation(messages: [UnifiedChatMessage]) -> ConversationAnalysis {
        let questions = messages.filter { $0.isUser }
        let responses = messages.filter { !$0.isUser }
        
        // Calculate engagement metrics
        let avgQuestionLength = questions.isEmpty ? 0 :
            questions.map { $0.content.count }.reduce(0, +) / questions.count
        
        let avgResponseLength = responses.isEmpty ? 0 :
            responses.map { $0.content.count }.reduce(0, +) / responses.count
        
        // Determine emotional tone
        let tone = determineEmotionalTone(from: messages)
        
        // Calculate engagement level
        let engagement = calculateEngagement(
            questionCount: questions.count,
            avgQuestionLength: avgQuestionLength,
            avgResponseLength: avgResponseLength
        )
        
        return ConversationAnalysis(
            questionCount: questions.count,
            responseCount: responses.count,
            avgQuestionLength: avgQuestionLength,
            avgResponseLength: avgResponseLength,
            emotionalTone: tone,
            engagementLevel: engagement
        )
    }
    
    private func determineEmotionalTone(from messages: [UnifiedChatMessage]) -> String {
        let content = messages.map { $0.content }.joined(separator: " ").lowercased()
        
        // Simple keyword-based tone detection
        if content.contains("love") || content.contains("beautiful") || content.contains("amazing") {
            return "Enthusiastic"
        } else if content.contains("confused") || content.contains("don't understand") {
            return "Curious"
        } else if content.contains("sad") || content.contains("tragic") {
            return "Reflective"
        } else if content.contains("exciting") || content.contains("thrilling") {
            return "Engaged"
        } else {
            return "Analytical"
        }
    }
    
    private func calculateEngagement(
        questionCount: Int,
        avgQuestionLength: Int,
        avgResponseLength: Int
    ) -> String {
        let score = (questionCount * 10) + (avgQuestionLength / 10) + (avgResponseLength / 50)
        
        switch score {
        case 0..<20: return "Light"
        case 20..<50: return "Moderate"
        case 50..<100: return "High"
        default: return "Deep Dive"
        }
    }
    
    private func generateInsights(
        from messages: [UnifiedChatMessage],
        book: Book?
    ) async -> [String] {
        // Extract key points from the conversation
        var insights: [String] = []
        
        // Find the most discussed topics
        let topics = extractThemes(from: messages)
        if !topics.isEmpty {
            insights.append("Explored \(topics.count) main topics")
        }
        
        // Note any repeated themes
        let questions = messages.filter { $0.isUser }.map { $0.content }
        let repeatedThemes = findRepeatedThemes(in: questions)
        if !repeatedThemes.isEmpty {
            insights.append("Deep interest in: \(repeatedThemes.joined(separator: ", "))")
        }
        
        // Reading progress insight
        if let book = book, let pageCount = book.pageCount, pageCount > 0 {
            let progress = Double(book.currentPage) / Double(pageCount) * 100
            insights.append("\(Int(progress))% through the book")
        }
        
        return insights
    }
    
    private func extractThemes(from messages: [UnifiedChatMessage]) -> [String] {
        return identifyTopics(from: messages.filter { $0.isUser }.map { $0.content })
    }
    
    private func findRepeatedThemes(in questions: [String]) -> [String] {
        var themeCounts: [String: Int] = [:]
        
        for question in questions {
            let themes = identifyTopics(from: [question])
            for theme in themes {
                themeCounts[theme, default: 0] += 1
            }
        }
        
        // Return themes mentioned more than once
        return themeCounts
            .filter { $0.value > 1 }
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }
    
    private func calculateBookProgress(session: OptimizedAmbientSession) -> BookProgress? {
        guard let book = session.bookContext,
              let pageCount = book.pageCount,
              pageCount > 0 else { return nil }
        
        let startPage = 0  // We don't track startPage in OptimizedAmbientSession
        let currentPage = book.currentPage
        let pagesRead = currentPage - startPage
        let percentComplete = Double(currentPage) / Double(pageCount) * 100
        
        return BookProgress(
            pagesRead: pagesRead,
            currentPage: currentPage,
            totalPages: pageCount,
            percentComplete: percentComplete
        )
    }
}

// MARK: - Supporting Types

struct ChatSessionSummary {
    let title: String
    let duration: TimeInterval
    let messageCount: Int
    let questionsAsked: Int
    let topicsExplored: [String]
    let keyInsights: [String]
    let bookProgress: BookProgress?
    let emotionalTone: String
    let engagementLevel: String
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
}

struct ConversationAnalysis {
    let questionCount: Int
    let responseCount: Int
    let avgQuestionLength: Int
    let avgResponseLength: Int
    let emotionalTone: String
    let engagementLevel: String
}

struct BookProgress {
    let pagesRead: Int
    let currentPage: Int
    let totalPages: Int
    let percentComplete: Double
}