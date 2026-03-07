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
            // Check for task cancellation between batches
            if Task.isCancelled { return }

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

    /// Force re-enrich ALL books (even already enriched ones)
    /// Use when enrichment data may be incorrect due to bugs or API changes
    func reEnrichAllBooks(modelContext: ModelContext, progressHandler: ((Int, Int, String) -> Void)? = nil) async {
        #if DEBUG
        print("🔄 [BATCH] Starting FORCE re-enrichment of ALL books...")
        #endif

        // Fetch all BookModels
        let descriptor = FetchDescriptor<BookModel>()

        guard let allBooks = try? modelContext.fetch(descriptor) else {
            #if DEBUG
            print("❌ [BATCH] Failed to fetch books")
            #endif
            return
        }

        guard !allBooks.isEmpty else {
            #if DEBUG
            print("✅ [BATCH] No books to re-enrich")
            #endif
            return
        }

        #if DEBUG
        print("📊 [BATCH] Will re-enrich \(allBooks.count) books")
        #endif

        // Clear existing enrichment data to force refresh
        for book in allBooks {
            book.smartSynopsis = nil
            book.keyThemes = nil
            book.majorCharacters = nil
            book.setting = nil
            book.tone = nil
            book.literaryStyle = nil
            book.enrichedAt = nil
        }

        // Process in batches
        let batchSize = 3
        var processedCount = 0

        for i in stride(from: 0, to: allBooks.count, by: batchSize) {
            if Task.isCancelled { return }

            let batch = Array(allBooks[i..<min(i + batchSize, allBooks.count)])

            #if DEBUG
            print("\n📦 [BATCH] Re-enriching batch \(i/batchSize + 1)")
            #endif

            await withTaskGroup(of: Void.self) { group in
                for book in batch {
                    group.addTask {
                        #if DEBUG
                        print("🔄 [BATCH] Re-enriching: \(book.title)")
                        #endif
                        await BookEnrichmentService.shared.enrichBook(book)

                        await MainActor.run {
                            processedCount += 1
                            progressHandler?(processedCount, allBooks.count, book.title)

                            if book.isEnriched {
                                #if DEBUG
                                print("✅ [BATCH] Re-enriched: \(book.title)")
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

            // Delay between batches
            if processedCount < allBooks.count {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }

        #if DEBUG
        print("✅ [BATCH] Force re-enrichment complete! Processed: \(processedCount)/\(allBooks.count)")
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
