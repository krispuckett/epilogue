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
            print("✅ Book already has cached cover data: \(bookModel.title)")
            return
        }

        guard let coverURL = bookModel.coverImageURL else {
            print("⚠️ No cover URL for: \(bookModel.title)")
            return
        }

        print("📥 Caching cover for new book: \(bookModel.title)")

        // Load full image and cache it
        if let image = await SharedBookCoverManager.shared.loadFullImage(from: coverURL),
           let data = image.jpegData(compressionQuality: 0.8) {
            bookModel.coverImageData = data
            try? modelContext?.save()
            print("✅ Cached cover data for: \(bookModel.title) (\(data.count / 1024) KB)")
        } else {
            print("❌ Failed to load cover for: \(bookModel.title)")
        }
    }

    // MARK: - Batch Library Caching

    /// Cache all library books' covers in background
    func cacheAllLibraryCovers() async {
        guard isAutoCacheEnabled else {
            print("⚠️ Auto-cache disabled by user")
            return
        }

        guard !isProcessing else {
            print("⚠️ Already processing cover cache")
            return
        }

        guard let context = modelContext else {
            print("❌ ModelContext not configured")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        print("🔄 Starting library cover cache process...")

        // Fetch all library books without cached cover data
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { book in
                book.isInLibrary && book.coverImageURL != nil && book.coverImageData == nil
            }
        )

        do {
            let booksNeedingCache = try context.fetch(descriptor)

            guard !booksNeedingCache.isEmpty else {
                print("✅ All library books already have cached covers")
                return
            }

            print("📚 Found \(booksNeedingCache.count) books needing cover cache")

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

                print("✅ Cached batch \(i/batchSize + 1) of \((booksNeedingCache.count + batchSize - 1) / batchSize)")

                // Small delay between batches
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }

            print("✅ Library cover cache complete!")

        } catch {
            print("❌ Error fetching books for caching: \(error)")
        }
    }

    private func cacheSingleBookCover(_ book: BookModel) async {
        guard let coverURL = book.coverImageURL else { return }

        if let image = await SharedBookCoverManager.shared.loadFullImage(from: coverURL),
           let data = image.jpegData(compressionQuality: 0.8) {
            book.coverImageData = data
            print("  ✅ \(book.title): \(data.count / 1024) KB")
        } else {
            print("  ❌ \(book.title): Failed to load")
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
                print("✅ All recent books already cached")
                return
            }

            print("📥 Caching \(recentBooks.count) recently added books...")

            for book in recentBooks {
                await cacheSingleBookCover(book)
            }

            try? context.save()
            print("✅ Recent books cached!")

        } catch {
            print("❌ Error fetching recent books: \(error)")
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
            print("❌ Error getting cache stats: \(error)")
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
            print("✅ Cleared \(booksWithCache.count) cached covers")

        } catch {
            print("❌ Error clearing cache: \(error)")
        }
    }
}