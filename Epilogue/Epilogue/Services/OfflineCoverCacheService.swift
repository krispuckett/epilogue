import Foundation
import SwiftData
import UIKit

/// Service to proactively cache book covers to SwiftData for offline access
@MainActor
class OfflineCoverCacheService {
    static let shared = OfflineCoverCacheService()

    private var modelContext: ModelContext?
    private var isProcessing = false

    // User preference for automatic caching
    private let autoCacheKey = "offlineCoverAutoCacheEnabled"
    var isAutoCacheEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: autoCacheKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoCacheKey) }
    }

    private init() {
        // Default to enabled for better offline experience
        if UserDefaults.standard.object(forKey: autoCacheKey) == nil {
            isAutoCacheEnabled = true
        }
    }

    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Single Book Caching

    /// Cache cover for a single book immediately when added
    func cacheCoverForNewBook(_ bookModel: BookModel) async {
        guard isAutoCacheEnabled else { return }
        guard bookModel.coverImageData == nil else {
            #if DEBUG
            print("✅ Book already has cached cover data: \(bookModel.title)")
            #endif
            return
        }

        guard let coverURL = bookModel.coverImageURL else {
            #if DEBUG
            print("⚠️ No cover URL for: \(bookModel.title)")
            #endif
            return
        }

        #if DEBUG
        print("📥 Caching cover for new book: \(bookModel.title)")
        #endif

        // Load full image and cache it
        if let image = await SharedBookCoverManager.shared.loadFullImage(from: coverURL),
           let data = image.jpegData(compressionQuality: 0.8) {
            bookModel.coverImageData = data
            try? modelContext?.save()
            #if DEBUG
            print("✅ Cached cover data for: \(bookModel.title) (\(data.count / 1024) KB)")
            #endif
        } else {
            #if DEBUG
            print("❌ Failed to load cover for: \(bookModel.title)")
            #endif
        }
    }

    // MARK: - Batch Library Caching

    /// Cache all library books' covers in background
    func cacheAllLibraryCovers() async {
        guard isAutoCacheEnabled else {
            #if DEBUG
            print("⚠️ Auto-cache disabled by user")
            #endif
            return
        }

        guard !isProcessing else {
            #if DEBUG
            print("⚠️ Already processing cover cache")
            #endif
            return
        }

        guard let context = modelContext else {
            #if DEBUG
            print("❌ ModelContext not configured")
            #endif
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        #if DEBUG
        print("🔄 Starting library cover cache process...")
        #endif

        // Fetch all library books without cached cover data
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { book in
                book.isInLibrary && book.coverImageURL != nil && book.coverImageData == nil
            }
        )

        do {
            let booksNeedingCache = try context.fetch(descriptor)

            guard !booksNeedingCache.isEmpty else {
                #if DEBUG
                print("✅ All library books already have cached covers")
                #endif
                return
            }

            #if DEBUG
            print("📚 Found \(booksNeedingCache.count) books needing cover cache")
            #endif

            // Process in batches to avoid memory pressure
            let batchSize = 3
            for i in stride(from: 0, to: booksNeedingCache.count, by: batchSize) {
                let batch = Array(booksNeedingCache[i..<min(i + batchSize, booksNeedingCache.count)])

                await withTaskGroup(of: Void.self) { group in
                    for book in batch {
                        group.addTask {
                            await self.cacheSingleBookCover(book)
                        }
                    }
                    await group.waitForAll()
                }

                // Save batch
                try? context.save()

                #if DEBUG
                print("✅ Cached batch \(i/batchSize + 1) of \((booksNeedingCache.count + batchSize - 1) / batchSize)")
                #endif

                // Small delay between batches
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }

            #if DEBUG
            print("✅ Library cover cache complete!")
            #endif

        } catch {
            #if DEBUG
            print("❌ Error fetching books for caching: \(error)")
            #endif
        }
    }

    private func cacheSingleBookCover(_ book: BookModel) async {
        guard let coverURL = book.coverImageURL else { return }

        if let image = await SharedBookCoverManager.shared.loadFullImage(from: coverURL),
           let data = image.jpegData(compressionQuality: 0.8) {
            book.coverImageData = data
            #if DEBUG
            print("  ✅ \(book.title): \(data.count / 1024) KB")
            #endif
        } else {
            #if DEBUG
            print("  ❌ \(book.title): Failed to load")
            #endif
        }
    }

    // MARK: - Smart Caching

    /// Cache covers for recently added books (useful after Goodreads import)
    func cacheRecentlyAddedBooks(days: Int = 1) async {
        guard isAutoCacheEnabled else { return }
        guard let context = modelContext else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { book in
                book.isInLibrary &&
                book.coverImageURL != nil &&
                book.coverImageData == nil &&
                book.dateAdded >= cutoffDate
            }
        )

        do {
            let recentBooks = try context.fetch(descriptor)

            guard !recentBooks.isEmpty else {
                #if DEBUG
                print("✅ All recent books already cached")
                #endif
                return
            }

            #if DEBUG
            print("📥 Caching \(recentBooks.count) recently added books...")
            #endif

            for book in recentBooks {
                await cacheSingleBookCover(book)
            }

            try? context.save()
            #if DEBUG
            print("✅ Recent books cached!")
            #endif

        } catch {
            #if DEBUG
            print("❌ Error fetching recent books: \(error)")
            #endif
        }
    }

    // MARK: - Cache Management

    /// Get cache statistics
    func getCacheStats() async -> (cached: Int, total: Int, sizeInMB: Double) {
        guard let context = modelContext else { return (0, 0, 0) }

        do {
            let totalDescriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate { $0.isInLibrary }
            )
            let totalBooks = try context.fetch(totalDescriptor)

            let cachedDescriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate { $0.isInLibrary && $0.coverImageData != nil }
            )
            let cachedBooks = try context.fetch(cachedDescriptor)

            let totalSize = cachedBooks.reduce(0.0) { sum, book in
                sum + Double(book.coverImageData?.count ?? 0)
            }
            let sizeInMB = totalSize / (1024 * 1024)

            return (cachedBooks.count, totalBooks.count, sizeInMB)

        } catch {
            #if DEBUG
            print("❌ Error getting cache stats: \(error)")
            #endif
            return (0, 0, 0)
        }
    }

    /// Clear all cached cover data (useful for troubleshooting or storage management)
    func clearAllCachedCovers() async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { $0.coverImageData != nil }
        )

        do {
            let booksWithCache = try context.fetch(descriptor)

            for book in booksWithCache {
                book.coverImageData = nil
            }

            try context.save()
            #if DEBUG
            print("✅ Cleared \(booksWithCache.count) cached covers")
            #endif

        } catch {
            #if DEBUG
            print("❌ Error clearing cache: \(error)")
            #endif
        }
    }
}