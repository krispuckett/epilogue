import SwiftData
import Foundation

@Model
final class AIMessage {
    @Attribute(.unique) var id: UUID
    var role: Role
    var content: String
    var timestamp: Date
    var tokenCount: Int?
    var model: String?
    var error: String?
    
    var session: AISession?
    
    enum Role: String, Codable, CaseIterable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
        case function = "function"
    }
    
    init(
        role: Role,
        content: String,
        session: AISession,
        tokenCount: Int? = nil,
        model: String? = nil
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.session = session
        self.timestamp = Date()
        self.tokenCount = tokenCount
        self.model = model
        self.error = nil
    }
    
    var isFromUser: Bool {
        role == .user
    }
    
    var isFromAssistant: Bool {
        role == .assistant
    }
    
    var hasError: Bool {
        error != nil
    }
}