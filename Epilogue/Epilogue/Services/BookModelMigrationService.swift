import Foundation
import SwiftData

/// One-time migration service to sync UserDefaults books to SwiftData
@MainActor
class BookModelMigrationService {
    static let shared = BookModelMigrationService()

    private init() {}

    private let migrationCompletedKey = "bookModelMigrationCompleted_v1"

    /// Migrate all UserDefaults books to SwiftData BookModels
    /// This ensures all existing library books have BookModels for enrichment
    func migrateIfNeeded(libraryViewModel: LibraryViewModel, modelContext: ModelContext) async {
        // Check if migration already completed
        if UserDefaults.standard.bool(forKey: migrationCompletedKey) {
            print("✅ [MIGRATION] Already completed, skipping")
            return
        }

        print("🔄 [MIGRATION] Starting UserDefaults → SwiftData migration...")

        let userDefaultsBooks = libraryViewModel.books
        print("📚 [MIGRATION] Found \(userDefaultsBooks.count) books in UserDefaults")

        var createdCount = 0
        var skippedCount = 0

        for book in userDefaultsBooks {
            // Check if BookModel already exists
            let descriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate<BookModel> { $0.id == book.id }
            )

            if let existingModel = try? modelContext.fetch(descriptor).first {
                print("⏭️ [MIGRATION] BookModel already exists: \(book.title)")
                skippedCount += 1
            } else {
                print("📝 [MIGRATION] Creating BookModel for: \(book.title)")
                let bookModel = BookModel(from: book)
                modelContext.insert(bookModel)
                createdCount += 1
            }
        }

        // Save all changes
        do {
            try modelContext.save()
            print("✅ [MIGRATION] Complete!")
            print("   Created: \(createdCount)")
            print("   Skipped: \(skippedCount)")
            print("   Total: \(userDefaultsBooks.count)")

            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationCompletedKey)

        } catch {
            print("❌ [MIGRATION] Failed to save: \(error)")
        }
    }

    /// Reset migration flag (for debugging only)
    func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationCompletedKey)
        print("🔄 [MIGRATION] Reset flag - will re-run on next launch")
    }
}
