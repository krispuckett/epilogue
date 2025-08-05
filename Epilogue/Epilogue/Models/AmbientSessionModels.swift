import Foundation

// MARK: - Extracted Content Models
// These models are used by ambient sessions and chat processing

struct ExtractedQuote {
    let text: String
    let context: String?
    let timestamp: Date
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
}

struct ExtractedQuestion {
    let text: String
    let context: String?
    let timestamp: Date
}