import Foundation
import SwiftData

/// Helper for recovering from SwiftData initialization failures
struct DataRecovery {

    /// Removes the SwiftData store files to force a clean initialization
    static func cleanSwiftDataStore() {
        #if DEBUG
        print("🧹 Attempting to clean SwiftData store...")
        #endif

        let fileManager = FileManager.default

        // Get the Application Support directory
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first else {
            #if DEBUG
            print("❌ Could not find Application Support directory")
            #endif
            return
        }

        // SwiftData typically stores files in Application Support
        let storeURL = appSupportURL.appendingPathComponent("default.store")
        let shmURL = appSupportURL.appendingPathComponent("default.store-shm")
        let walURL = appSupportURL.appendingPathComponent("default.store-wal")

        // Also check for CoreData files (SwiftData uses CoreData internally)
        let sqliteURL = appSupportURL.appendingPathComponent("Model.sqlite")
        let sqliteShmURL = appSupportURL.appendingPathComponent("Model.sqlite-shm")
        let sqliteWalURL = appSupportURL.appendingPathComponent("Model.sqlite-wal")

        let filesToDelete = [
            storeURL, shmURL, walURL,
            sqliteURL, sqliteShmURL, sqliteWalURL
        ]

        var deletedFiles = false

        for fileURL in filesToDelete {
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    try fileManager.removeItem(at: fileURL)
                    #if DEBUG
                    print("✅ Deleted: \(fileURL.lastPathComponent)")
                    #endif
                    deletedFiles = true
                } catch {
                    #if DEBUG
                    print("⚠️ Could not delete \(fileURL.lastPathComponent): \(error)")
                    #endif
                }
            }
        }

        if deletedFiles {
            #if DEBUG
            print("🧹 SwiftData store cleaned. App will create fresh database on next launch.")
            #endif
        } else {
            #if DEBUG
            print("ℹ️ No SwiftData store files found to clean.")
            #endif
        }

        // Also clear CloudKit metadata if present
        clearCloudKitMetadata()
    }

    /// Clears CloudKit metadata that might be causing sync issues
    private static func clearCloudKitMetadata() {
        let fileManager = FileManager.default

        // CloudKit metadata is typically stored in a .CloudKit subdirectory
        guard let documentsURL = fileManager.urls(for: .documentDirectory,
                                                  in: .userDomainMask).first else { return }

        let cloudKitURL = documentsURL.appendingPathComponent(".CloudKit")

        if fileManager.fileExists(atPath: cloudKitURL.path) {
            do {
                try fileManager.removeItem(at: cloudKitURL)
                #if DEBUG
                print("✅ Cleared CloudKit metadata")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Could not clear CloudKit metadata: \(error)")
                #endif
            }
        }
    }

    /// Checks if we should attempt recovery based on previous crashes
    static func shouldAttemptRecovery() -> Bool {
        let key = "SwiftDataInitializationFailureCount"
        let failureCount = UserDefaults.standard.integer(forKey: key)

        // If we've failed more than 2 times, attempt recovery
        if failureCount >= 2 {
            #if DEBUG
            print("⚠️ Multiple initialization failures detected. Attempting recovery...")
            #endif
            // Reset the counter
            UserDefaults.standard.set(0, forKey: key)
            return true
        }

        return false
    }

    /// Records an initialization failure
    static func recordInitializationFailure() {
        let key = "SwiftDataInitializationFailureCount"
        let failureCount = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(failureCount + 1, forKey: key)
    }

    /// Records a successful initialization
    static func recordInitializationSuccess() {
        let key = "SwiftDataInitializationFailureCount"
        UserDefaults.standard.set(0, forKey: key)
    }
}