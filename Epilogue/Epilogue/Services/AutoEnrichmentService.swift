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

    private func performBackgroundEnrichment(modelContext: ModelContext) async {
        // Fetch all BookModels
        let descriptor = FetchDescriptor<BookModel>()

        guard let allBooks = try? modelContext.fetch(descriptor) else {
            #if DEBUG
            print("❌ [AUTO-ENRICH] Failed to fetch books")
            #endif
            return
        }

        // Filter to only unenriched books
        let unenrichedBooks = allBooks.filter { !$0.isEnriched }

        #if DEBUG
        print("📊 [AUTO-ENRICH] Found \(allBooks.count) total books")
        #endif
        #if DEBUG
        print("📊 [AUTO-ENRICH] \(unenrichedBooks.count) need enrichment")
        #endif

        guard !unenrichedBooks.isEmpty else {
            #if DEBUG
            print("✅ [AUTO-ENRICH] All books already enriched!")
            #endif
            return
        }

        // Process VERY slowly to avoid overwhelming API
        // Enrich 1 book every 5 seconds
        for (index, book) in unenrichedBooks.enumerated() {
            #if DEBUG
            print("🎨 [AUTO-ENRICH] [\(index + 1)/\(unenrichedBooks.count)] Enriching: \(book.title)")
            #endif

            do {
                await BookEnrichmentService.shared.enrichBook(book)

                if book.isEnriched {
                    #if DEBUG
                    print("✅ [AUTO-ENRICH] Success: \(book.title)")
                    #endif
                } else {
                    #if DEBUG
                    print("⚠️ [AUTO-ENRICH] No error but not enriched: \(book.title)")
                    #endif
                }
            } catch {
                #if DEBUG
                print("❌ [AUTO-ENRICH] Failed: \(book.title) - \(error)")
                #endif
            }

            // Wait 5 seconds between books to be respectful to API
            if index < unenrichedBooks.count - 1 {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }

        #if DEBUG
        print("✅ [AUTO-ENRICH] Background enrichment complete!")
        #endif
    }
}
