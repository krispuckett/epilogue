import Foundation
import SwiftData

// MARK: - Note Model

@Model
final class CapturedNote {
    var id: UUID
    var content: String
    var timestamp: Date
    var pageNumber: Int?
    var bookLocalId: String?
    var source: CaptureSource
    var tags: [String]
    
    // Relationship
    @Relationship(deleteRule: .nullify)
    var book: BookModel?
    
    init(
        content: String,
        book: BookModel? = nil,
        pageNumber: Int? = nil,
        timestamp: Date = Date(),
        source: CaptureSource = .manual,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.content = content
        self.book = book
        self.bookLocalId = book?.localId
        self.pageNumber = pageNumber
        self.timestamp = timestamp
        self.source = source
        self.tags = tags
    }
}

// MARK: - Quote Model

@Model
final class CapturedQuote {
    var id: UUID
    var text: String
    var author: String?
    var timestamp: Date
    var pageNumber: Int?
    var bookLocalId: String?
    var source: CaptureSource
    var notes: String? // User's notes about the quote
    
    // Relationship
    @Relationship(deleteRule: .nullify)
    var book: BookModel?
    
    init(
        text: String,
        book: BookModel? = nil,
        author: String? = nil,
        pageNumber: Int? = nil,
        timestamp: Date = Date(),
        source: CaptureSource = .manual,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.book = book
        self.bookLocalId = book?.localId
        self.author = author ?? book?.author
        self.pageNumber = pageNumber
        self.timestamp = timestamp
        self.source = source
        self.notes = notes
    }
}

// MARK: - Question Model

@Model
final class CapturedQuestion {
    var id: UUID
    var content: String
    var timestamp: Date
    var pageNumber: Int?
    var bookLocalId: String?
    var source: CaptureSource
    var isAnswered: Bool
    var answer: String?
    
    // Relationship
    @Relationship(deleteRule: .nullify)
    var book: BookModel?
    
    init(
        content: String,
        book: BookModel? = nil,
        pageNumber: Int? = nil,
        timestamp: Date = Date(),
        source: CaptureSource = .manual
    ) {
        self.id = UUID()
        self.content = content
        self.book = book
        self.bookLocalId = book?.localId
        self.pageNumber = pageNumber
        self.timestamp = timestamp
        self.source = source
        self.isAnswered = false
        self.answer = nil
    }
}

// MARK: - Supporting Types

enum CaptureSource: String, Codable, CaseIterable {
    case manual = "manual"
    case ambient = "ambient"
    case voice = "voice"
    case import_ = "import"
    
    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .ambient: return "Ambient"
        case .voice: return "Voice"
        case .import_: return "Import"
        }
    }
    
    var icon: String {
        switch self {
        case .manual: return "pencil"
        case .ambient: return "mic.fill"
        case .voice: return "waveform"
        case .import_: return "square.and.arrow.down"
        }
    }
}