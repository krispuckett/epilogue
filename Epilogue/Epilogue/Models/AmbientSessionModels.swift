import Foundation
import SwiftUI

// MARK: - Optimized Session Content Models

struct SessionContent: Identifiable, Codable {
    let id: UUID
    let type: ContentType
    let text: String
    let timestamp: Date
    let confidence: Float
    let bookContext: String?
    let aiResponse: AISessionResponse?
    
    init(type: ContentType, text: String, timestamp: Date, confidence: Float, bookContext: String? = nil, aiResponse: AISessionResponse? = nil) {
        self.id = UUID()
        self.type = type
        self.text = text
        self.timestamp = timestamp
        self.confidence = confidence
        self.bookContext = bookContext
        self.aiResponse = aiResponse
    }
    
    enum ContentType: String, Codable, CaseIterable {
        case question = "question"
        case quote = "quote"
        case reflection = "reflection"
        case insight = "insight"
        case connection = "connection"
        case reaction = "reaction"
        
        var icon: String {
            switch self {
            case .question: return "questionmark.circle.fill"
            case .quote: return "quote.bubble.fill"
            case .reflection: return "brain.head.profile"
            case .insight: return "lightbulb.fill"
            case .connection: return "link.circle.fill"
            case .reaction: return "heart.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .question: return .blue
            case .quote: return .green
            case .reflection: return .purple
            case .insight: return .orange
            case .connection: return .mint
            case .reaction: return .pink
            }
        }
    }
}

struct AISessionResponse: Identifiable, Codable {
    let id: UUID
    let question: String
    let answer: String
    let model: String
    let confidence: Float
    let responseTime: TimeInterval
    let timestamp: Date
    let isStreamed: Bool
    let wasFromCache: Bool
    
    init(question: String, answer: String, model: String, confidence: Float, responseTime: TimeInterval, timestamp: Date, isStreamed: Bool, wasFromCache: Bool) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.model = model
        self.confidence = confidence
        self.responseTime = responseTime
        self.timestamp = timestamp
        self.isStreamed = isStreamed
        self.wasFromCache = wasFromCache
    }
}

struct SessionCluster: Identifiable, Codable {
    let id: UUID
    let topic: String
    let content: [SessionContent]
    let timestamp: Date
    let bookContext: String?
    let mood: SessionMood
    
    init(topic: String, content: [SessionContent], timestamp: Date, bookContext: String? = nil, mood: SessionMood) {
        self.id = UUID()
        self.topic = topic
        self.content = content
        self.timestamp = timestamp
        self.bookContext = bookContext
        self.mood = mood
    }
    
    var duration: TimeInterval {
        guard let first = content.first?.timestamp,
              let last = content.last?.timestamp else {
            return 0
        }
        return last.timeIntervalSince(first)
    }
    
    var questionCount: Int {
        content.filter { $0.type == .question }.count
    }
    
    var aiResponseCount: Int {
        content.compactMap { $0.aiResponse }.count
    }
}

struct OptimizedAmbientSession: Identifiable {
    let id = UUID()
    let startTime: Date
    var endTime: Date?
    let bookContext: Book?
    var title: String = "Reading Session"  // Added title property
    var clusters: [SessionCluster] = []
    var rawTranscriptions: [String] = []
    var allContent: [SessionContent] = []
    var metadata: SessionMetadata
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    var isActive: Bool {
        endTime == nil
    }
    
    var totalQuestions: Int {
        allContent.filter { $0.type == .question }.count
    }
    
    var totalAIResponses: Int {
        allContent.compactMap { $0.aiResponse }.count
    }
    
    var averageResponseTime: TimeInterval {
        let responseTimes = allContent.compactMap { $0.aiResponse?.responseTime }
        return responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
    }
    
    var cacheHitRate: Float {
        let responses = allContent.compactMap { $0.aiResponse }
        let cacheHits = responses.filter { $0.wasFromCache }.count
        return responses.isEmpty ? 0 : Float(cacheHits) / Float(responses.count)
    }
}

enum SessionMood: String, Codable, CaseIterable {
    case positive = "positive"
    case thoughtful = "thoughtful"
    case challenging = "challenging"
    case neutral = "neutral"
    case excited = "excited"
    case confused = "confused"
    
    var color: Color {
        switch self {
        case .positive: return .green
        case .thoughtful: return .blue
        case .challenging: return .orange
        case .neutral: return .gray
        case .excited: return .yellow
        case .confused: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .positive: return "face.smiling"
        case .thoughtful: return "brain"
        case .challenging: return "exclamationmark.triangle"
        case .neutral: return "circle"
        case .excited: return "star.fill"
        case .confused: return "questionmark.diamond"
        }
    }
}

struct SessionMetadata: Codable {
    var wordCount: Int = 0
    var readingSpeed: Float = 0 // words per minute
    var engagementScore: Float = 0 // based on reactions and questions
    var comprehensionScore: Float = 0 // based on question complexity
    var mood: SessionMood = .neutral
    var topics: [String] = []
    var difficulty: DifficultyLevel = .medium
    var sessionType: SessionType = .casual
    
    enum DifficultyLevel: String, Codable, CaseIterable {
        case easy = "easy"
        case medium = "medium"
        case challenging = "challenging"
        case complex = "complex"
        
        var color: Color {
            switch self {
            case .easy: return .green
            case .medium: return .blue
            case .challenging: return .orange
            case .complex: return .red
            }
        }
    }
    
    enum SessionType: String, Codable, CaseIterable {
        case casual = "casual"
        case focused = "focused"
        case analytical = "analytical"
        case exploratory = "exploratory"
        
        var description: String {
            switch self {
            case .casual: return "Light reading with occasional questions"
            case .focused: return "Deep focus with minimal interruptions"
            case .analytical: return "Critical analysis with many questions"
            case .exploratory: return "Discovery reading with broad curiosity"
            }
        }
    }
}

// MARK: - Legacy Support (for backward compatibility)

struct ExtractedQuote {
    let text: String
    let context: String?
    let timestamp: Date
    
    func toSessionContent() -> SessionContent {
        SessionContent(
            type: .quote,
            text: text,
            timestamp: timestamp,
            confidence: 0.8,
            bookContext: context,
            aiResponse: nil
        )
    }
}

struct ExtractedNote {
    let text: String
    let type: NoteType
    let timestamp: Date
    let emotionalContext: String?
    
    init(text: String, type: NoteType, timestamp: Date, emotionalContext: String? = nil) {
        self.text = text
        self.type = type
        self.timestamp = timestamp
        self.emotionalContext = emotionalContext
    }
    
    enum NoteType {
        case reflection
        case insight
        case connection
    }
    
    func toSessionContent() -> SessionContent {
        let contentType: SessionContent.ContentType = switch type {
        case .reflection: .reflection
        case .insight: .insight
        case .connection: .connection
        }
        
        return SessionContent(
            type: contentType,
            text: text,
            timestamp: timestamp,
            confidence: 0.8,
            bookContext: emotionalContext,
            aiResponse: nil
        )
    }
}

struct ExtractedQuestion {
    let text: String
    let context: String?
    let timestamp: Date
    let response: String?  // AI response to the question
    
    func toSessionContent(with aiResponse: AISessionResponse? = nil) -> SessionContent {
        SessionContent(
            type: .question,
            text: text,
            timestamp: timestamp,
            confidence: 0.8,
            bookContext: context,
            aiResponse: aiResponse
        )
    }
}