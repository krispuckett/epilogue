import Foundation
import SwiftData
import CloudKit

// MARK: - Social Reading Companionship
/// Represents a two-person reading companionship for a specific book.
/// Not to be confused with ReadingCompanion (the AI companion system).

@Model
final class SocialCompanionship {
    // Primary key - also used for CloudKit sharing
    var id: UUID = UUID()

    // Book being read together
    var bookISBN: String = ""
    var bookLocalId: String = ""
    var bookTitle: String = ""
    var bookAuthor: String = ""
    var bookCoverURL: String?

    // Participants
    var ownerDisplayName: String = ""        // Person who created the companionship
    var companionDisplayName: String?        // Person who joined
    var ownerRecordName: String = ""         // CloudKit record name for owner
    var companionRecordName: String?         // CloudKit record name for companion

    // Progress tracking (approximate for privacy)
    var ownerProgress: Double = 0.0          // 0.0 to 1.0
    var ownerChapter: String?                // "Chapter 5" - fuzzy, not page number
    var companionProgress: Double = 0.0
    var companionChapter: String?

    // State
    var status: String = CompanionshipStatus.pending.rawValue
    var createdAt: Date = Date()
    var lastActivityAt: Date = Date()

    // Invitation
    var invitationToken: String?             // Used for invitation links
    var invitationExpiresAt: Date?

    // Relationships
    @Relationship(deleteRule: .cascade)
    var trailMarkers: [TrailMarker]?

    init(
        book: BookModel,
        ownerDisplayName: String,
        ownerRecordName: String
    ) {
        self.id = UUID()
        self.bookISBN = book.isbn ?? ""
        self.bookLocalId = book.localId
        self.bookTitle = book.title
        self.bookAuthor = book.author
        self.bookCoverURL = book.coverImageURL
        self.ownerDisplayName = ownerDisplayName
        self.ownerRecordName = ownerRecordName
        self.status = CompanionshipStatus.pending.rawValue
        self.createdAt = Date()
        self.lastActivityAt = Date()

        // Generate invitation token
        self.invitationToken = UUID().uuidString
        self.invitationExpiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date())
    }

    // Computed properties
    var companionshipStatus: CompanionshipStatus {
        get { CompanionshipStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }

    var isActive: Bool {
        companionshipStatus == .active
    }

    var invitationURL: URL? {
        guard let token = invitationToken else { return nil }
        // Will be: readepilogue.com/companion/[token]
        return URL(string: "https://readepilogue.com/companion/\(token)")
    }

    var deepLinkURL: URL? {
        guard let token = invitationToken else { return nil }
        return URL(string: "epilogue://companion/\(token)")
    }

    /// Check if user is ahead of their companion
    func isAheadOfCompanion(forOwner: Bool) -> Bool {
        if forOwner {
            return ownerProgress > companionProgress
        } else {
            return companionProgress > ownerProgress
        }
    }

    /// Get visible trail markers based on user's progress
    func visibleTrailMarkers(forProgress progress: Double) -> [TrailMarker] {
        guard let markers = trailMarkers else { return [] }
        return markers.filter { $0.bookProgress <= progress }
            .sorted { $0.bookProgress < $1.bookProgress }
    }

    /// Get new trail markers the user hasn't seen yet
    func newTrailMarkers(forProgress progress: Double, lastSeenProgress: Double) -> [TrailMarker] {
        guard let markers = trailMarkers else { return [] }
        return markers.filter { marker in
            marker.bookProgress <= progress && marker.bookProgress > lastSeenProgress
        }
        .sorted { $0.bookProgress < $1.bookProgress }
    }
}

// MARK: - Companionship Status

enum CompanionshipStatus: String, Codable {
    case pending = "pending"       // Invitation sent, not yet accepted
    case active = "active"         // Both people reading together
    case completed = "completed"   // Both finished the book
    case expired = "expired"       // Invitation expired
    case declined = "declined"     // Invitation declined
}

// MARK: - Trail Marker
/// A quote or thought left at a specific point for your companion to discover.

@Model
final class TrailMarker {
    var id: UUID = UUID()

    // Content
    var content: String = ""               // The quote or thought
    var markerType: String = TrailMarkerType.thought.rawValue

    // Position in book
    var bookProgress: Double = 0.0         // 0.0 to 1.0 - when to reveal
    var chapterReference: String?          // "Chapter 5"
    var pageReference: Int?                // Optional page number

    // Author
    var authorDisplayName: String = ""
    var authorRecordName: String = ""

    // Metadata
    var createdAt: Date = Date()
    var isRevealed: Bool = false           // Has the companion seen this?
    var revealedAt: Date?

    // Relationship
    @Relationship
    var companionship: SocialCompanionship?

    init(
        content: String,
        type: TrailMarkerType,
        bookProgress: Double,
        authorDisplayName: String,
        authorRecordName: String,
        chapter: String? = nil,
        page: Int? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.markerType = type.rawValue
        self.bookProgress = bookProgress
        self.chapterReference = chapter
        self.pageReference = page
        self.authorDisplayName = authorDisplayName
        self.authorRecordName = authorRecordName
        self.createdAt = Date()
        self.isRevealed = false
    }

    var type: TrailMarkerType {
        get { TrailMarkerType(rawValue: markerType) ?? .thought }
        set { markerType = newValue.rawValue }
    }
}

// MARK: - Trail Marker Type

enum TrailMarkerType: String, Codable, CaseIterable {
    case thought = "thought"     // Personal reflection
    case quote = "quote"         // A quote from the book
    case question = "question"   // Something to think about
    case highlight = "highlight" // Just marking a moment

    var icon: String {
        switch self {
        case .thought: return "bubble.left"
        case .quote: return "quote.opening"
        case .question: return "questionmark.circle"
        case .highlight: return "star"
        }
    }

    var displayName: String {
        switch self {
        case .thought: return "Thought"
        case .quote: return "Quote"
        case .question: return "Question"
        case .highlight: return "Highlight"
        }
    }
}

// MARK: - User Profile Extension
/// Simple model for storing user's display name (used for social features)

@Model
final class UserProfile {
    var id: UUID = UUID()
    var displayName: String = ""
    var cloudKitRecordName: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Preferences
    var shareProgressByDefault: Bool = true
    var allowCompanionInvites: Bool = true

    init(displayName: String) {
        self.id = UUID()
        self.displayName = displayName
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Companion Discovery Event
/// Tracks when a user discovers their companion's trail markers (for ceremony)

struct TrailMarkerDiscovery: Identifiable {
    let id = UUID()
    let marker: TrailMarker
    let discoveredAt: Date

    init(marker: TrailMarker) {
        self.marker = marker
        self.discoveredAt = Date()
    }
}
