import Foundation
import SwiftData
import UserNotifications

// MARK: - Memory Resurfacing Service
/// Manages spaced repetition for quotes, notes, and insights.
/// Generates MemoryCards from existing content and schedules reviews using SM-2.

@MainActor
final class MemoryResurfacingService {
    static let shared = MemoryResurfacingService()

    private var modelContainer: ModelContainer?

    private init() {}

    // MARK: - Configuration

    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }

    // MARK: - Card Generation

    /// Scans all CapturedQuotes, CapturedNotes, and BookInsights.
    /// Creates MemoryCards for any that don't already have one.
    func generateCardsFromExistingContent(modelContext: ModelContext) {
        #if DEBUG
        print("🧠 MemoryResurfacing: Scanning for new content to create cards...")
        #endif

        var cardsCreated = 0

        // --- Quotes ---
        let quoteDescriptor = FetchDescriptor<CapturedQuote>()
        if let quotes = try? modelContext.fetch(quoteDescriptor) {
            for quote in quotes {
                guard let quoteId = quote.id?.uuidString else { continue }
                guard let text = quote.text, !text.isEmpty else { continue }

                // Check if card already exists for this quote
                if cardExists(forSourceQuoteId: quoteId, in: modelContext) { continue }

                let bookTitle = quote.book?.title ?? "Unknown Book"
                let bookAuthor = quote.book?.author ?? quote.author ?? "Unknown Author"

                let card = MemoryCard(
                    content: text,
                    sourceType: "quote",
                    bookTitle: bookTitle,
                    bookAuthor: bookAuthor
                )
                card.sourceQuoteId = quoteId
                card.bookCoverURL = quote.book?.coverImageURL
                card.bookLocalId = quote.book?.localId ?? quote.bookLocalId
                card.bookColors = quote.book?.extractedColors

                modelContext.insert(card)
                cardsCreated += 1
            }
        }

        // --- Notes ---
        let noteDescriptor = FetchDescriptor<CapturedNote>()
        if let notes = try? modelContext.fetch(noteDescriptor) {
            for note in notes {
                guard let noteId = note.id?.uuidString else { continue }
                guard let content = note.content, !content.isEmpty else { continue }

                // Check if card already exists for this note
                if cardExists(forSourceNoteId: noteId, in: modelContext) { continue }

                let bookTitle = note.book?.title ?? "Unknown Book"
                let bookAuthor = note.book?.author ?? "Unknown Author"

                let card = MemoryCard(
                    content: content,
                    sourceType: "note",
                    bookTitle: bookTitle,
                    bookAuthor: bookAuthor
                )
                card.sourceNoteId = noteId
                card.bookCoverURL = note.book?.coverImageURL
                card.bookLocalId = note.book?.localId ?? note.bookLocalId
                card.bookColors = note.book?.extractedColors

                modelContext.insert(card)
                cardsCreated += 1
            }
        }

        // --- BookInsights ---
        let insightDescriptor = FetchDescriptor<BookInsight>()
        if let insights = try? modelContext.fetch(insightDescriptor) {
            for insight in insights {
                let insightId = insight.id
                guard !insight.content.isEmpty else { continue }
                // Only surface meaningful insights (importance >= 3)
                guard insight.importance >= 3 else { continue }

                // Check if card already exists for this insight
                if cardExists(forSourceInsightId: insightId, in: modelContext) { continue }

                let bookTitle = insight.book?.title ?? "Unknown Book"
                let bookAuthor = insight.book?.author ?? "Unknown Author"

                let card = MemoryCard(
                    content: insight.content,
                    sourceType: "insight",
                    bookTitle: bookTitle,
                    bookAuthor: bookAuthor
                )
                card.sourceInsightId = insightId
                card.bookCoverURL = insight.book?.coverImageURL
                card.bookLocalId = insight.book?.localId
                card.bookColors = insight.book?.extractedColors

                modelContext.insert(card)
                cardsCreated += 1
            }
        }

        if cardsCreated > 0 {
            try? modelContext.save()
            #if DEBUG
            print("🧠 MemoryResurfacing: Created \(cardsCreated) new memory cards")
            #endif
        } else {
            #if DEBUG
            print("🧠 MemoryResurfacing: No new cards needed")
            #endif
        }
    }

    // MARK: - Card Retrieval

    /// Returns cards due for review (nextReviewDate <= now), sorted by priority.
    func getCardsForReview(modelContext: ModelContext, limit: Int = 10) -> [MemoryCard] {
        let now = Date()
        var descriptor = FetchDescriptor<MemoryCard>(
            predicate: #Predicate<MemoryCard> { card in
                card.nextReviewDate <= now
            },
            sortBy: [
                SortDescriptor(\MemoryCard.nextReviewDate, order: .forward)
            ]
        )
        descriptor.fetchLimit = limit

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Count of cards currently due for review.
    func pendingReviewCount(modelContext: ModelContext) -> Int {
        let now = Date()
        let descriptor = FetchDescriptor<MemoryCard>(
            predicate: #Predicate<MemoryCard> { card in
                card.nextReviewDate <= now
            }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    /// Total number of memory cards.
    func totalCardCount(modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<MemoryCard>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - SM-2 Review Algorithm

    /// Updates a card using the SM-2 spaced repetition algorithm.
    /// - Parameters:
    ///   - card: The memory card being reviewed
    ///   - quality: The user's self-assessed recall quality
    func reviewCard(_ card: MemoryCard, quality: ReviewQuality) {
        let q = Double(quality.rawValue)

        card.reviewCount += 1
        card.lastReviewedAt = Date()

        if quality.rawValue >= 3 {
            // Successful recall — increase interval
            switch card.reviewCount {
            case 1:
                card.interval = 1
            case 2:
                card.interval = 6
            default:
                card.interval = max(1, Int(Double(card.interval) * card.easeFactor))
            }

            // Update ease factor (SM-2 formula)
            let newEF = card.easeFactor + (0.1 - (5.0 - q) * (0.08 + (5.0 - q) * 0.02))
            card.easeFactor = max(1.3, newEF)
        } else {
            // Failed recall — reset to beginning
            card.interval = 1
            card.reviewCount = 0 // Reset repetition count
            // Ease factor stays the same on failure
        }

        // Schedule next review
        card.nextReviewDate = Calendar.current.date(
            byAdding: .day,
            value: card.interval,
            to: Date()
        ) ?? Date().addingTimeInterval(TimeInterval(card.interval * 86400))

        #if DEBUG
        print("🧠 Card reviewed: quality=\(quality.label), interval=\(card.interval)d, EF=\(String(format: "%.2f", card.easeFactor))")
        #endif
    }

    // MARK: - Notifications

    /// Schedule a daily review reminder if there are pending cards.
    func scheduleReviewNotification(modelContext: ModelContext) {
        let pendingCount = pendingReviewCount(modelContext: modelContext)
        guard pendingCount > 0 else {
            // Remove any existing notifications
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["epilogue.daily.review"]
            )
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Daily Review"
        content.body = "\(pendingCount) highlight\(pendingCount == 1 ? "" : "s") waiting to be revisited"
        content.sound = .default

        // Schedule for 9 AM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "epilogue.daily.review",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
            if let error {
                print("🧠 Failed to schedule review notification: \(error)")
            } else {
                print("🧠 Daily review notification scheduled")
            }
            #endif
        }
    }

    // MARK: - Private Helpers

    private func cardExists(forSourceQuoteId quoteId: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<MemoryCard>(
            predicate: #Predicate<MemoryCard> { card in
                card.sourceQuoteId == quoteId
            }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    private func cardExists(forSourceNoteId noteId: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<MemoryCard>(
            predicate: #Predicate<MemoryCard> { card in
                card.sourceNoteId == noteId
            }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    private func cardExists(forSourceInsightId insightId: String, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<MemoryCard>(
            predicate: #Predicate<MemoryCard> { card in
                card.sourceInsightId == insightId
            }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }
}
