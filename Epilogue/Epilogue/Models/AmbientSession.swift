import Foundation
import SwiftUI
import SwiftData

// MARK: - Ambient Session Model
@Model
final class AmbientSession {
    var id: UUID? = UUID()
    var startTime: Date? = Date()
    var endTime: Date? = Date()
    var bookModel: BookModel?
    var currentChapter: Int?
    var currentPage: Int?
    var generatedInsight: String?  // Cache the AI-generated insight

    // Transient property for Book
    @Transient var book: Book? {
        // Convert BookModel to Book if needed
        return nil
    }
    
    // Raw content - Store as Data for CloudKit
    @Transient var transcriptSegments: [TranscriptSegment] = []
    @Transient var processedContent: [ProcessedContent] = []
    
    // Captured items (relationships to SwiftData models)
    var capturedQuotes: [CapturedQuote]? = []
    var capturedNotes: [CapturedNote]? = []
    var capturedQuestions: [CapturedQuestion]? = []
    
    // Computed properties
    var duration: TimeInterval {
        guard let startTime = startTime, let endTime = endTime else { return 0 }
        return endTime.timeIntervalSince(startTime)
    }
    
    var questions: [CapturedQuestion] {
        capturedQuestions ?? []
    }
    
    var quotes: [CapturedQuote] {
        capturedQuotes ?? []
    }
    
    var notes: [CapturedNote] {
        capturedNotes ?? []
    }
    
    var keyTopics: [String] {
        // Extract key topics from content
        extractKeyTopics()
    }
    
    var groupedThreads: [ConversationThread] {
        // Group related conversations into threads
        groupConversations()
    }
    
    var suggestedContinuations: [String] {
        // Generate smart follow-up suggestions
        generateSuggestions()
    }
    
    var capturedContent: [any CapturedContent] {
        var content: [any CapturedContent] = []
        content.append(contentsOf: capturedQuotes ?? [])
        content.append(contentsOf: capturedNotes ?? [])
        return content
    }
    
    init(startTime: Date = Date(), bookModel: BookModel? = nil) {
        self.startTime = startTime
        self.endTime = Date() // Set to current time, will be updated when session ends
        self.bookModel = bookModel
    }
    
    convenience init(book: Book?) {
        self.init(startTime: Date())
        if let book = book {
            // Create or find BookModel
            self.bookModel = BookModel(from: book)
        }
    }
    
    // MARK: - Content Processing
    private func extractKeyTopics() -> [String] {
        var topics: [String: Int] = [:]
        
        // Analyze questions for topics
        for question in capturedQuestions ?? [] {
            if let content = question.content {
                let words = content.split(separator: " ")
                for word in words {
                    let key = String(word).lowercased()
                    // Filter for meaningful words (not common words)
                    if key.count > 4 && !commonWords.contains(key) {
                        topics[key, default: 0] += 1
                    }
                }
            }
        }
        
        // Analyze quotes and notes too
        for quote in capturedQuotes ?? [] {
            if let text = quote.text {
                extractTopicsFromText(text, into: &topics)
            }
        }
        
        for note in capturedNotes ?? [] {
            if let content = note.content {
                extractTopicsFromText(content, into: &topics)
            }
        }
        
        // Sort by frequency and take top 5
        return topics.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key.capitalized }
    }
    
    private func extractTopicsFromText(_ text: String, into topics: inout [String: Int]) {
        let words = text.split(separator: " ")
        for word in words {
            let key = String(word).lowercased().trimmingCharacters(in: .punctuationCharacters)
            // Filter for meaningful words (not common words)
            if key.count > 4 && !commonWords.contains(key) {
                topics[key, default: 0] += 1
            }
        }
    }
    
    private func groupConversations() -> [ConversationThread] {
        var threads: [ConversationThread] = []
        
        // Group questions with their responses
        for (index, question) in (capturedQuestions ?? []).enumerated() {
            let thread = ConversationThread(
                id: question.id?.uuidString ?? UUID().uuidString,
                index: index,
                title: question.content ?? "",
                icon: "questionmark.circle",
                iconColor: .blue,
                messages: [question.content ?? ""],
                aiResponse: question.answer,
                timestamp: question.timestamp ?? Date(),
                suggestedFollowUps: generateFollowUps(for: question)
            )
            threads.append(thread)
        }
        
        return threads
    }
    
    private func generateFollowUps(for question: CapturedQuestion) -> [String] {
        // Generate contextual follow-up questions
        var followUps: [String] = []
        
        let content = (question.content ?? "").lowercased()
        
        // Character questions
        if content.contains("who") || content.contains("character") {
            followUps.append("Tell me more about their motivations")
            followUps.append("How do they change throughout the story?")
        }
        
        // Theme questions
        if content.contains("theme") || content.contains("meaning") {
            followUps.append("How does this relate to other themes?")
            followUps.append("Can you give specific examples?")
        }
        
        // Comparison questions
        if content.contains("different") || content.contains("compare") {
            followUps.append("What are the key similarities?")
            followUps.append("Which interpretation do you prefer?")
        }
        
        return Array(followUps.prefix(2))
    }
    
    private func generateSuggestions() -> [String] {
        var suggestions: [String] = []
        
        // Based on recent topics
        if let lastQuestion = capturedQuestions?.last {
            if let content = lastQuestion.content, content.contains("character") {
                suggestions.append("Explore character relationships")
            }
            if let content = lastQuestion.content, content.contains("theme") {
                suggestions.append("Discuss symbolism")
            }
        }
        
        // Based on book progress
        if let chapter = currentChapter {
            suggestions.append("What happens in Chapter \(chapter + 1)?")
        }
        
        // Generic helpful suggestions
        suggestions.append("Summarize this session")
        suggestions.append("Key takeaways")
        
        return Array(suggestions.prefix(3))
    }
    
    // MARK: - AI-Powered Session Analysis
    
    func generateSessionInsights() async -> SessionInsights {
        
        // Use Foundation Models if available
        let isAvailable = await MainActor.run { AIFoundationModelsManager.shared.isAvailable }
        if isAvailable {
            let capturesText = formatAllCaptures()
            
            let prompt = """
            Analyze this reading session and provide insights:
            
            Book: \(bookModel?.title ?? "Unknown")
            Duration: \(Int(duration / 60)) minutes
            
            Content captured:
            \(capturesText)
            
            Provide:
            1. The dominant theme explored
            2. The emotional arc of the session
            3. A key realization or insight
            4. Connections between different captures
            5. A suggested reflection question
            """
            
            let response = await AIFoundationModelsManager.shared.processQuery(
                prompt,
                bookContext: nil
            )
            
            return parseSessionInsights(from: response)
        }
        
        // Fallback to basic analysis
        return generateBasicInsights()
    }
    
    private func formatAllCaptures() -> String {
        var text = ""
        
        // Add questions
        if let questions = capturedQuestions, !questions.isEmpty {
            text += "Questions asked:\n"
            for (i, question) in questions.enumerated() {
                text += "\(i + 1). \(question.content ?? "")\n"
            }
            text += "\n"
        }
        
        // Add quotes
        if let quotes = capturedQuotes, !quotes.isEmpty {
            text += "Quotes captured:\n"
            for quote in quotes {
                text += "• \"\(quote.text ?? "")\"\n"
            }
            text += "\n"
        }
        
        // Add notes
        if let notes = capturedNotes, !notes.isEmpty {
            text += "Notes taken:\n"
            for note in notes {
                text += "• \(note.content ?? "")\n"
            }
        }
        
        return text
    }
    
    private func parseSessionInsights(from response: String) -> SessionInsights {
        // Basic parsing - enhance as needed
        let defaultInsights = SessionInsights(
            dominantTheme: "Exploration and discovery",
            emotionalArc: "Started curious, ended thoughtful",
            keyRealization: nil,
            connectionsFound: [],
            suggestedReflection: "What resonated most with you from this session?"
        )
        
        // Parse the AI response for structured data
        var theme = defaultInsights.dominantTheme
        let arc = defaultInsights.emotionalArc
        let realization: String? = nil
        let connections: [String] = []
        let reflection = defaultInsights.suggestedReflection
        
        let lines = response.components(separatedBy: .newlines)
        for line in lines {
            if line.lowercased().contains("theme") {
                theme = line.replacingOccurrences(of: "theme:", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
            }
            // Add more parsing as needed
        }
        
        return SessionInsights(
            dominantTheme: theme,
            emotionalArc: arc,
            keyRealization: realization,
            connectionsFound: connections,
            suggestedReflection: reflection
        )
    }
    
    private func generateBasicInsights() -> SessionInsights {
        let topics = keyTopics
        let theme = topics.first ?? "Reading and reflection"
        
        let questionCount = (capturedQuestions ?? []).count
        let quoteCount = (capturedQuotes ?? []).count
        let noteCount = (capturedNotes ?? []).count
        
        var emotionalArc = "Engaged throughout"
        if questionCount > 5 {
            emotionalArc = "Started curious, grew more inquisitive"
        } else if quoteCount > noteCount {
            emotionalArc = "Focused on memorable passages"
        }
        
        return SessionInsights(
            dominantTheme: theme,
            emotionalArc: emotionalArc,
            keyRealization: nil,
            connectionsFound: [],
            suggestedReflection: "What surprised you most in this reading session?"
        )
    }
}

// MARK: - Session Insights
struct SessionInsights {
    let dominantTheme: String
    let emotionalArc: String // "Started curious, ended contemplative"
    let keyRealization: String?
    let connectionsFound: [String] // Links between captures
    let suggestedReflection: String
}

// MARK: - Conversation Thread
struct ConversationThread: Identifiable {
    let id: String
    let index: Int
    let title: String
    let icon: String
    let iconColor: Color
    let messages: [String]
    let aiResponse: String?
    let timestamp: Date
    let suggestedFollowUps: [String]
}

// MARK: - Transcript Segment
struct TranscriptSegment: Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let speaker: Speaker
    let confidence: Float
    
    enum Speaker: String, Codable {
        case user
        case ai
        case system
    }
}

// MARK: - Processed Content
struct ProcessedContent: Codable {
    let id: UUID
    let originalText: String
    let processedText: String
    let type: ContentType
    let entities: [String]
    let sentiment: Float
    let timestamp: Date
    
    enum ContentType: String, Codable {
        case question
        case quote
        case note
        case thought
        case reflection
    }
}

// MARK: - Captured Content Protocol
protocol CapturedContent {
    var id: UUID? { get }
    var timestamp: Date? { get }
}

// Make existing models conform to protocol
extension CapturedQuote: CapturedContent {}
extension CapturedNote: CapturedContent {}
extension CapturedQuestion: CapturedContent {}

// Common words to filter out
private let commonWords = Set([
    "the", "and", "for", "are", "but", "not", "you", "all", "can", "had",
    "her", "was", "one", "our", "out", "his", "has", "how", "its", "who",
    "will", "with", "what", "when", "where", "why", "this", "that", "these",
    "those", "been", "have", "from", "they", "were", "would", "could", "should"
])