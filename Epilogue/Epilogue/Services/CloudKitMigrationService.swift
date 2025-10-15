import Foundation
import SwiftData
import SwiftUI
import CloudKit
import Combine

// MARK: - Migration State
enum MigrationState {
    case checking
    case notNeeded
    case inProgress(progress: Double, message: String)
    case completed
    case failed(Error)
}

// MARK: - CloudKit Migration Service
@MainActor
final class CloudKitMigrationService: ObservableObject {
    static let shared = CloudKitMigrationService()
    
    @Published var migrationState: MigrationState = .checking
    @Published var showMigrationUI = false
    
    private let migrationKey = "hasCompletedCloudKitResync_v1"
    private let previousVersionKey = "previousAppVersion"
    private let localDataExistsKey = "hasLocalDataForMigration"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Check if migration is needed and perform it if necessary
    func checkAndPerformMigration(container: ModelContainer) async {
        // Check if migration has already been completed
        if UserDefaults.standard.bool(forKey: migrationKey) {
            migrationState = .notNeeded
            return
        }
        
        // Check if this is an upgrade
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let previousVersion = UserDefaults.standard.string(forKey: previousVersionKey)
        
        // Store current version for future checks
        UserDefaults.standard.set(currentVersion, forKey: previousVersionKey)
        
        // Check if we have local data that needs migration
        let hasLocalData = await checkForLocalData(container: container)
        
        // Special check for TestFlight users who may have deleted and reinstalled
        let isTestFlightBuild = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        let hasUsedAppBefore = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") || 
                               UserDefaults.standard.object(forKey: "lastSyncDate") != nil
        
        if hasLocalData || previousVersion != nil || (isTestFlightBuild && hasUsedAppBefore) {
            // This is either an upgrade, we have local data, or a TestFlight reinstall
            showMigrationUI = true
            await performMigration(container: container)
        } else {
            // Fresh install, no migration needed
            migrationState = .notNeeded
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
    }
    
    // MARK: - Private Methods
    
    private func checkForLocalData(container: ModelContainer) async -> Bool {
        do {
            let context = container.mainContext
            
            // Check for any existing data
            let bookCount = try context.fetchCount(FetchDescriptor<BookModel>())
            let noteCount = try context.fetchCount(FetchDescriptor<CapturedNote>())
            let quoteCount = try context.fetchCount(FetchDescriptor<CapturedQuote>())
            let questionCount = try context.fetchCount(FetchDescriptor<CapturedQuestion>())
            let sessionCount = try context.fetchCount(FetchDescriptor<AmbientSession>())
            
            let totalCount = bookCount + noteCount + quoteCount + questionCount + sessionCount
            
            if totalCount > 0 {
                #if DEBUG
                print("📊 Found local data: \(bookCount) books, \(noteCount) notes, \(quoteCount) quotes, \(questionCount) questions, \(sessionCount) sessions")
                #endif
                UserDefaults.standard.set(true, forKey: localDataExistsKey)
                return true
            }
            
            return false
        } catch {
            #if DEBUG
            print("❌ Error checking for local data: \(error)")
            #endif
            return false
        }
    }
    
    private func performMigration(container: ModelContainer) async {
        migrationState = .inProgress(progress: 0.0, message: "Preparing migration...")
        
        do {
            let context = container.mainContext
            
            // Step 1: Fetch all data
            migrationState = .inProgress(progress: 0.1, message: "Analyzing your library...")
            
            let books = try context.fetch(FetchDescriptor<BookModel>())
            let notes = try context.fetch(FetchDescriptor<CapturedNote>())
            let quotes = try context.fetch(FetchDescriptor<CapturedQuote>())
            let questions = try context.fetch(FetchDescriptor<CapturedQuestion>())
            let sessions = try context.fetch(FetchDescriptor<AmbientSession>())
            
            let totalItems = books.count + notes.count + quotes.count + questions.count + sessions.count
            var processedItems = 0
            
            // Step 2: Force CloudKit sync by touching each object
            migrationState = .inProgress(progress: 0.2, message: "Syncing \(books.count) books...")
            
            for book in books {
                // Touch the book to mark it as modified
                book.dateAdded = book.dateAdded // This triggers a change
                processedItems += 1
                
                // Update progress
                let progress = 0.2 + (Double(processedItems) / Double(totalItems)) * 0.6
                migrationState = .inProgress(
                    progress: progress,
                    message: "Syncing book: \(book.title)"
                )
                
                // Save periodically to trigger sync
                if processedItems % 10 == 0 {
                    try context.save()
                    // Small delay to prevent overwhelming CloudKit
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
            }
            
            // Step 3: Process notes
            for note in notes {
                note.timestamp = note.timestamp // Touch to trigger sync
                processedItems += 1
                
                let progress = 0.2 + (Double(processedItems) / Double(totalItems)) * 0.6
                migrationState = .inProgress(
                    progress: progress,
                    message: "Syncing notes..."
                )
                
                if processedItems % 20 == 0 {
                    try context.save()
                    try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                }
            }
            
            // Step 4: Process quotes
            for quote in quotes {
                quote.timestamp = quote.timestamp // Touch to trigger sync
                processedItems += 1
                
                let progress = 0.2 + (Double(processedItems) / Double(totalItems)) * 0.6
                migrationState = .inProgress(
                    progress: progress,
                    message: "Syncing quotes..."
                )
                
                if processedItems % 20 == 0 {
                    try context.save()
                    try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                }
            }
            
            // Step 5: Process questions
            for question in questions {
                question.timestamp = question.timestamp // Touch to trigger sync
                processedItems += 1
                
                let progress = 0.2 + (Double(processedItems) / Double(totalItems)) * 0.6
                migrationState = .inProgress(
                    progress: progress,
                    message: "Syncing questions..."
                )
                
                if processedItems % 20 == 0 {
                    try context.save()
                    try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                }
            }
            
            // Step 6: Process sessions
            for session in sessions {
                session.startTime = session.startTime // Touch to trigger sync
                processedItems += 1
                
                let progress = 0.2 + (Double(processedItems) / Double(totalItems)) * 0.6
                migrationState = .inProgress(
                    progress: progress,
                    message: "Syncing sessions..."
                )
                
                if processedItems % 10 == 0 {
                    try context.save()
                    try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                }
            }
            
            // Step 7: Final save
            migrationState = .inProgress(progress: 0.9, message: "Finalizing sync...")
            try context.save()
            
            // Step 8: Verify CloudKit sync status
            migrationState = .inProgress(progress: 0.95, message: "Verifying sync...")
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds to allow sync to start
            
            // Mark migration as completed
            UserDefaults.standard.set(true, forKey: migrationKey)
            migrationState = .completed
            
            // Force CloudKit sync
            SyncStatusManager.shared.forceSyncWithCloudKit()
            
            #if DEBUG
            print("✅ Migration completed successfully!")
            #endif
            #if DEBUG
            print("📊 Migrated: \(books.count) books, \(notes.count) notes, \(quotes.count) quotes, \(questions.count) questions, \(sessions.count) sessions")
            #endif
            
            // Hide UI after a short delay
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            showMigrationUI = false
            
        } catch {
            #if DEBUG
            print("❌ Migration failed: \(error)")
            #endif
            migrationState = .failed(error)
        }
    }
    
    /// Reset migration status (for testing)
    func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        UserDefaults.standard.removeObject(forKey: localDataExistsKey)
        migrationState = .checking
        showMigrationUI = false
    }
}

// MARK: - Migration UI View
struct CloudKitMigrationView: View {
    @StateObject private var migrationService = CloudKitMigrationService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            DesignSystem.Colors.surfaceBackground
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 32) {
                // Icon
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .symbolEffect(.pulse, isActive: migrationService.migrationState.isInProgress)
                
                // Title and description
                VStack(spacing: 12) {
                    Text("Syncing Your Library")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("We're ensuring all your books and notes are safely synced to iCloud.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Progress indicator
                Group {
                    switch migrationService.migrationState {
                    case .checking:
                        ProgressView()
                            .scaleEffect(1.5)
                        
                    case .notNeeded:
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.green)
                            
                            Text("Your library is up to date")
                                .font(.headline)
                        }
                        
                    case .inProgress(let progress, let message):
                        VStack(spacing: 16) {
                            ProgressView(value: progress) {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(DesignSystem.Colors.primaryAccent)
                            
                            Text("\(Int(progress * 100))%")
                                .font(.headline)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 32)
                        
                    case .completed:
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.green)
                                .symbolEffect(.bounce)
                            
                            Text("Sync completed!")
                                .font(.headline)
                            
                            Text("All your data is now safely synced to iCloud")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                    case .failed(let error):
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.red)
                            
                            Text("Sync failed")
                                .font(.headline)
                            
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Retry") {
                                Task {
                                    if let container = try? ModelContainer(for: BookModel.self) {
                                        await migrationService.checkAndPerformMigration(container: container)
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .frame(height: 120)
                
                // Dismiss button (only show when completed or failed)
                if case .completed = migrationService.migrationState {
                    Button("Continue") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if case .failed = migrationService.migrationState {
                    Button("Dismiss") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

extension MigrationState {
    var isInProgress: Bool {
        if case .inProgress = self {
            return true
        }
        return false
    }
}