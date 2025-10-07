import Foundation
import SwiftData

/// Automatically enriches unenriched books in the background without user intervention
@MainActor
class AutoEnrichmentService {
    static let shared = AutoEnrichmentService()

    private init() {}

    private var isRunning = false

    /// Automatically enrich unenriched books in the background
    /// - Runs silently without blocking UI
    /// - Processes slowly to avoid API rate limits
    /// - Only runs if there are unenriched books
    func autoEnrichBooksIfNeeded(modelContext: ModelContext) {
        // Don't run if already running
        guard !isRunning else {
            print("🔄 [AUTO-ENRICH] Already running, skipping")
            return
        }

        print("🎨 [AUTO-ENRICH] Checking for unenriched books...")
        isRunning = true

        // Run in background task
        Task(priority: .background) {
            await performBackgroundEnrichment(modelContext: modelContext)
            await MainActor.run {
                isRunning = false
            }
        }
    }

    private func performBackgroundEnrichment(modelContext: ModelContext) async {
        // Fetch all BookModels
        let descriptor = FetchDescriptor<BookModel>()

        guard let allBooks = try? modelContext.fetch(descriptor) else {
            print("❌ [AUTO-ENRICH] Failed to fetch books")
            return
        }

        // Filter to only unenriched books
        let unenrichedBooks = allBooks.filter { !$0.isEnriched }

        print("📊 [AUTO-ENRICH] Found \(allBooks.count) total books")
        print("📊 [AUTO-ENRICH] \(unenrichedBooks.count) need enrichment")

        guard !unenrichedBooks.isEmpty else {
            print("✅ [AUTO-ENRICH] All books already enriched!")
            return
        }

        // Process VERY slowly to avoid overwhelming API
        // Enrich 1 book every 5 seconds
        for (index, book) in unenrichedBooks.enumerated() {
            print("🎨 [AUTO-ENRICH] [\(index + 1)/\(unenrichedBooks.count)] Enriching: \(book.title)")

            do {
                await BookEnrichmentService.shared.enrichBook(book)

                if book.isEnriched {
                    print("✅ [AUTO-ENRICH] Success: \(book.title)")
                } else {
                    print("⚠️ [AUTO-ENRICH] No error but not enriched: \(book.title)")
                }
            } catch {
                print("❌ [AUTO-ENRICH] Failed: \(book.title) - \(error)")
            }

            // Wait 5 seconds between books to be respectful to API
            if index < unenrichedBooks.count - 1 {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }

        print("✅ [AUTO-ENRICH] Background enrichment complete!")
    }
}
