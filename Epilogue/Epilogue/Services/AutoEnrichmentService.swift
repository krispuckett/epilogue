import Foundation
import SwiftData

/// Automatically enriches unenriched books in the background without user intervention
@MainActor
class AutoEnrichmentService {
    static let shared = AutoEnrichmentService()

    private init() {}

    private var isRunning = false

    /// Maximum number of enrichment failures before giving up on a book
    private let maxFailCount = 5

    /// Automatically enrich unenriched books in the background
    /// - Runs silently without blocking UI
    /// - Processes slowly to avoid API rate limits
    /// - Only runs if there are unenriched books
    /// - Skips books that have exceeded retry limits or are in backoff
    func autoEnrichBooksIfNeeded(modelContext: ModelContext) {
        // Don't run if already running
        guard !isRunning else {
            #if DEBUG
            print("🔄 [AUTO-ENRICH] Already running, skipping")
            #endif
            return
        }

        #if DEBUG
        print("🎨 [AUTO-ENRICH] Checking for unenriched books...")
        #endif
        isRunning = true

        // Run on MainActor to ensure ModelContext safety
        Task { @MainActor in
            await performBackgroundEnrichment(modelContext: modelContext)
            isRunning = false
        }
    }

    /// Calculate the backoff interval for a given fail count
    /// 1st retry: 1h, 2nd: 2h, 3rd: 4h, 4th: 8h, 5th: 16h, capped at 24h
    private func backoffInterval(for failCount: Int) -> TimeInterval {
        let hours = pow(2.0, Double(failCount))
        let cappedHours = min(hours, 24.0)
        return cappedHours * 3600 // Convert to seconds
    }

    /// Check if a book is eligible for enrichment retry based on backoff
    private func isEligibleForRetry(_ book: BookModel) -> Bool {
        // Already enriched — skip
        if book.isEnriched { return false }

        // Exceeded max failures — give up
        if book.enrichmentFailCount >= maxFailCount { return false }

        // Never failed — eligible
        guard book.enrichmentFailCount > 0 else { return true }

        // Check backoff interval
        guard let lastAttempt = book.lastEnrichmentAttempt else { return true }
        let requiredInterval = backoffInterval(for: book.enrichmentFailCount)
        return Date().timeIntervalSince(lastAttempt) >= requiredInterval
    }

    private func performBackgroundEnrichment(modelContext: ModelContext) async {
        // Fetch all BookModels
        let descriptor = FetchDescriptor<BookModel>()

        guard let allBooks = try? modelContext.fetch(descriptor) else {
            #if DEBUG
            print("❌ [AUTO-ENRICH] Failed to fetch books")
            #endif
            return
        }

        // Filter to books eligible for enrichment (unenriched + passing backoff check)
        let eligibleBooks = allBooks.filter { isEligibleForRetry($0) }

        #if DEBUG
        let unenrichedCount = allBooks.filter { !$0.isEnriched }.count
        let givenUpCount = allBooks.filter { $0.enrichmentFailCount >= maxFailCount }.count
        let backoffCount = unenrichedCount - eligibleBooks.count - givenUpCount
        print("📊 [AUTO-ENRICH] Found \(allBooks.count) total books")
        print("📊 [AUTO-ENRICH] \(unenrichedCount) unenriched, \(eligibleBooks.count) eligible, \(givenUpCount) given up, \(backoffCount) in backoff")
        #endif

        guard !eligibleBooks.isEmpty else {
            #if DEBUG
            print("✅ [AUTO-ENRICH] No books eligible for enrichment right now")
            #endif
            return
        }

        // Process VERY slowly to avoid overwhelming API
        // Enrich 1 book every 5 seconds
        for (index, book) in eligibleBooks.enumerated() {
            #if DEBUG
            let retryInfo = book.enrichmentFailCount > 0 ? " (retry #\(book.enrichmentFailCount))" : ""
            print("🎨 [AUTO-ENRICH] [\(index + 1)/\(eligibleBooks.count)] Enriching: \(book.title)\(retryInfo)")
            #endif

            await BookEnrichmentService.shared.enrichBook(book)

            if book.isEnriched {
                // Success — reset failure tracking
                book.enrichmentFailCount = 0
                #if DEBUG
                print("✅ [AUTO-ENRICH] Success: \(book.title)")
                #endif
            } else {
                // Failed — increment fail count and record attempt time
                book.enrichmentFailCount += 1
                book.lastEnrichmentAttempt = Date()
                #if DEBUG
                let nextBackoff = backoffInterval(for: book.enrichmentFailCount)
                let nextRetryHours = nextBackoff / 3600
                if book.enrichmentFailCount >= maxFailCount {
                    print("❌ [AUTO-ENRICH] Failed: \(book.title) — giving up after \(maxFailCount) attempts")
                } else {
                    print("⚠️ [AUTO-ENRICH] Failed: \(book.title) — attempt \(book.enrichmentFailCount)/\(maxFailCount), next retry in \(String(format: "%.0f", nextRetryHours))h")
                }
                #endif
            }

            // Wait 5 seconds between books to be respectful to API
            if index < eligibleBooks.count - 1 {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }

        #if DEBUG
        print("✅ [AUTO-ENRICH] Background enrichment complete!")
        #endif
    }

    /// Reset all failed enrichment counts so books can be retried
    /// Use this from Gandalf mode or manual retry UI
    func resetFailedEnrichments(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<BookModel>()

        guard let allBooks = try? modelContext.fetch(descriptor) else {
            #if DEBUG
            print("❌ [AUTO-ENRICH] Failed to fetch books for reset")
            #endif
            return
        }

        var resetCount = 0
        for book in allBooks where book.enrichmentFailCount > 0 {
            book.enrichmentFailCount = 0
            book.lastEnrichmentAttempt = nil
            resetCount += 1
        }

        #if DEBUG
        print("🔄 [AUTO-ENRICH] Reset enrichment failures for \(resetCount) books")
        #endif
    }
}
