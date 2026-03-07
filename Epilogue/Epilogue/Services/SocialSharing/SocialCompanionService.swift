import Foundation
import SwiftData
import CloudKit
import OSLog

// MARK: - Social Companion Service
/// Manages friend-to-friend reading companionships via CloudKit sharing.
/// Uses CKShare for two-person private sharing.

@MainActor
@Observable
final class SocialCompanionService {
    static let shared = SocialCompanionService()

    private let logger = Logger(subsystem: "com.epilogue", category: "SocialCompanion")
    private let container = CKContainer.default()

    // State
    private(set) var activeCompanionships: [SocialCompanionship] = []
    private(set) var pendingInvitations: [SocialCompanionship] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    // Discovery queue for ceremonial reveal
    private(set) var pendingDiscoveries: [TrailMarkerDiscovery] = []

    private init() {}

    // MARK: - User Identity

    /// Get or create the current user's CloudKit record name
    func getCurrentUserRecordName() async throws -> String {
        let recordID = try await container.userRecordID()
        return recordID.recordName
    }

    /// Check if user is signed into iCloud
    func checkiCloudStatus() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            logger.error("Failed to check iCloud status: \(error)")
            return false
        }
    }

    // MARK: - Create Companionship

    /// Create a new reading companionship for a book
    func createCompanionship(
        for book: BookModel,
        ownerDisplayName: String,
        context: ModelContext
    ) async throws -> SocialCompanionship {
        isLoading = true
        defer { isLoading = false }

        // Get user's CloudKit record name
        let recordName = try await getCurrentUserRecordName()

        // Create companionship
        let companionship = SocialCompanionship(
            book: book,
            ownerDisplayName: ownerDisplayName,
            ownerRecordName: recordName
        )

        // Set initial progress
        if let pageCount = book.pageCount, pageCount > 0 {
            companionship.ownerProgress = Double(book.currentPage) / Double(pageCount)
        }

        // Save to SwiftData
        context.insert(companionship)
        try context.save()

        logger.info("Created companionship for '\(book.title)' with token: \(companionship.invitationToken ?? "none")")

        return companionship
    }

    /// Generate shareable invitation link
    func generateInvitationLink(for companionship: SocialCompanionship) -> URL? {
        return companionship.invitationURL
    }

    // MARK: - Accept Invitation

    /// Look up a companionship by invitation token (without accepting it)
    func lookupInvitation(
        token: String,
        context: ModelContext
    ) async throws -> SocialCompanionship {
        isLoading = true
        defer { isLoading = false }

        // Find companionship with this token
        let descriptor = FetchDescriptor<SocialCompanionship>(
            predicate: #Predicate { $0.invitationToken == token }
        )

        guard let companionship = try context.fetch(descriptor).first else {
            logger.error("No companionship found for token")
            throw CompanionshipError.invitationNotFound
        }

        // Check if expired
        if let expiresAt = companionship.invitationExpiresAt, expiresAt < Date() {
            companionship.companionshipStatus = .expired
            try context.save()
            throw CompanionshipError.invitationExpired
        }

        // Check if already accepted
        guard companionship.companionshipStatus == .pending else {
            throw CompanionshipError.alreadyAccepted
        }

        return companionship
    }

    /// Accept a companionship invitation (after lookup)
    func acceptInvitation(
        companionship: SocialCompanionship,
        companionDisplayName: String,
        context: ModelContext
    ) async throws -> SocialCompanionship {
        isLoading = true
        defer { isLoading = false }

        // Get user's CloudKit record name
        let recordName = try await getCurrentUserRecordName()

        // Update companionship
        companionship.companionDisplayName = companionDisplayName
        companionship.companionRecordName = recordName
        companionship.companionshipStatus = .active
        companionship.lastActivityAt = Date()

        try context.save()

        logger.info("Accepted companionship invitation for '\(companionship.bookTitle)'")

        return companionship
    }

    /// Accept a companionship invitation via token
    func acceptInvitation(
        token: String,
        companionDisplayName: String,
        context: ModelContext
    ) async throws -> SocialCompanionship? {
        isLoading = true
        defer { isLoading = false }

        // Find companionship with this token
        let descriptor = FetchDescriptor<SocialCompanionship>(
            predicate: #Predicate { $0.invitationToken == token }
        )

        guard let companionship = try context.fetch(descriptor).first else {
            logger.error("No companionship found for token: \(token)")
            throw CompanionshipError.invitationNotFound
        }

        // Check if expired
        if let expiresAt = companionship.invitationExpiresAt, expiresAt < Date() {
            companionship.companionshipStatus = .expired
            try context.save()
            throw CompanionshipError.invitationExpired
        }

        // Check if already accepted
        guard companionship.companionshipStatus == .pending else {
            throw CompanionshipError.alreadyAccepted
        }

        // Get user's CloudKit record name
        let recordName = try await getCurrentUserRecordName()

        // Update companionship
        companionship.companionDisplayName = companionDisplayName
        companionship.companionRecordName = recordName
        companionship.companionshipStatus = .active
        companionship.lastActivityAt = Date()

        try context.save()

        logger.info("Accepted companionship invitation for '\(companionship.bookTitle)'")

        return companionship
    }

    // MARK: - Update Progress

    /// Update your reading progress in a companionship
    func updateProgress(
        companionship: SocialCompanionship,
        progress: Double,
        chapter: String?,
        isOwner: Bool,
        context: ModelContext
    ) throws {
        if isOwner {
            companionship.ownerProgress = progress
            companionship.ownerChapter = chapter
        } else {
            companionship.companionProgress = progress
            companionship.companionChapter = chapter
        }

        companionship.lastActivityAt = Date()
        try context.save()

        logger.info("Updated progress in companionship: \(progress * 100)%")
    }

    // MARK: - Trail Markers

    /// Leave a trail marker for your companion
    func leaveTrailMarker(
        in companionship: SocialCompanionship,
        content: String,
        type: TrailMarkerType,
        progress: Double,
        chapter: String?,
        page: Int?,
        authorDisplayName: String,
        authorRecordName: String,
        context: ModelContext
    ) throws -> TrailMarker {
        let marker = TrailMarker(
            content: content,
            type: type,
            bookProgress: progress,
            authorDisplayName: authorDisplayName,
            authorRecordName: authorRecordName,
            chapter: chapter,
            page: page
        )

        marker.companionship = companionship

        if companionship.trailMarkers == nil {
            companionship.trailMarkers = []
        }
        companionship.trailMarkers?.append(marker)
        companionship.lastActivityAt = Date()

        context.insert(marker)
        try context.save()

        logger.info("Left trail marker at \(progress * 100)%: '\(content.prefix(30))...'")

        return marker
    }

    /// Check for new trail markers that should be revealed
    func checkForNewMarkers(
        in companionship: SocialCompanionship,
        currentProgress: Double,
        lastCheckedProgress: Double,
        isOwner: Bool
    ) -> [TrailMarkerDiscovery] {
        guard let markers = companionship.trailMarkers else { return [] }

        // Get the other person's record name
        let myRecordName = isOwner ? companionship.ownerRecordName : companionship.companionRecordName

        // Find markers from companion that are now visible
        let newMarkers = markers.filter { marker in
            // Must be from the other person
            marker.authorRecordName != myRecordName &&
            // Must be at or before current progress
            marker.bookProgress <= currentProgress &&
            // Must not have been revealed yet
            !marker.isRevealed &&
            // Must be after last checked progress (or check all if first time)
            (lastCheckedProgress == 0 || marker.bookProgress > lastCheckedProgress)
        }

        // Create discoveries
        let discoveries = newMarkers.map { TrailMarkerDiscovery(marker: $0) }

        // Mark as revealed
        for marker in newMarkers {
            marker.isRevealed = true
            marker.revealedAt = Date()
        }

        if !discoveries.isEmpty {
            logger.info("Discovered \(discoveries.count) new trail markers")
        }

        return discoveries
    }

    /// Queue a discovery for ceremonial reveal
    func queueDiscovery(_ discovery: TrailMarkerDiscovery) {
        pendingDiscoveries.append(discovery)
    }

    /// Get and clear the next pending discovery
    func popNextDiscovery() -> TrailMarkerDiscovery? {
        guard !pendingDiscoveries.isEmpty else { return nil }
        return pendingDiscoveries.removeFirst()
    }

    // MARK: - Fetch Companionships

    /// Load all companionships for the current user
    func loadCompanionships(context: ModelContext) async throws {
        isLoading = true
        defer { isLoading = false }

        let recordName = try await getCurrentUserRecordName()

        // Fetch all companionships where user is owner or companion
        let descriptor = FetchDescriptor<SocialCompanionship>(
            predicate: #Predicate<SocialCompanionship> { companionship in
                companionship.ownerRecordName == recordName ||
                companionship.companionRecordName == recordName
            },
            sortBy: [SortDescriptor(\.lastActivityAt, order: .reverse)]
        )

        let companionships = try context.fetch(descriptor)

        // Separate active and pending
        activeCompanionships = companionships.filter { $0.isActive }
        pendingInvitations = companionships.filter { $0.companionshipStatus == .pending }

        let activeCount = self.activeCompanionships.count
        let pendingCount = self.pendingInvitations.count
        logger.info("Loaded \(activeCount) active, \(pendingCount) pending companionships")
    }

    /// Get companionship for a specific book
    func getCompanionship(forBookLocalId bookLocalId: String, context: ModelContext) throws -> SocialCompanionship? {
        let descriptor = FetchDescriptor<SocialCompanionship>(
            predicate: #Predicate { $0.bookLocalId == bookLocalId && $0.status == "active" }
        )
        return try context.fetch(descriptor).first
    }

    // MARK: - Cleanup

    /// End a companionship (mark as completed)
    func endCompanionship(_ companionship: SocialCompanionship, context: ModelContext) throws {
        companionship.companionshipStatus = .completed
        companionship.lastActivityAt = Date()
        try context.save()

        // Remove from active list
        activeCompanionships.removeAll { $0.id == companionship.id }

        logger.info("Ended companionship for '\(companionship.bookTitle)'")
    }

    /// Decline an invitation
    func declineInvitation(_ companionship: SocialCompanionship, context: ModelContext) throws {
        companionship.companionshipStatus = .declined
        try context.save()

        pendingInvitations.removeAll { $0.id == companionship.id }

        logger.info("Declined companionship invitation for '\(companionship.bookTitle)'")
    }
}

// MARK: - Errors

enum CompanionshipError: LocalizedError {
    case invitationNotFound
    case invitationExpired
    case alreadyAccepted
    case notSignedIn
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .invitationNotFound:
            return "This invitation couldn't be found."
        case .invitationExpired:
            return "This invitation has expired."
        case .alreadyAccepted:
            return "This invitation has already been accepted."
        case .notSignedIn:
            return "Please sign in to iCloud to use this feature."
        case .syncFailed:
            return "Failed to sync with iCloud. Please try again."
        }
    }
}
