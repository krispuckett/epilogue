import SwiftUI
import SwiftData
import UserNotifications

@main
struct EpilogueApp: App {
    @State private var modelContainer: ModelContainer?
    
    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                ContentView()
                    .preferredColorScheme(.dark)
                    .modelContainer(container)
                    .runSwiftDataMigrations()
                    .onAppear {
                        // API key is now built-in, no setup needed
                        
                        // Clear command history on app launch to prevent artifacts
                        Task { @MainActor in
                            CommandHistoryManager.shared.clearHistory()
                        }
                        
                        // Request notification permissions
                        requestNotificationPermissions()
                    }
            } else {
                // Minimal launch screen while loading
                ZStack {
                    DesignSystem.Colors.surfaceBackground
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .tint(DesignSystem.Colors.primaryAccent)
                        .scaleEffect(1.5)
                }
                .task {
                    await setupModelContainer()
                }
            }
        }
    }
    
    // Removed - API key is now built-in
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            #if DEBUG
            if granted {
                print("✅ Notification permissions granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            } else {
                print("⚠️ Notification permissions denied")
            }
            #endif
        }
        
        // Set the delegate to handle notification taps
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    @MainActor
    private func setupModelContainer() async {
        // Clear image caches on app launch (temporary for debugging)
        DisplayedImageStore.clearAllCaches()

        // Create Application Support directory if it doesn't exist to prevent CoreData warnings
        createApplicationSupportDirectoryIfNeeded()

        // Check if we should clean the database due to repeated failures
        if DataRecovery.shouldAttemptRecovery() {
            DataRecovery.cleanSwiftDataStore()
        }

        let schema = Schema([
            BookModel.self,
            CapturedNote.self,
            CapturedQuote.self,
            CapturedQuestion.self,
            AmbientSession.self,
            QueuedQuestion.self
        ])

        // First, try with CloudKit (preferred for sync)
        do {
            let cloudKitConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic  // Enable CloudKit sync
            )
            modelContainer = try ModelContainer(for: schema, configurations: [cloudKitConfig])
            DataRecovery.recordInitializationSuccess()
            print("✅ ModelContainer initialized with CloudKit sync enabled")
            return
        } catch {
            print("⚠️ CloudKit initialization failed: \(error)")
            // Only record as failure if it's not a network issue
            if !error.localizedDescription.contains("network") {
                DataRecovery.recordInitializationFailure()
            }
        }

        // Fallback: Try local storage without CloudKit
        do {
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none  // No CloudKit, but data persists locally
            )
            modelContainer = try ModelContainer(for: schema, configurations: [localConfig])
            DataRecovery.recordInitializationSuccess()
            print("⚠️ ModelContainer initialized WITHOUT CloudKit (local only)")
            print("ℹ️ Data will not sync across devices")
            return
        } catch {
            print("❌ Local initialization also failed: \(error)")
            DataRecovery.recordInitializationFailure()
        }

        // Last resort: In-memory only
        do {
            let memoryConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            modelContainer = try ModelContainer(for: schema, configurations: [memoryConfig])
            print("⚠️ ModelContainer initialized in-memory only (data won't persist)")
            print("⚠️ Please use 'Delete All Data' in Settings to fix persistent storage")
        } catch {
            print("❌ Fatal: Could not initialize ModelContainer: \(error)")
            // Clean the store and ask user to restart
            DataRecovery.cleanSwiftDataStore()
            fatalError("Database error. Please restart the app.")
        }
    }
    
    private func createApplicationSupportDirectoryIfNeeded() {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, 
                                                   in: .userDomainMask).first else { return }
        
        // Check if directory exists
        if !fileManager.fileExists(atPath: appSupportURL.path) {
            do {
                // Create the directory
                try fileManager.createDirectory(at: appSupportURL, 
                                              withIntermediateDirectories: true, 
                                              attributes: nil)
                #if DEBUG
                print("✅ Created Application Support directory")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Could not create Application Support directory: \(error)")
                #endif
            }
        }
    }
}