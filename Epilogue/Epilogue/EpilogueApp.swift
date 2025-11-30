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
    @StateObject private var storeKit = SimplifiedStoreKitManager.shared

    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                ContentView()
                    .preferredColorScheme(.dark)
                    .modelContainer(container)
                    // .runSwiftDataMigrations() // DISABLED - causing data loss
                    .task {
                        // Load StoreKit products and check subscription status on app start
                        await storeKit.loadProducts()
                        await storeKit.checkSubscriptionStatus()
                    }
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

                            // Migrate cached colors to BookModel for widgets (one-time)
                            Task { @MainActor in
                                await migrateCachedColorsToBookModel(context: context)
                            }

                            // Update widgets with current book data
                            Task { @MainActor in
                                updateWidgetData(context: context)
                            }
                        }
                    }
                    .alert("iCloud Sync", isPresented: $showingCloudKitAlert) {
                        Button("OK", role: .cancel) {}
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
                #if DEBUG
                print("✅ Notification permissions granted")
                #endif
            } else if let error = error {
                #if DEBUG
                print("❌ Notification permission error: \(error)")
                #endif
            } else {
                #if DEBUG
                print("⚠️ Notification permissions denied")
                #endif
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
                #if DEBUG
                print("🔄 Attempt \(retryCount + 1)/\(maxRetries): Initializing ModelContainer with CloudKit...")
                #endif

                // CRITICAL: Use DEFAULT unnamed container to preserve existing user data
                // DO NOT use a custom ModelConfiguration name - that creates a new database!
                // .automatic will use the CloudKit container from entitlements (iCloud.com.krispuckett.Epilogue)
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
                         ReadingJourney.self,
                         JourneyBook.self,
                         JourneyMilestone.self,
                         BookMilestone.self,
                         ReadingHabitPlan.self,
                         HabitDay.self,
                    configurations: cloudKitContainer
                )
                #if DEBUG
                print("✅ ModelContainer initialized successfully with CloudKit")
                #endif

                // Verify data after migration
                let context = ModelContext(modelContainer!)
                let bookDescriptor = FetchDescriptor<BookModel>()
                if let books = try? context.fetch(bookDescriptor) {
                    #if DEBUG
                    print("📚 Books in library after init: \(books.count)")
                    #endif
                    if let firstBook = books.first {
                        #if DEBUG
                        print("   Sample: '\(firstBook.title)' by \(firstBook.author)")
                        #endif
                        #if DEBUG
                        print("   Enrichment: \(firstBook.isEnriched ? "YES" : "not yet")")
                        #endif
                    }
                }
                DataRecovery.recordInitializationSuccess()
                
                // Store that we're using CloudKit
                UserDefaults.standard.set(true, forKey: "isUsingCloudKit")
                
                #if DEBUG
                print("✅ ModelContainer initialized with CloudKit sync enabled")
                #endif
                #if DEBUG
                print("✅ Your data will sync across all your devices signed into iCloud")
                #endif
                return
            } catch {
                lastError = error
                retryCount += 1
                
                if retryCount < maxRetries {
                    #if DEBUG
                    print("⚠️ CloudKit initialization attempt \(retryCount) failed:")
                    #endif
                    #if DEBUG
                    print("   Error: \(error.localizedDescription)")
                    #endif
                    #if DEBUG
                    print("   Full error: \(error)")
                    #endif
                    #if DEBUG
                    print("🔄 Retrying in 0.5 seconds...")
                    #endif

                    // Brief delay before retry (reduced from 1s to 0.5s)
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                } else {
                    #if DEBUG
                    print("❌ All CloudKit attempts failed, will use fallback storage")
                    #endif
                    #if DEBUG
                    print("   Final error: \(error)")
                    #endif
                }
            }
        }

        // If we get here, CloudKit initialization failed after all retries
        #if DEBUG
        print("❌ CloudKit initialization failed after \(maxRetries) attempts")
        #endif
        if let error = lastError {
            #if DEBUG
            print("❌ Last error description: \(error.localizedDescription)")
            #endif
            #if DEBUG
            print("❌ Last error full: \(error)")
            #endif
            #if DEBUG
            print("❌ Error domain: \((error as NSError).domain)")
            #endif
            #if DEBUG
            print("❌ Error code: \((error as NSError).code)")
            #endif

            // Check if it's a network issue
            if error.localizedDescription.contains("network") ||
               error.localizedDescription.contains("Internet") ||
               error.localizedDescription.contains("offline") {
                #if DEBUG
                print("📱 Appears to be a network connectivity issue")
                #endif
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
                     ReadingJourney.self,
                     JourneyBook.self,
                     JourneyMilestone.self,
                     BookMilestone.self,
                     ReadingHabitPlan.self,
                     HabitDay.self,
                configurations: localConfig
            )

            #if DEBUG
            print("📱 Simulator detected: Using local persistent storage")
            #endif
            #if DEBUG
            print("⚠️ CloudKit sync disabled on simulator")
            #endif
            
            // Mark as not using CloudKit but don't show error
            UserDefaults.standard.set(false, forKey: "isUsingCloudKit")
            UserDefaults.standard.set(false, forKey: "cloudKitInitializationFailed")
            
            #else
            // On real device, use DEFAULT local persistent storage as fallback
            // CRITICAL: No custom name - use default container to preserve data!
            #if DEBUG
            print("⚠️ Using default local persistent storage as fallback on real device")
            #endif
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
                     ReadingJourney.self,
                     JourneyBook.self,
                     JourneyMilestone.self,
                     BookMilestone.self,
                     ReadingHabitPlan.self,
                     HabitDay.self,
                configurations: localConfig
            )

            // Set a flag to show CloudKit error in the UI
            UserDefaults.standard.set(false, forKey: "isUsingCloudKit")
            UserDefaults.standard.set(true, forKey: "cloudKitInitializationFailed")

            #if DEBUG
            print("⚠️ ModelContainer initialized with local storage only (no sync)")
            #endif
            #if DEBUG
            print("⚠️ User should sign into iCloud for data sync across devices")
            #endif

            // Show alert to user (optional - user can check Settings view)
            cloudKitErrorMessage = "Your data is saved locally. To sync across devices, enable iCloud in system Settings → [Your Name] → iCloud → iCloud Drive."
            showingCloudKitAlert = true
            #endif
        } catch {
            #if DEBUG
            print("❌ Fatal: Could not initialize ModelContainer: \(error)")
            #endif

            // Clean the store
            DataRecovery.cleanSwiftDataStore()

            // Create in-memory container as absolute emergency fallback
            // This prevents app crash and allows user to see error message
            do {
                let inMemoryConfig = ModelConfiguration(
                    isStoredInMemoryOnly: true,  // Temporary in-memory only
                    cloudKitDatabase: .none
                )
                modelContainer = try ModelContainer(
                    for: BookModel.self,
                         CapturedNote.self,
                         CapturedQuote.self,
                         CapturedQuestion.self,
                         AmbientSession.self,
                         QueuedQuestion.self,
                         ReadingSession.self,
                         ReadingJourney.self,
                         JourneyBook.self,
                         JourneyMilestone.self,
                         BookMilestone.self,
                         ReadingHabitPlan.self,
                         HabitDay.self,
                    configurations: inMemoryConfig
                )

                // Show critical error to user
                cloudKitErrorMessage = "Critical database error. Your data is temporarily unavailable. Please restart the app. If this persists, reinstall the app or contact support."
                showingCloudKitAlert = true

                #if DEBUG
                print("⚠️ Using emergency in-memory container to prevent crash")
                #endif
            } catch {
                // If even in-memory container fails, we have bigger problems
                // Log the error but don't crash - show loading screen forever
                #if DEBUG
                print("❌ Even in-memory container failed: \(error)")
                #endif
                cloudKitErrorMessage = "Critical app error. Please reinstall Epilogue or contact support."
                showingCloudKitAlert = true
            }
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
    
    private func updateWidgetData(context: ModelContext) {
        #if DEBUG
        print("📱 Updating widget data...")
        #endif

        // First, check ALL books to see what we have
        let allBooksDescriptor = FetchDescriptor<BookModel>()
        if let allBooks = try? context.fetch(allBooksDescriptor) {
            #if DEBUG
            print("📚 Total books in library: \(allBooks.count)")
            #endif
            for book in allBooks.prefix(5) {
                #if DEBUG
                print("   - '\(book.title)' status: \(book.readingStatus)")
                #endif
            }
        }

        let descriptor = FetchDescriptor<BookModel>(
            predicate: #Predicate { $0.readingStatus == "Currently Reading" },
            sortBy: [SortDescriptor(\BookModel.dateAdded, order: .reverse)]
        )

        guard let currentBook = try? context.fetch(descriptor).first else {
            #if DEBUG
            print("❌ No currently reading book for widgets")
            #endif
            BookWidgetUpdater.shared.clearCurrentBook()
            return
        }

        #if DEBUG
        print("✅ Found currently reading book: \(currentBook.title)")
        #endif
        #if DEBUG
        print("   Cover URL: \(currentBook.coverImageURL ?? "none")")
        #endif
        #if DEBUG
        print("   Colors: \(currentBook.extractedColors?.count ?? 0) colors")
        #endif
        BookWidgetUpdater.shared.updateCurrentBook(from: currentBook)
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

    @MainActor
    private func migrateCachedColorsToBookModel(context: ModelContext) async {
        // Check if migration already ran
        if UserDefaults.standard.bool(forKey: "didMigrateCachedColorsToBookModel") {
            return
        }

        #if DEBUG
        print("🎨 Migrating cached colors to BookModel for widgets...")
        #endif

        let descriptor = FetchDescriptor<BookModel>()
        guard let allBooks = try? context.fetch(descriptor) else {
            return
        }

        var migratedCount = 0

        for bookModel in allBooks {
            // Skip if already has colors
            if let colors = bookModel.extractedColors, !colors.isEmpty {
                continue
            }

            // Check if there's a cached palette
            let bookID = bookModel.localId
            if let cachedPalette = await BookColorPaletteCache.shared.getCachedPalette(for: bookID) {
                bookModel.extractedColors = [
                    cachedPalette.primary.toHexString(),
                    cachedPalette.secondary.toHexString(),
                    cachedPalette.accent.toHexString(),
                    cachedPalette.background.toHexString()
                ]
                migratedCount += 1
                #if DEBUG
                print("  ✅ Migrated colors for: \(bookModel.title)")
                #endif
            }
        }

        #if DEBUG
        print("🎨 Migration complete: \(migratedCount) books updated with colors")
        #endif

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: "didMigrateCachedColorsToBookModel")
    }
}