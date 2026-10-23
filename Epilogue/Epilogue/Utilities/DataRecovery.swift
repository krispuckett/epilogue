import Foundation
import SwiftData

/// Helper for recovering from SwiftData initialization failures
struct DataRecovery {

    /// Moves the SwiftData store files into a dated quarantine folder so the next
    /// initialization starts clean without destroying the reader's data.
    /// Nothing is deleted. The quarantined copy can be restored or exported later.
    static func quarantineSwiftDataStore() {
        #if DEBUG
        print("🧹 Attempting to quarantine SwiftData store...")
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

        let filesToMove = [
            storeURL, shmURL, walURL,
            sqliteURL, sqliteShmURL, sqliteWalURL
        ]

        let quarantineURL = quarantineDirectory(in: appSupportURL)
        var movedFiles = false

        for fileURL in filesToMove where fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.createDirectory(at: quarantineURL, withIntermediateDirectories: true)
                try fileManager.moveItem(at: fileURL,
                                         to: quarantineURL.appendingPathComponent(fileURL.lastPathComponent))
                #if DEBUG
                print("✅ Quarantined: \(fileURL.lastPathComponent)")
                #endif
                movedFiles = true
            } catch {
                #if DEBUG
                print("⚠️ Could not quarantine \(fileURL.lastPathComponent): \(error)")
                #endif
            }
        }

        if movedFiles {
            UserDefaults.standard.set(quarantineURL.path, forKey: lastQuarantineKey)
            #if DEBUG
            print("🧹 SwiftData store quarantined at \(quarantineURL.path)")
            #endif
        } else {
            #if DEBUG
            print("ℹ️ No SwiftData store files found to quarantine.")
            #endif
        }

        // Also set aside CloudKit metadata if present
        quarantineCloudKitMetadata(into: quarantineURL)
    }

    /// Permanently removes the store and every quarantined copy.
    /// Only for the explicit, user-confirmed Delete All Data action in Settings.
    static func deleteSwiftDataStoreForExplicitReset() {
        quarantineSwiftDataStore()

        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first else { return }
        let quarantineRoot = appSupportURL.appendingPathComponent("StoreQuarantine", isDirectory: true)
        do {
            if fileManager.fileExists(atPath: quarantineRoot.path) {
                try fileManager.removeItem(at: quarantineRoot)
            }
            UserDefaults.standard.removeObject(forKey: lastQuarantineKey)
        } catch {
            #if DEBUG
            print("⚠️ Could not delete quarantined store: \(error)")
            #endif
        }
    }

    /// Path of the most recent quarantine folder, if any.
    static let lastQuarantineKey = "SwiftDataLastQuarantinePath"

    private static func quarantineDirectory(in appSupportURL: URL) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return appSupportURL
            .appendingPathComponent("StoreQuarantine", isDirectory: true)
            .appendingPathComponent(formatter.string(from: Date()), isDirectory: true)
    }

    /// Moves CloudKit metadata that might be causing sync issues into the quarantine folder
    private static func quarantineCloudKitMetadata(into quarantineURL: URL) {
        let fileManager = FileManager.default

        // CloudKit metadata is typically stored in a .CloudKit subdirectory
        guard let documentsURL = fileManager.urls(for: .documentDirectory,
                                                  in: .userDomainMask).first else { return }

        let cloudKitURL = documentsURL.appendingPathComponent(".CloudKit")

        if fileManager.fileExists(atPath: cloudKitURL.path) {
            do {
                try fileManager.createDirectory(at: quarantineURL, withIntermediateDirectories: true)
                try fileManager.moveItem(at: cloudKitURL,
                                         to: quarantineURL.appendingPathComponent("CloudKit", isDirectory: true))
                #if DEBUG
                print("✅ Quarantined CloudKit metadata")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Could not quarantine CloudKit metadata: \(error)")
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