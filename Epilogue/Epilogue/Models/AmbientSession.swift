import Foundation
import SwiftUI
import SwiftData

// MARK: - Ambient Session Model
@Model
final class AmbientSession {
    @Attribute(.unique) var id: UUID = UUID()
    var startTime: Date
    var endTime: Date
    var bookModel: BookModel?
    var currentChapter: Int?
    var currentPage: Int?
    
    // Transient property for Book
    @Transient var book: Book? {
        // Convert BookModel to Book if needed
        return nil
    }
    
    // Raw content
    var transcriptSegments: [TranscriptSegment] = []
    var processedContent: [ProcessedContent] = []
    
    // Captured items (relationships to SwiftData models)
    var capturedQuotes: [CapturedQuote] = []
    var capturedNotes: [CapturedNote] = []
    var capturedQuestions: [CapturedQuestion] = []
    
    // Computed properties
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var questions: [CapturedQuestion] {
        capturedQuestions
    }
    
    var quotes: [CapturedQuote] {
        capturedQuotes
    }
    
    var notes: [CapturedNote] {
        capturedNotes
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
        content.append(contentsOf: capturedQuotes)
        content.append(contentsOf: capturedNotes)
        return content
    }
    
    init(startTime: Date = Date(), bookModel: BookModel? = nil) {
        self.startTime = startTime
        self.endTime = startTime
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
        for question in capturedQuestions {
            let words = question.content.split(separator: " ")
            for word in words {
                let key = String(word).lowercased()
                // Filter for meaningful words (not common words)
                if key.count > 4 && !commonWords.contains(key) {
                    topics[key, default: 0] += 1
                }
            }
        }
        
        // Sort by frequency and take top 5
        return topics.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key.capitalized }
    }
    
    private func groupConversations() -> [ConversationThread] {
        var threads: [ConversationThread] = []
        var currentThread: ConversationThread?
        
        // Group questions with their responses
        for (index, question) in capturedQuestions.enumerated() {
            let thread = ConversationThread(
                id: question.id.uuidString,
                index: index,
                title: question.content,
                icon: "questionmark.circle",
                iconColor: .blue,
                messages: [question.content],
                aiResponse: question.answer,
                timestamp: question.timestamp,
                suggestedFollowUps: generateFollowUps(for: question)
            )
            threads.append(thread)
        }
        
        return threads
    }
    
    private func generateFollowUps(for question: CapturedQuestion) -> [String] {
        // Generate contextual follow-up questions
        var followUps: [String] = []
        
        let content = question.content.lowercased()
        
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
        if let lastQuestion = capturedQuestions.last {
            if lastQuestion.content.contains("character") {
                suggestions.append("Explore character relationships")
            }
            if lastQuestion.content.contains("theme") {
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
    var id: UUID { get }
    var timestamp: Date { get }
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