import Foundation
import SwiftData

/// One-time migration service to sync UserDefaults books to SwiftData
@MainActor
class BookModelMigrationService {
    static let shared = BookModelMigrationService()

    private init() {}

    private let migrationCompletedKey = "bookModelMigrationCompleted_v1"

    private let readingStatusNormalizedKey = "readingStatusNormalized_v1"

    /// Ambient recommendations once saved "want_to_read", which matches no
    /// ReadingStatus case, so those books fell out of status-filtered lists.
    func normalizeLegacyReadingStatuses(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: readingStatusNormalizedKey) else { return }

        let legacyValue = "want_to_read"
        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate<BookModel> { $0.readingStatus == legacyValue }
        )

        do {
            let legacyBooks = try modelContext.fetch(descriptor)
            for book in legacyBooks {
                book.readingStatus = ReadingStatus.wantToRead.rawValue
            }
            if !legacyBooks.isEmpty {
                try modelContext.save()
            }
            UserDefaults.standard.set(true, forKey: readingStatusNormalizedKey)
            #if DEBUG
            print("✅ [MIGRATION] Normalized \(legacyBooks.count) legacy reading statuses")
            #endif
        } catch {
            #if DEBUG
            print("❌ [MIGRATION] Reading status normalization failed: \(error)")
            #endif
        }
    }

    /// Migrate all UserDefaults books to SwiftData BookModels
    /// This ensures all existing library books have BookModels for enrichment
    func migrateIfNeeded(libraryViewModel: LibraryViewModel, modelContext: ModelContext) async {
        // Check if migration already completed
        if UserDefaults.standard.bool(forKey: migrationCompletedKey) {
            #if DEBUG
            print("✅ [MIGRATION] Already completed, skipping")
            #endif
            return
        }

        #if DEBUG
        print("🔄 [MIGRATION] Starting UserDefaults → SwiftData migration...")
        #endif

        let userDefaultsBooks = libraryViewModel.books
        #if DEBUG
        print("📚 [MIGRATION] Found \(userDefaultsBooks.count) books in UserDefaults")
        #endif

        var createdCount = 0
        var skippedCount = 0

        for book in userDefaultsBooks {
            // Check if BookModel already exists
            let descriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate<BookModel> { $0.id == book.id }
            )

            if let existingModel = try? modelContext.fetch(descriptor).first {
                #if DEBUG
                print("⏭️ [MIGRATION] BookModel already exists: \(book.title)")
                #endif
                skippedCount += 1
            } else {
                #if DEBUG
                print("📝 [MIGRATION] Creating BookModel for: \(book.title)")
                #endif
                let bookModel = BookModel(from: book)
                modelContext.insert(bookModel)
                createdCount += 1
            }
        }

        // Save all changes
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ [MIGRATION] Complete!")
            #endif
            #if DEBUG
            print("   Created: \(createdCount)")
            #endif
            #if DEBUG
            print("   Skipped: \(skippedCount)")
            #endif
            #if DEBUG
            print("   Total: \(userDefaultsBooks.count)")
            #endif

            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationCompletedKey)

        } catch {
            #if DEBUG
            print("❌ [MIGRATION] Failed to save: \(error)")
            #endif
        }
    }

    /// Reset migration flag (for debugging only)
    func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationCompletedKey)
        #if DEBUG
        print("🔄 [MIGRATION] Reset flag - will re-run on next launch")
        #endif
    }
}
