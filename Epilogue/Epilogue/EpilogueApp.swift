import SwiftUI
import SwiftData
import UserNotifications
import CloudKit
import BackgroundTasks

@main
struct EpilogueApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var showingCloudKitAlert = false
    @State private var cloudKitErrorMessage = ""

    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                ContentView()
                    .preferredColorScheme(.dark)
                    .modelContainer(container)
                    // .runSwiftDataMigrations() // DISABLED - causing data loss
                    .onAppear {
                        // API key is now built-in, no setup needed

                        // Clear command history on app launch to prevent artifacts
                        Task { @MainActor in
                            CommandHistoryManager.shared.clearHistory()
                        }

                        // Request notification permissions
                        requestNotificationPermissions()

                        // Check CloudKit status and show alert if needed
                        checkCloudKitStatus()

                        // Schedule background refresh for trending books
                        EnhancedTrendingBooksService.shared.scheduleBackgroundRefresh()

                        // Initialize offline services
                        if let container = modelContainer {
                            let context = ModelContext(container)
                            OfflineQueueManager.shared.configure(with: context)
                            OfflineCoverCacheService.shared.configure(with: context)

                            // Background task: Cache all library covers for offline use
                            Task.detached(priority: .background) { @MainActor in
                                // Wait 5 seconds after launch to avoid competing for resources
                                try? await Task.sleep(nanoseconds: 5_000_000_000)
                                await OfflineCoverCacheService.shared.cacheAllLibraryCovers()
                            }
                        }
                    }
                    .alert("iCloud Sync Required", isPresented: $showingCloudKitAlert) {
                        Button("Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        Button("Dismiss", role: .cancel) {}
                    } message: {
                        Text(cloudKitErrorMessage)
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

        // CRITICAL: Always use CloudKit for data persistence and sync
        // We'll retry multiple times to ensure CloudKit is properly initialized
        var retryCount = 0
        let maxRetries = 2  // Reduced from 3 to 2 for faster fallback
        var lastError: Error?

        while retryCount < maxRetries {
            do {
                print("🔄 Attempt \(retryCount + 1)/\(maxRetries): Initializing ModelContainer with CloudKit...")

                // CRITICAL: Use DEFAULT unnamed container to preserve existing user data
                // DO NOT use a custom name - that creates a new database!
                let cloudKitContainer = ModelConfiguration(
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .automatic
                )

                // SwiftData will automatically handle lightweight migration for optional fields
                modelContainer = try ModelContainer(
                    for: BookModel.self,
                         CapturedNote.self,
                         CapturedQuote.self,
                         CapturedQuestion.self,
                         AmbientSession.self,
                         QueuedQuestion.self,
                         ReadingSession.self,
                    configurations: cloudKitContainer
                )
                print("✅ ModelContainer initialized successfully with CloudKit")

                // Verify data after migration
                let context = ModelContext(modelContainer!)
                let bookDescriptor = FetchDescriptor<BookModel>()
                if let books = try? context.fetch(bookDescriptor) {
                    print("📚 Books in library after init: \(books.count)")
                    if let firstBook = books.first {
                        print("   Sample: '\(firstBook.title)' by \(firstBook.author)")
                        print("   Enrichment: \(firstBook.isEnriched ? "YES" : "not yet")")
                    }
                }
                DataRecovery.recordInitializationSuccess()
                
                // Store that we're using CloudKit
                UserDefaults.standard.set(true, forKey: "isUsingCloudKit")
                
                print("✅ ModelContainer initialized with CloudKit sync enabled")
                print("✅ Your data will sync across all your devices signed into iCloud")
                return
            } catch {
                lastError = error
                retryCount += 1
                
                if retryCount < maxRetries {
                    print("⚠️ CloudKit initialization attempt \(retryCount) failed: \(error.localizedDescription)")
                    print("🔄 Retrying in 0.5 seconds...")

                    // Brief delay before retry (reduced from 1s to 0.5s)
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                } else {
                    print("❌ All CloudKit attempts failed, will use fallback storage")
                }
            }
        }

        // If we get here, CloudKit initialization failed after all retries
        print("❌ CloudKit initialization failed after \(maxRetries) attempts")
        if let error = lastError {
            print("❌ Last error: \(error)")
            
            // Check if it's a network issue
            if error.localizedDescription.contains("network") || 
               error.localizedDescription.contains("Internet") ||
               error.localizedDescription.contains("offline") {
                print("📱 Appears to be a network connectivity issue")
                // Don't record as failure for network issues
            } else {
                DataRecovery.recordInitializationFailure()
            }
        }

        // IMPORTANT: We should not fall back to local-only storage
        // This causes data loss on reinstall. Instead, show an error to the user
        // and ask them to ensure they're signed into iCloud
        
        // For now, we'll initialize with appropriate fallback storage
        do {
            #if targetEnvironment(simulator)
            // On simulator, use DEFAULT local persistent storage (no custom name!)
            let localConfig = ModelConfiguration(
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none  // No CloudKit on simulator
            )
            modelContainer = try ModelContainer(
                for: BookModel.self,
                     CapturedNote.self,
                     CapturedQuote.self,
                     CapturedQuestion.self,
                     AmbientSession.self,
                     QueuedQuestion.self,
                     ReadingSession.self,
                configurations: localConfig
            )
            
            print("📱 Simulator detected: Using local persistent storage")
            print("⚠️ CloudKit sync disabled on simulator")
            
            // Mark as not using CloudKit but don't show error
            UserDefaults.standard.set(false, forKey: "isUsingCloudKit")
            UserDefaults.standard.set(false, forKey: "cloudKitInitializationFailed")
            
            #else
            // On real device, use DEFAULT local persistent storage as fallback
            // CRITICAL: No custom name - use default container to preserve data!
            print("⚠️ Using default local persistent storage as fallback on real device")
            let localConfig = ModelConfiguration(
                isStoredInMemoryOnly: false,  // Use persistent storage
                cloudKitDatabase: .none  // No CloudKit sync
            )
            modelContainer = try ModelContainer(
                for: BookModel.self,
                     CapturedNote.self,
                     CapturedQuote.self,
                     CapturedQuestion.self,
                     AmbientSession.self,
                     QueuedQuestion.self,
                     ReadingSession.self,
                configurations: localConfig
            )

            // Set a flag to show CloudKit error in the UI
            UserDefaults.standard.set(false, forKey: "isUsingCloudKit")
            UserDefaults.standard.set(true, forKey: "cloudKitInitializationFailed")

            print("⚠️ ModelContainer initialized with local storage only (no sync)")
            print("⚠️ User should sign into iCloud for data sync across devices")

            // Show alert to user
            cloudKitErrorMessage = "Your data is being saved locally. Sign into iCloud in Settings to sync across all your devices."
            showingCloudKitAlert = true
            #endif
        } catch {
            print("❌ Fatal: Could not initialize ModelContainer: \(error)")
            // Clean the store and ask user to restart
            DataRecovery.cleanSwiftDataStore()
            fatalError("Database error. Please ensure you're signed into iCloud and restart the app.")
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
    
    @MainActor
    private func checkCloudKitStatus() {
        // Check if CloudKit initialization failed
        if UserDefaults.standard.bool(forKey: "cloudKitInitializationFailed") {
            Task {
                // Check iCloud account status
                let container = CKContainer.default()
                let accountStatus = try? await container.accountStatus()
                
                switch accountStatus {
                case .available:
                    // iCloud is available but CloudKit failed - might be a temporary issue
                    cloudKitErrorMessage = "Your data couldn't sync to iCloud. Please check your internet connection and try restarting the app. Your reading data will be stored locally until sync is restored."
                case .noAccount:
                    cloudKitErrorMessage = "Please sign in to iCloud in Settings to sync your reading data across devices. Without iCloud, your data won't be backed up or available on other devices."
                case .restricted:
                    cloudKitErrorMessage = "iCloud access is restricted. Please check parental controls or device management settings."
                case .temporarilyUnavailable:
                    cloudKitErrorMessage = "iCloud is temporarily unavailable. Your data will sync once the service is restored."
                default:
                    cloudKitErrorMessage = "iCloud sync is unavailable. Please ensure you're signed into iCloud and have an internet connection."
                }
                
                showingCloudKitAlert = true
                
                // Clear the flag so we don't show this every time
                UserDefaults.standard.set(false, forKey: "cloudKitInitializationFailed")
            }
        }
    }
}