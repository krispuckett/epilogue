import Foundation
import SwiftData
import CloudKit
import Combine

/// A safety service to verify CloudKit data integrity before migrations
@MainActor
final class CloudKitSafetyCheck: ObservableObject {
    static let shared = CloudKitSafetyCheck()
    
    private init() {}
    
    /// Check if we have the correct model schema
    func verifyModelSchema(in container: ModelContainer) async -> (isValid: Bool, message: String) {
        do {
            let context = container.mainContext
            
            // Try to fetch from both possible schemas to detect which one is active
            var hasNewSchema = false
            var newDataCount = 0
            
            // Check for new schema (BookModel, CapturedNote, etc.)
            do {
                let bookCount = try context.fetchCount(FetchDescriptor<BookModel>())
                let noteCount = try context.fetchCount(FetchDescriptor<CapturedNote>())
                let quoteCount = try context.fetchCount(FetchDescriptor<CapturedQuote>())
                newDataCount = bookCount + noteCount + quoteCount
                hasNewSchema = true
                #if DEBUG
                print("✅ Found new schema with \(newDataCount) items")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ New schema not found: \(error)")
                #endif
            }
            
            // We can't check for old schema directly due to type conflicts
            // Instead, check UserDefaults for migration markers
            let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            
            // Determine the state
            if hasNewSchema && newDataCount > 0 {
                return (true, "Schema is valid with \(newDataCount) items")
            } else if hasCompletedOnboarding && !hasNewSchema {
                // User has used the app before but we can't find data
                return (false, "Warning: Previous data may exist in old schema format")
            } else {
                // Fresh install or no data
                return (true, "No data found - fresh installation")
            }
            
        } catch {
            return (false, "Error checking schema: \(error.localizedDescription)")
        }
    }
    
    /// Check CloudKit account status
    func checkCloudKitAccount() async -> (available: Bool, message: String) {
        do {
            let container = CKContainer.default()
            let status = try await container.accountStatus()
            
            switch status {
            case .available:
                return (true, "iCloud account is available")
            case .noAccount:
                return (false, "No iCloud account - please sign in to Settings")
            case .restricted:
                return (false, "iCloud is restricted by parental controls")
            case .temporarilyUnavailable:
                return (false, "iCloud is temporarily unavailable")
            case .couldNotDetermine:
                return (false, "Could not determine iCloud status")
            @unknown default:
                return (false, "Unknown iCloud status")
            }
        } catch {
            return (false, "Error checking iCloud: \(error.localizedDescription)")
        }
    }
    
    /// Safely backup critical user data before any migration
    func backupCriticalData(from container: ModelContainer) async {
        do {
            let context = container.mainContext
            
            // Create a backup dictionary
            var backup: [String: Any] = [:]
            
            // Try to fetch and backup data from the current schema
            do {
                let books = try context.fetch(FetchDescriptor<BookModel>())
                let bookData = books.map { book in
                    [
                        "id": book.id,
                        "title": book.title,
                        "author": book.author,
                        "dateAdded": book.dateAdded.timeIntervalSince1970,
                        "readingStatus": book.readingStatus,
                        "currentPage": book.currentPage
                    ]
                }
                backup["books"] = bookData
                
                let notes = try context.fetch(FetchDescriptor<CapturedNote>())
                backup["noteCount"] = notes.count
                
                let quotes = try context.fetch(FetchDescriptor<CapturedQuote>())
                backup["quoteCount"] = quotes.count
                
            } catch {
                #if DEBUG
                print("⚠️ Could not backup current schema data: \(error)")
                #endif
            }
            
            // Save backup to UserDefaults with timestamp
            backup["timestamp"] = Date().timeIntervalSince1970
            backup["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            
            if let data = try? JSONSerialization.data(withJSONObject: backup) {
                UserDefaults.standard.set(data, forKey: "cloudkit_safety_backup")
                #if DEBUG
                print("✅ Created safety backup with \(backup["books"] as? [[String: Any]])?.count ?? 0) books")
                #endif
            }
            
        } catch {
            #if DEBUG
            print("❌ Backup failed: \(error)")
            #endif
        }
    }
    
    /// Check if we have a recent backup
    func hasRecentBackup() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "cloudkit_safety_backup"),
              let backup = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timestamp = backup["timestamp"] as? TimeInterval else {
            return false
        }
        
        // Consider backup recent if less than 7 days old
        let backupDate = Date(timeIntervalSince1970: timestamp)
        return Date().timeIntervalSince(backupDate) < 7 * 24 * 60 * 60
    }
    
    /// Get a summary of what will happen during migration
    func getMigrationSummary(for container: ModelContainer) async -> String {
        let schemaCheck = await verifyModelSchema(in: container)
        let cloudKitCheck = await checkCloudKitAccount()
        let hasBackup = hasRecentBackup()
        
        var summary = "Migration Status:\n"
        summary += "• Schema: \(schemaCheck.message)\n"
        summary += "• iCloud: \(cloudKitCheck.message)\n"
        summary += "• Backup: \(hasBackup ? "Recent backup available" : "No recent backup")\n"
        
        if !schemaCheck.isValid || !cloudKitCheck.available {
            summary += "\n⚠️ Warning: Migration may not proceed safely. Please ensure:\n"
            summary += "1. You're signed into iCloud\n"
            summary += "2. You have a stable internet connection\n"
            summary += "3. The app has permission to use iCloud\n"
        }
        
        return summary
    }
}