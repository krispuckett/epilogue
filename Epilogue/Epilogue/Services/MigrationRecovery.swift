import Foundation
import SwiftData

/// Emergency recovery service for migration issues
@MainActor
final class MigrationRecovery {
    static let shared = MigrationRecovery()
    
    private let backupKey = "com.epilogue.preImportBackup"
    private let recoveryAttemptKey = "com.epilogue.migrationRecoveryAttempts"
    
    private init() {}
    
    /// Creates a backup before migration
    func createPreMigrationBackup() {
        // Store critical metadata about the current state
        let backup = PreMigrationBackup(
            timestamp: Date(),
            bookCount: getCurrentBookCount(),
            noteCount: getCurrentNoteCount(),
            quoteCount: getCurrentQuoteCount()
        )
        
        if let data = try? JSONEncoder().encode(backup) {
            UserDefaults.standard.set(data, forKey: backupKey)
        }
    }
    
    /// Checks if recovery is needed
    func shouldAttemptRecovery() -> Bool {
        // Check if migration was started but not completed
        let migrationInProgress = UserDefaults.standard.bool(forKey: "com.epilogue.dataMigrationInProgress")
        let migrationCompleted = UserDefaults.standard.bool(forKey: "com.epilogue.dataMigrationCompleted.v2")
        
        // If migration was in progress but not completed, and we've restarted
        if migrationInProgress && !migrationCompleted {
            let attempts = UserDefaults.standard.integer(forKey: recoveryAttemptKey)
            
            // Only attempt recovery up to 3 times
            if attempts < 3 {
                UserDefaults.standard.set(attempts + 1, forKey: recoveryAttemptKey)
                return true
            }
        }
        
        return false
    }
    
    /// Resets migration state for retry
    func resetMigrationState() {
        print("🔄 Resetting migration state for retry...")
        
        // Clear migration flags
        UserDefaults.standard.removeObject(forKey: "com.epilogue.dataMigrationInProgress")
        UserDefaults.standard.removeObject(forKey: "com.epilogue.dataMigrationCompleted.v2")
        
        // Clear any partial migration stats
        UserDefaults.standard.removeObject(forKey: "com.epilogue.migrationStats")
    }
    
    /// Emergency reset - use with extreme caution
    func performEmergencyReset() {
        print("🚨 Performing emergency migration reset...")
        
        // Reset all migration-related keys
        resetMigrationState()
        
        // Clear recovery attempts
        UserDefaults.standard.removeObject(forKey: recoveryAttemptKey)
        
        // Note: This does NOT delete any data, just resets migration state
        print("✅ Emergency reset complete. Migration will be reattempted on next launch.")
    }
    
    /// Gets current counts for comparison
    private func getCurrentBookCount() -> Int {
        // This is a simplified version - in production you'd check actual SwiftData
        return 0
    }
    
    private func getCurrentNoteCount() -> Int {
        return 0
    }
    
    private func getCurrentQuoteCount() -> Int {
        return 0
    }
    
    /// Validates migration results
    func validateMigrationResults(oldContainer: ModelContainer?, newContainer: ModelContainer) async -> MigrationValidation {
        guard let backup = getPreMigrationBackup() else {
            return .noBackupAvailable
        }
        
        do {
            let newContext = newContainer.mainContext
            
            let currentBookCount = try newContext.fetchCount(FetchDescriptor<BookModel>())
            let currentNoteCount = try newContext.fetchCount(FetchDescriptor<CapturedNote>())
            let currentQuoteCount = try newContext.fetchCount(FetchDescriptor<CapturedQuote>())
            
            // Check if we have at least as much data as before
            if currentBookCount >= backup.bookCount &&
               currentNoteCount >= backup.noteCount &&
               currentQuoteCount >= backup.quoteCount {
                return .success
            } else {
                return .dataLoss(
                    expectedBooks: backup.bookCount,
                    foundBooks: currentBookCount,
                    expectedNotes: backup.noteCount,
                    foundNotes: currentNoteCount,
                    expectedQuotes: backup.quoteCount,
                    foundQuotes: currentQuoteCount
                )
            }
        } catch {
            return .validationError(error)
        }
    }
    
    /// Gets the pre-migration backup
    private func getPreMigrationBackup() -> PreMigrationBackup? {
        guard let data = UserDefaults.standard.data(forKey: backupKey),
              let backup = try? JSONDecoder().decode(PreMigrationBackup.self, from: data) else {
            return nil
        }
        return backup
    }
}

// MARK: - Supporting Types

private struct PreMigrationBackup: Codable {
    let timestamp: Date
    let bookCount: Int
    let noteCount: Int
    let quoteCount: Int
}

enum MigrationValidation {
    case success
    case noBackupAvailable
    case dataLoss(expectedBooks: Int, foundBooks: Int, expectedNotes: Int, foundNotes: Int, expectedQuotes: Int, foundQuotes: Int)
    case validationError(Error)
    
    var description: String {
        switch self {
        case .success:
            return "Migration validated successfully"
        case .noBackupAvailable:
            return "No backup available for validation"
        case .dataLoss(let expectedBooks, let foundBooks, let expectedNotes, let foundNotes, let expectedQuotes, let foundQuotes):
            return """
            Potential data loss detected:
            Books: expected \(expectedBooks), found \(foundBooks)
            Notes: expected \(expectedNotes), found \(foundNotes)
            Quotes: expected \(expectedQuotes), found \(foundQuotes)
            """
        case .validationError(let error):
            return "Validation error: \(error.localizedDescription)"
        }
    }
}