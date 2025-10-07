import Foundation
import SwiftData

/// Service to batch enrich existing books in the library
@MainActor
class BatchEnrichmentService {
    static let shared = BatchEnrichmentService()

    private init() {}

    /// Enrich all unenriched books in the library
    func enrichAllBooks(modelContext: ModelContext, progressHandler: ((Int, Int, String) -> Void)? = nil) async {
        print("📚 [BATCH] Starting batch enrichment of all books...")

        // Fetch all BookModels
        let descriptor = FetchDescriptor<BookModel>()

        guard let allBooks = try? modelContext.fetch(descriptor) else {
            print("❌ [BATCH] Failed to fetch books")
            return
        }

        // Filter to only unenriched books
        let unenrichedBooks = allBooks.filter { !$0.isEnriched }

        print("📊 [BATCH] Found \(allBooks.count) total books")
        print("📊 [BATCH] \(unenrichedBooks.count) need enrichment")
        print("📊 [BATCH] \(allBooks.count - unenrichedBooks.count) already enriched")

        guard !unenrichedBooks.isEmpty else {
            print("✅ [BATCH] All books already enriched!")
            return
        }

        // Process in batches to avoid overwhelming the API
        let batchSize = 3 // Process 3 books at a time
        var processedCount = 0

        for i in stride(from: 0, to: unenrichedBooks.count, by: batchSize) {
            let batch = Array(unenrichedBooks[i..<min(i + batchSize, unenrichedBooks.count)])

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📦 [BATCH] Processing batch \(i/batchSize + 1)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            // Process batch concurrently
            await withTaskGroup(of: Void.self) { group in
                for book in batch {
                    group.addTask {
                        print("🎨 [BATCH] Enriching: \(book.title)")
                        await BookEnrichmentService.shared.enrichBook(book)

                        await MainActor.run {
                            processedCount += 1
                            progressHandler?(processedCount, unenrichedBooks.count, book.title)

                            if book.isEnriched {
                                print("✅ [BATCH] Success: \(book.title)")
                            } else {
                                print("❌ [BATCH] Failed: \(book.title)")
                            }
                        }
                    }
                }
            }

            // Small delay between batches to avoid rate limiting
            if processedCount < unenrichedBooks.count {
                print("⏸️ [BATCH] Pausing 2s before next batch...")
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ [BATCH] Batch enrichment complete!")
        print("   Processed: \(processedCount)/\(unenrichedBooks.count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    /// Get enrichment statistics
    func getEnrichmentStats(modelContext: ModelContext) -> (total: Int, enriched: Int, pending: Int) {
        let descriptor = FetchDescriptor<BookModel>()

        guard let allBooks = try? modelContext.fetch(descriptor) else {
            return (0, 0, 0)
        }

        let enrichedCount = allBooks.filter { $0.isEnriched }.count

        return (
            total: allBooks.count,
            enriched: enrichedCount,
            pending: allBooks.count - enrichedCount
        )
    }
}
