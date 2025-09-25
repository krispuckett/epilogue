import Foundation
import SwiftData

// MARK: - Legacy Models for Migration
// These are the old SwiftData models that we're migrating from
// They are defined here to avoid naming conflicts with the current models

@Model
final class LegacyBook {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var isbn: String?
    var coverImageData: Data?
    var dateAdded: Date
    var lastOpened: Date?
    var readingProgress: Double // 0.0 to 1.0
    var totalPages: Int?
    var currentPage: Int?
    var genre: String?
    var publicationYear: Int?
    var publisher: String?
    var bookDescription: String?
    var rating: Int? // 1-5 stars
    
    @Relationship(deleteRule: .cascade, inverse: \LegacyQuote.book)
    var quotes: [LegacyQuote]?
    
    @Relationship(deleteRule: .cascade, inverse: \LegacyNote.book)
    var notes: [LegacyNote]?
    
    @Relationship(deleteRule: .cascade, inverse: \LegacyAISession.book)
    var aiSessions: [LegacyAISession]?
    
    @Relationship(deleteRule: .cascade, inverse: \LegacyReadingSession.book)
    var readingSessions: [LegacyReadingSession]?
    
    init(
        title: String,
        author: String,
        isbn: String? = nil,
        coverImageData: Data? = nil,
        genre: String? = nil,
        publicationYear: Int? = nil,
        publisher: String? = nil,
        description: String? = nil,
        totalPages: Int? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.isbn = isbn
        self.coverImageData = coverImageData
        self.dateAdded = Date()
        self.lastOpened = nil
        self.readingProgress = 0.0
        self.totalPages = totalPages
        self.currentPage = 0
        self.genre = genre
        self.publicationYear = publicationYear
        self.publisher = publisher
        self.bookDescription = description
        self.rating = nil
        self.quotes = []
        self.notes = []
        self.aiSessions = []
        self.readingSessions = []
    }
}

@Model
final class LegacyQuote {
    @Attribute(.unique) var id: UUID
    var text: String
    var pageNumber: Int?
    var chapter: String?
    var dateCreated: Date
    var dateModified: Date
    var notes: String?
    var isFavorite: Bool
    var highlightColor: String?
    var tags: [String]
    
    var book: LegacyBook?
    
    var relatedNote: LegacyNote?
    
    init(
        text: String,
        book: LegacyBook,
        pageNumber: Int? = nil,
        chapter: String? = nil,
        notes: String? = nil,
        highlightColor: String? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.text = text
        self.book = book
        self.pageNumber = pageNumber
        self.chapter = chapter
        self.dateCreated = Date()
        self.dateModified = Date()
        self.notes = notes
        self.isFavorite = false
        self.highlightColor = highlightColor
        self.tags = tags
    }
}

@Model
final class LegacyNote {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var dateCreated: Date
    var dateModified: Date
    var tags: [String]
    var pageReference: Int?
    var chapterReference: String?
    var isPinned: Bool
    var attachmentData: [Data]? // For images or other attachments
    
    var book: LegacyBook?
    
    @Relationship(inverse: \LegacyQuote.relatedNote)
    var linkedQuotes: [LegacyQuote]?
    
    init(
        title: String,
        content: String,
        book: LegacyBook,
        tags: [String] = [],
        pageReference: Int? = nil,
        chapterReference: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.book = book
        self.dateCreated = Date()
        self.dateModified = Date()
        self.tags = tags
        self.pageReference = pageReference
        self.chapterReference = chapterReference
        self.isPinned = false
        self.attachmentData = []
        self.linkedQuotes = []
    }
}

@Model
final class LegacyAISession {
    @Attribute(.unique) var id: UUID
    var title: String
    var dateCreated: Date
    var lastAccessed: Date
    var sessionType: SessionType
    var context: String? // Additional context about the session
    
    var book: LegacyBook?
    
    @Relationship(deleteRule: .cascade, inverse: \LegacyAIMessage.session)
    var messages: [LegacyAIMessage]?
    
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
        book: LegacyBook,
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
}

@Model
final class LegacyAIMessage {
    @Attribute(.unique) var id: UUID
    var role: Role
    var content: String
    var timestamp: Date
    var tokenCount: Int?
    var model: String?
    var error: String?
    
    var session: LegacyAISession?
    
    enum Role: String, Codable, CaseIterable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
        case function = "function"
    }
    
    init(
        role: Role,
        content: String,
        session: LegacyAISession,
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
}

@Model
final class LegacyReadingSession {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    var duration: TimeInterval
    var startPage: Int
    var endPage: Int
    var pagesRead: Int
    
    var book: LegacyBook?
    
    init(
        book: LegacyBook,
        startPage: Int
    ) {
        self.id = UUID()
        self.book = book
        self.startDate = Date()
        self.startPage = startPage
        self.endPage = startPage
        self.pagesRead = 0
        self.duration = 0
    }
}

@Model
final class LegacyUsageTracking {
    @Attribute(.unique) var id: UUID
    var date: Date
    var apiCallCount: Int
    var quotaRemaining: Int
    var quotaLimit: Int
    var tokensUsed: Int
    var costEstimate: Double? // In USD cents
    var model: String
    var endpoint: String?
    
    init(
        apiCallCount: Int = 0,
        quotaRemaining: Int,
        quotaLimit: Int,
        tokensUsed: Int = 0,
        model: String = "gpt-4",
        endpoint: String? = nil
    ) {
        self.id = UUID()
        self.date = Date()
        self.apiCallCount = apiCallCount
        self.quotaRemaining = quotaRemaining
        self.quotaLimit = quotaLimit
        self.tokensUsed = tokensUsed
        self.model = model
        self.endpoint = endpoint
        self.costEstimate = nil
    }
}