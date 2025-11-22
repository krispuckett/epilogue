import Foundation
import SwiftData

// MARK: - Note Model

@Model
final class CapturedNote {
    var id: UUID? = UUID()
    var content: String? = ""
    var contentFormat: String? = "plaintext"  // "markdown" or "plaintext"
    var timestamp: Date? = Date()
    var pageNumber: Int?
    var bookLocalId: String?
    var source: String? = CaptureSource.manual.rawValue  // Store as String for CloudKit
    var tags: [String]? = []
    var isFavorite: Bool? = false

    // Relationships
    @Relationship(deleteRule: .nullify)
    var book: BookModel?

    @Relationship(inverse: \AmbientSession.capturedNotes)
    var ambientSession: AmbientSession?

    // Computed property for CaptureSource
    var captureSource: CaptureSource {
        CaptureSource(rawValue: source ?? CaptureSource.manual.rawValue) ?? .manual
    }

    // Computed property for content format type
    var isMarkdown: Bool {
        contentFormat == "markdown"
    }

    // Helper to mark note as having markdown content
    func markAsMarkdown() {
        contentFormat = "markdown"
    }

    init(
        content: String,
        book: BookModel? = nil,
        pageNumber: Int? = nil,
        timestamp: Date = Date(),
        source: CaptureSource = .manual,
        tags: [String] = [],
        contentFormat: String = "plaintext"
    ) {
        self.id = UUID()
        self.content = content
        self.contentFormat = contentFormat
        self.book = book
        self.bookLocalId = book?.localId
        self.pageNumber = pageNumber
        self.timestamp = timestamp
        self.source = source.rawValue  // Store as String
        self.tags = tags
    }
}

// MARK: - Quote Model

@Model
final class CapturedQuote {
    var id: UUID? = UUID()
    var text: String? = ""
    var author: String?
    var timestamp: Date? = Date()
    var pageNumber: Int?
    var bookLocalId: String?
    var source: String? = CaptureSource.manual.rawValue  // Store as String for CloudKit
    var notes: String? // User's notes about the quote
    var isFavorite: Bool? = false
    var exportedToReadwise: Bool = false  // Track if synced to Readwise
    var additionalNotes: String? // Additional notes for the quote

    // Relationships
    @Relationship(deleteRule: .nullify)
    var book: BookModel?
    
    @Relationship(inverse: \AmbientSession.capturedQuotes)
    var ambientSession: AmbientSession?
    
    // Computed property for CaptureSource
    var captureSource: CaptureSource {
        CaptureSource(rawValue: source ?? CaptureSource.manual.rawValue) ?? .manual
    }
    
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
        self.source = source.rawValue  // Store as String
        self.notes = notes
        self.exportedToReadwise = false
        self.additionalNotes = nil
    }
}

// MARK: - Question Model

@Model
final class CapturedQuestion {
    var id: UUID? = UUID()
    var content: String? = ""
    var timestamp: Date? = Date()
    var pageNumber: Int?
    var bookLocalId: String?
    var source: String? = CaptureSource.manual.rawValue  // Store as String for CloudKit
    var isAnswered: Bool? = false
    var answer: String?
    
    // Relationships
    @Relationship(deleteRule: .nullify)
    var book: BookModel?
    
    @Relationship(inverse: \AmbientSession.capturedQuestions)
    var ambientSession: AmbientSession?
    
    // Computed property for CaptureSource
    var captureSource: CaptureSource {
        CaptureSource(rawValue: source ?? CaptureSource.manual.rawValue) ?? .manual
    }
    
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
        self.source = source.rawValue  // Store as String
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