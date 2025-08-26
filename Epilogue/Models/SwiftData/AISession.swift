import SwiftData
import Foundation

@Model
final class AISession {
    @Attribute(.unique) var id: UUID
    var title: String
    var dateCreated: Date
    var lastAccessed: Date
    var sessionType: SessionType
    var context: String? // Additional context about the session
    
    var book: Book?
    
    @Relationship(deleteRule: .cascade, inverse: \AIMessage.session)
    var messages: [AIMessage]?
    
    enum SessionType: String, Codable, CaseIterable {
        case discussion = "discussion"
        case summary = "summary"
        case analysis = "analysis"
        case questions = "questions"
        case characterAnalysis = "character_analysis"
        case themeExploration = "theme_exploration"
    }
    
    init(
        title: String,
        book: Book,
        sessionType: SessionType = .discussion,
        context: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.book = book
        self.dateCreated = Date()
        self.lastAccessed = Date()
        self.sessionType = sessionType
        self.context = context
        self.messages = []
    }
    
    func addMessage(role: AIMessage.Role, content: String) {
        let message = AIMessage(role: role, content: content, session: self)
        if messages == nil {
            messages = []
        }
        messages?.append(message)
        lastAccessed = Date()
    }
    
    var totalTokenCount: Int {
        messages?.reduce(0) { $0 + ($1.tokenCount ?? 0) } ?? 0
    }
    
    var messageCount: Int {
        messages?.count ?? 0
    }
}