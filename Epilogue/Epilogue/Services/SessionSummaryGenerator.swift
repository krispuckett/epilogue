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

    // MARK: - Claude-Powered Session Reflection

    /// Generate a thoughtful, literary reflection on a reading session using Claude
    func generateClaudeReflection(
        session: OptimizedAmbientSession,
        messages: [UnifiedChatMessage],
        quotesCaptures: [String] = [],
        notesCreated: [String] = []
    ) async -> SessionReflection {
        isGenerating = true
        defer { isGenerating = false }

        let book = session.bookContext
        let duration = Date().timeIntervalSince(session.startTime)

        // Build rich context for Claude
        let conversationSummary = buildConversationSummary(messages: messages)
        let capturedContent = buildCapturedContent(quotes: quotesCaptures, notes: notesCreated)

        let systemPrompt = """
        You are a thoughtful reading companion reflecting on a reading session with a reader.
        Your role is to synthesize what was discussed, connect themes, and offer a warm, insightful reflection.

        Be genuine and literary, not generic. Connect the dots between their questions and the book's themes.
        Speak as if you're a well-read friend who genuinely cares about their reading experience.
        Keep it concise (2-3 short paragraphs max). No emojis.
        """

        let userPrompt = """
        Please reflect on this reading session for "\(book?.title ?? "a book")" by \(book?.author ?? "the author"):

        CONVERSATION TOPICS:
        \(conversationSummary)

        \(capturedContent.isEmpty ? "" : "QUOTES & NOTES CAPTURED:\n\(capturedContent)\n")

        SESSION DETAILS:
        - Duration: \(formatDuration(duration))
        - Questions asked: \(messages.filter { $0.isUser }.count)

        Generate a warm, insightful reflection that:
        1. Summarizes what themes or questions emerged
        2. Notes any interesting connections or insights from the conversation
        3. Offers a thought to carry forward into their next reading session

        Keep it personal and engaging, not academic.
        """

        do {
            let reflection = try await ClaudeService.shared.subscriberChat(
                message: userPrompt,
                systemPrompt: systemPrompt,
                maxTokens: 500
            )

            logger.info("✨ Generated Claude session reflection")

            return SessionReflection(
                text: reflection,
                themes: extractThemes(from: messages),
                duration: duration,
                questionCount: messages.filter { $0.isUser }.count,
                bookTitle: book?.title ?? "Reading Session",
                generatedAt: Date()
            )

        } catch {
            logger.error("Claude reflection failed: \(error), using fallback")
            return SessionReflection(
                text: generateFallbackReflection(messages: messages, book: book),
                themes: extractThemes(from: messages),
                duration: duration,
                questionCount: messages.filter { $0.isUser }.count,
                bookTitle: book?.title ?? "Reading Session",
                generatedAt: Date()
            )
        }
    }

    /// Generate a "What to watch for next" prompt using Claude
    func generateNextSessionPrompt(
        book: Book,
        currentProgress: Double,
        recentQuestions: [String]
    ) async -> String? {
        guard !recentQuestions.isEmpty else { return nil }

        let systemPrompt = """
        You are a reading companion. Based on what the reader has been curious about,
        suggest ONE thing to watch for in their next reading session.
        Be specific to this book and their interests. Keep it to 1-2 sentences.
        No spoilers beyond their current progress (\(Int(currentProgress * 100))%).
        """

        let userPrompt = """
        Book: "\(book.title)" by \(book.author)
        Progress: \(Int(currentProgress * 100))%
        Recent questions: \(recentQuestions.prefix(3).joined(separator: "; "))

        What's one thing they might watch for in their next reading session?
        """

        do {
            let suggestion = try await ClaudeService.shared.subscriberChat(
                message: userPrompt,
                systemPrompt: systemPrompt,
                maxTokens: 100
            )
            return suggestion
        } catch {
            logger.error("Failed to generate next session prompt: \(error)")
            return nil
        }
    }

    private func buildConversationSummary(messages: [UnifiedChatMessage]) -> String {
        let userQuestions = messages
            .filter { $0.isUser }
            .prefix(10)
            .map { "- \($0.content.prefix(100))" }
            .joined(separator: "\n")

        return userQuestions.isEmpty ? "No specific questions recorded" : userQuestions
    }

    private func buildCapturedContent(quotes: [String], notes: [String]) -> String {
        var content: [String] = []
        if !quotes.isEmpty {
            content.append("Quotes: \(quotes.prefix(3).joined(separator: "; "))")
        }
        if !notes.isEmpty {
            content.append("Notes: \(notes.prefix(3).joined(separator: "; "))")
        }
        return content.joined(separator: "\n")
    }

    private func generateFallbackReflection(messages: [UnifiedChatMessage], book: Book?) -> String {
        let questionCount = messages.filter { $0.isUser }.count
        let bookTitle = book?.title ?? "your book"

        if questionCount > 5 {
            return "You had a rich exploration of \(bookTitle) today, asking \(questionCount) questions. The curiosity you brought to this session is exactly what great reading looks like — keep following those threads."
        } else if questionCount > 0 {
            return "A thoughtful session with \(bookTitle). Every question you ask deepens your relationship with the text. See what emerges in your next reading."
        } else {
            return "Time spent with \(bookTitle) is time well spent. Looking forward to hearing what catches your attention next time."
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes < 1 {
            return "less than a minute"
        } else if minutes == 1 {
            return "about a minute"
        } else if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            } else {
                return "\(hours) hour\(hours > 1 ? "s" : "") and \(remainingMinutes) minutes"
            }
        }
    }

    // MARK: - Session Reflection Model

    struct SessionReflection {
        let text: String
        let themes: [String]
        let duration: TimeInterval
        let questionCount: Int
        let bookTitle: String
        let generatedAt: Date
    }
    
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