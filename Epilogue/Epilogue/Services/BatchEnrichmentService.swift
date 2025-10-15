import Foundation
import SwiftData

/// Service to batch enrich existing books in the library
@MainActor
class BatchEnrichmentService {
    static let shared = BatchEnrichmentService()

    private init() {}

    /// Enrich all unenriched books in the library
    func enrichAllBooks(modelContext: ModelContext, progressHandler: ((Int, Int, String) -> Void)? = nil) async {
        #if DEBUG
        print("📚 [BATCH] Starting batch enrichment of all books...")
        #endif

        // Fetch all BookModels
        let descriptor = FetchDescriptor<BookModel>()

        guard let allBooks = try? modelContext.fetch(descriptor) else {
            #if DEBUG
            print("❌ [BATCH] Failed to fetch books")
            #endif
            return
        }

        // Filter to only unenriched books
        let unenrichedBooks = allBooks.filter { !$0.isEnriched }

        #if DEBUG
        print("📊 [BATCH] Found \(allBooks.count) total books")
        #endif
        #if DEBUG
        print("📊 [BATCH] \(unenrichedBooks.count) need enrichment")
        #endif
        #if DEBUG
        print("📊 [BATCH] \(allBooks.count - unenrichedBooks.count) already enriched")
        #endif

        guard !unenrichedBooks.isEmpty else {
            #if DEBUG
            print("✅ [BATCH] All books already enriched!")
            #endif
            return
        }

        // Process in batches to avoid overwhelming the API
        let batchSize = 3 // Process 3 books at a time
        var processedCount = 0

        for i in stride(from: 0, to: unenrichedBooks.count, by: batchSize) {
            let batch = Array(unenrichedBooks[i..<min(i + batchSize, unenrichedBooks.count)])

            #if DEBUG
            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            #endif
            #if DEBUG
            print("📦 [BATCH] Processing batch \(i/batchSize + 1)")
            #endif
            #if DEBUG
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            #endif

            // Process batch concurrently
            await withTaskGroup(of: Void.self) { group in
                for book in batch {
                    group.addTask {
                        #if DEBUG
                        print("🎨 [BATCH] Enriching: \(book.title)")
                        #endif
                        await BookEnrichmentService.shared.enrichBook(book)

                        await MainActor.run {
                            processedCount += 1
                            progressHandler?(processedCount, unenrichedBooks.count, book.title)

                            if book.isEnriched {
                                #if DEBUG
                                print("✅ [BATCH] Success: \(book.title)")
                                #endif
                            } else {
                                #if DEBUG
                                print("❌ [BATCH] Failed: \(book.title)")
                                #endif
                            }
                        }
                    }
                }
            }

            // Small delay between batches to avoid rate limiting
            if processedCount < unenrichedBooks.count {
                #if DEBUG
                print("⏸️ [BATCH] Pausing 2s before next batch...")
                #endif
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }

        #if DEBUG
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        #endif
        #if DEBUG
        print("✅ [BATCH] Batch enrichment complete!")
        #endif
        #if DEBUG
        print("   Processed: \(processedCount)/\(unenrichedBooks.count)")
        #endif
        #if DEBUG
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        #endif
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
