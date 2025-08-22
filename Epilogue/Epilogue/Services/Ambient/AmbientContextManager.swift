import Foundation
import SwiftData
import Observation

// MARK: - Ambient Context Manager
/// Manages rich context for AI responses to make them feel incredibly intelligent
@MainActor
@Observable
class AmbientContextManager {
    static let shared = AmbientContextManager()
    
    // MARK: - Reading Context
    var currentPage: Int?
    var currentChapter: String?
    var readingProgress: Double = 0.0
    var timeOnCurrentPage: TimeInterval = 0
    private var pageStartTime: Date?
    
    // MARK: - Conversation Context
    private var recentTopics: [String] = []  // Last 5 topics discussed
    private var charactersMentioned: Set<String> = []
    private var plotPointsDiscussed: Set<String> = []
    private var themesExplored: Set<String> = []
    
    // MARK: - User Patterns
    private var questionPatterns: [QuestionPattern] = []
    private var readingPace: ReadingPace = .moderate
    private var preferredResponseLength: ResponseLength = .detailed
    
    // MARK: - Book-Specific Knowledge
    private var bookKnowledge: BookKnowledge?
    
    struct QuestionPattern {
        let type: String  // "character", "plot", "theme", "quotes"
        let frequency: Int
        let lastAsked: Date
    }
    
    enum ReadingPace {
        case slow, moderate, fast
    }
    
    enum ResponseLength {
        case concise, balanced, detailed
    }
    
    struct BookKnowledge {
        let title: String
        let author: String
        let genre: String
        let themes: [String]
        let mainCharacters: [String]
        let setting: String
        let publicationYear: Int?
        
        // Dynamic knowledge built from conversation
        var userInsights: [String] = []
        var favoriteCharacters: [String] = []
        var confusingParts: [String] = []
    }
    
    private init() {}
    
    // MARK: - Context Building
    
    /// Builds rich context for the AI to provide incredibly relevant responses
    func buildEnhancedContext(for question: String, book: Book?) -> String {
        var contextParts: [String] = []
        
        // 1. Current Reading Context
        if let book = book {
            contextParts.append("Reading '\(book.title)' by \(book.author)")
            
            if let page = currentPage {
                contextParts.append("Currently on page \(page)")
                
                // Add pace context
                if timeOnCurrentPage > 300 {  // More than 5 minutes on same page
                    contextParts.append("(Reader spending time on this page - might be complex or interesting)")
                }
            }
            
            if let pageCount = book.pageCount, pageCount > 0 {
                let progress = Double(book.currentPage) / Double(pageCount)
                let percentage = Int(progress * 100)
                contextParts.append("Progress: \(percentage)% complete")
                
                // Add context based on progress
                if progress < 0.2 {
                    contextParts.append("Early in the book - avoid major spoilers")
                } else if progress > 0.8 {
                    contextParts.append("Near the end - can discuss most plot points")
                }
            }
        }
        
        // 2. Recent Conversation Context
        if !recentTopics.isEmpty {
            contextParts.append("Recent topics: \(recentTopics.suffix(3).joined(separator: ", "))")
        }
        
        if !charactersMentioned.isEmpty {
            contextParts.append("Characters discussed: \(Array(charactersMentioned.prefix(5)).joined(separator: ", "))")
        }
        
        // 3. Question Pattern Recognition
        let questionLower = question.lowercased()
        
        // Detect follow-up questions
        if questionLower.contains("what about") || 
           questionLower.contains("and") ||
           questionLower.contains("also") ||
           questionLower.contains("more about") {
            contextParts.append("This appears to be a follow-up question - reference previous answer")
        }
        
        // Detect comparison questions
        if questionLower.contains("similar") || 
           questionLower.contains("different") ||
           questionLower.contains("compare") ||
           questionLower.contains("versus") {
            contextParts.append("Comparison requested - provide clear contrasts")
        }
        
        // Detect depth indicators
        if questionLower.contains("why") || 
           questionLower.contains("how come") ||
           questionLower.contains("explain") {
            contextParts.append("Deep explanation requested - provide reasoning and context")
        }
        
        // 4. Adaptive Response Style
        switch preferredResponseLength {
        case .concise:
            contextParts.append("Keep response brief and to the point")
        case .balanced:
            contextParts.append("Provide a balanced response with key details")
        case .detailed:
            contextParts.append("Provide comprehensive, detailed response")
        }
        
        // 5. Smart Anticipation
        contextParts.append(contentsOf: anticipateFollowUps(for: question))
        
        return contextParts.joined(separator: "\n")
    }
    
    // MARK: - Smart Anticipation
    
    private func anticipateFollowUps(for question: String) -> [String] {
        var anticipations: [String] = []
        let questionLower = question.lowercased()
        
        // Character questions often lead to...
        if questionLower.contains("who is") {
            anticipations.append("Briefly mention their role and significance without spoilers")
            anticipations.append("Reader might ask about relationships or motivations next")
        }
        
        // Plot questions often lead to...
        if questionLower.contains("what happens") || questionLower.contains("what occurred") {
            anticipations.append("Focus on events up to reader's current progress")
            anticipations.append("Reader might ask 'why' or about consequences next")
        }
        
        // Theme questions often lead to...
        if questionLower.contains("theme") || questionLower.contains("meaning") {
            anticipations.append("Connect to specific examples from the book")
            anticipations.append("Reader might want to explore symbolism or author's intent")
        }
        
        // Quote questions often lead to...
        if questionLower.contains("quote") {
            anticipations.append("Provide context for when/why it was said")
            anticipations.append("Reader might ask about significance or interpretation")
        }
        
        return anticipations
    }
    
    // MARK: - Update Methods
    
    func updatePage(_ page: Int) {
        if currentPage != page {
            currentPage = page
            pageStartTime = Date()
            timeOnCurrentPage = 0
        }
    }
    
    func updateTimeOnPage() {
        if let startTime = pageStartTime {
            timeOnCurrentPage = Date().timeIntervalSince(startTime)
        }
    }
    
    func addTopic(_ topic: String) {
        recentTopics.append(topic)
        if recentTopics.count > 5 {
            recentTopics.removeFirst()
        }
    }
    
    func addCharacterMention(_ character: String) {
        charactersMentioned.insert(character)
    }
    
    func learnUserPreference(from response: String, feedback: UserFeedback?) {
        // Learn from response length preferences
        if let feedback = feedback {
            switch feedback {
            case .tooLong:
                preferredResponseLength = .concise
            case .tooShort:
                preferredResponseLength = .detailed
            case .justRight:
                // Keep current preference
                break
            }
        }
    }
    
    // MARK: - Smart Corrections
    
    /// Provides intelligent corrections for misheard transcriptions
    func suggestCorrection(for text: String, confidence: Float) -> String? {
        guard confidence < 0.7 else { return nil }
        
        let corrections = [
            "gone": "Gondor",
            "gollum": "Golem",
            "Aragon": "Aragorn",
            "Soron": "Sauron",
            "Freddo": "Frodo",
            "Gandolf": "Gandalf",
            "Bilbao": "Bilbo",
            "Borimir": "Boromir"
        ]
        
        let words = text.lowercased().split(separator: " ")
        var correctedWords: [String] = []
        var didCorrect = false
        
        for word in words {
            if let correction = corrections[String(word)] {
                correctedWords.append(correction)
                didCorrect = true
            } else {
                correctedWords.append(String(word))
            }
        }
        
        return didCorrect ? correctedWords.joined(separator: " ") : nil
    }
    
    // MARK: - Session Management
    
    func startReadingSession(book: Book) {
        // Reset session-specific data
        recentTopics.removeAll()
        charactersMentioned.removeAll()
        plotPointsDiscussed.removeAll()
        currentPage = nil
        timeOnCurrentPage = 0
        
        // Load book knowledge if available
        loadBookKnowledge(for: book)
    }
    
    private func loadBookKnowledge(for book: Book) {
        // This could be enhanced with a database of book metadata
        // For now, use basic info
        // Infer genre from title and description
        let titleAndDesc = (book.title + " " + (book.description ?? "")).lowercased()
        var genre = "Fiction"
        
        if titleAndDesc.contains("fantasy") || titleAndDesc.contains("magic") || titleAndDesc.contains("wizard") {
            genre = "Fantasy"
        } else if titleAndDesc.contains("mystery") || titleAndDesc.contains("detective") || titleAndDesc.contains("murder") {
            genre = "Mystery"
        } else if titleAndDesc.contains("romance") || titleAndDesc.contains("love") {
            genre = "Romance"
        } else if titleAndDesc.contains("science fiction") || titleAndDesc.contains("sci-fi") || titleAndDesc.contains("space") {
            genre = "Science Fiction"
        } else if titleAndDesc.contains("history") || titleAndDesc.contains("historical") {
            genre = "Historical"
        } else if titleAndDesc.contains("thriller") || titleAndDesc.contains("suspense") {
            genre = "Thriller"
        }
        
        bookKnowledge = BookKnowledge(
            title: book.title,
            author: book.author,
            genre: genre,
            themes: [],  // Could be populated from analysis
            mainCharacters: [],  // Could be extracted from previous conversations
            setting: "",  // Could be determined from context
            publicationYear: nil
        )
    }
    
    enum UserFeedback {
        case tooLong
        case tooShort
        case justRight
    }
}

// MARK: - Intelligent Response Timer
/// Adapts response timing based on question complexity
class AdaptiveResponseTimer {
    static func calculateDelay(for question: String) -> TimeInterval {
        let wordCount = question.split(separator: " ").count
        let hasComplexTerms = question.lowercased().contains(where: { char in
            ["why", "how", "explain", "analyze", "compare"].contains(where: {
                question.lowercased().contains($0)
            })
        })
        
        // Base delay
        var delay: TimeInterval = 1.5
        
        // Adjust based on complexity
        if wordCount > 10 {
            delay += 0.5
        }
        
        if hasComplexTerms {
            delay += 1.0
        }
        
        // Add natural variation (±20%)
        let variation = Double.random(in: 0.8...1.2)
        
        return min(delay * variation, 4.0)  // Cap at 4 seconds
    }
}