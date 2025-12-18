import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "ContentView")

/// Main content view - Refactored to under 100 lines
/// Delegates all responsibilities to specialized coordinators
struct ContentView: View {
    // MARK: - State Objects
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    @StateObject private var ambientCoordinator = EpilogueAmbientCoordinator.shared
    @StateObject private var appStateCoordinator = AppStateCoordinator()
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var notesViewModel = NotesViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var whatsNewManager = WhatsNewManager.shared

    // MARK: - State
    @State private var selectedTab = 0
    @State private var showQuickActionCard = false
    @State private var showReturnCard = false
    @FocusState private var isInputFocused: Bool

    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body
    var body: some View {
        mainContent
            .preferredColorScheme(.dark)
            .withErrorHandling()
            .withOnboarding()
            .environmentObject(libraryViewModel)
            .environmentObject(notesViewModel)
            .environmentObject(navigationCoordinator)
            .environmentObject(appStateCoordinator)
            .environmentObject(deepLinkHandler)
            .setupAppearanceConfiguration()
            .setupSheetPresentations()
            .setupAmbientMode(libraryViewModel: libraryViewModel, notesViewModel: notesViewModel, appStateCoordinator: appStateCoordinator)
            .withCloudKitMigration()
            .onAppear {
                performInitialSetup()
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchToLibraryTab"))) { _ in
                // Switch to library tab when navigating from ambient mode
                selectedTab = 0
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowQuickActionCard"))) { _ in
                // Show unified input card from anywhere in the app
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showQuickActionCard = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenAmbientModeFromIntent"))) { notification in
                // Handle Siri "Continue Reading" intent
                handleAmbientModeIntent(notification)
            }
            .onOpenURL { url in
                // Handle deep links from widgets and external sources
                deepLinkHandler.handle(url: url)
            }
            // MARK: - Global Note/Quote Persistence
            // These handlers ensure notes and quotes are saved to SwiftData
            // regardless of which tab the user is on
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CreateNewNote"))) { notification in
                handleCreateNewNote(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SaveQuote"))) { notification in
                handleSaveQuote(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowReturnCard"))) { _ in
                // Developer trigger from Gandalf Mode
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showReturnCard = true
                }
            }
            .sheet(isPresented: $whatsNewManager.shouldShow) {
                whatsNewManager.markAsShown()
            } content: {
                WhatsNewView()
            }
            .glassToast(isShowing: $appStateCoordinator.showingGlassToast, message: appStateCoordinator.toastMessage)
            .id(themeManager.currentTheme) // Force complete view recreation on theme change
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ZStack {
            // Use subtle themed gradient like original amber
            SubtleThemedBackground()
                .ignoresSafeArea()

            NavigationContainer(selectedTab: $selectedTab)
        }
        // Action bar - sits above tab bar
        .overlay(alignment: .bottom) {
            if !showQuickActionCard && !notesViewModel.isEditingNote {
                SimpleActionBar(showCard: $showQuickActionCard)
                    .environmentObject(libraryViewModel)
                    .padding(.bottom, 54)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
        }
        // Input card overlay when plus is tapped
        .overlay(alignment: .bottom) {
            if showQuickActionCard {
                UnifiedQuickActionCard(isPresented: $showQuickActionCard)
                    .environmentObject(libraryViewModel)
                    .environmentObject(notesViewModel)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showQuickActionCard)
            }
        }
        .overlay(alignment: .bottom) {
            CommandInputOverlay(
                appStateCoordinator: appStateCoordinator,
                libraryViewModel: libraryViewModel,
                notesViewModel: notesViewModel,
                modelContext: modelContext,
                isInputFocused: $isInputFocused
            )
        }
        // Return card overlay - animates from Dynamic Island on cold launch
        .overlay {
            if showReturnCard {
                ReturnCardOverlay {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showReturnCard = false
                    }
                    ReturnCardManager.shared.markCardShown()
                }
            }
        }
    }

    // MARK: - Initial Setup
    private func performInitialSetup() {
        logger.info("Performing initial app setup")

        // Set up coordinator dependencies
        appStateCoordinator.libraryViewModel = libraryViewModel
        appStateCoordinator.notesViewModel = notesViewModel
        deepLinkHandler.navigationCoordinator = navigationCoordinator

        // Check if we should show return card (cold start with currently reading book)
        Task { @MainActor in
            // Small delay to let SwiftData query complete
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

            if ReturnCardManager.shared.shouldShowReturnCard {
                logger.info("🎴 Cold start detected - starting Welcome Back Live Activity")

                // Find currently reading book
                let descriptor = FetchDescriptor<BookModel>(
                    predicate: #Predicate { $0.readingStatus == "Currently Reading" },
                    sortBy: [SortDescriptor(\BookModel.dateAdded, order: .reverse)]
                )

                if let book = try? modelContext.fetch(descriptor).first {
                    // Start Live Activity in Dynamic Island
                    WelcomeBackActivityManager.shared.startActivity(for: book)
                } else {
                    // Fallback: any book
                    let anyBookDescriptor = FetchDescriptor<BookModel>(
                        sortBy: [SortDescriptor(\BookModel.dateAdded, order: .reverse)]
                    )
                    if let book = try? modelContext.fetch(anyBookDescriptor).first {
                        WelcomeBackActivityManager.shared.startActivity(for: book)
                    }
                }
            }
        }

        // Clear command history
        Task { @MainActor in
            CommandHistoryManager.shared.clearHistory()
        }

        // Clean caches after delay
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            ResponseCache.shared.cleanExpiredEntries()
        }

        // Migrate UserDefaults books to SwiftData (one-time)
        // This ensures all existing books have BookModels for enrichment
        Task { @MainActor in
            await BookModelMigrationService.shared.migrateIfNeeded(
                libraryViewModel: libraryViewModel,
                modelContext: modelContext
            )
        }

        // Check for CloudKit migration
        // DISABLED - causing data loss
        // Task { @MainActor in
        //     await CloudKitMigrationService.shared.checkAndPerformMigration(container: modelContext.container)
        // }

        // Prepare haptics
        SensoryFeedback.light()
    }

    // MARK: - Scene Phase Handling
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            logger.info("App became active")
            // Record activity for return card timing
            ReturnCardManager.shared.recordActivity()
        case .inactive:
            logger.info("App became inactive")
            // Don't end Live Activity here - let it persist
        case .background:
            logger.info("App entered background")
            // Don't end Live Activity here - Live Activities should persist in background
            // They will be ended when the user explicitly exits ambient mode
            // Record activity timestamp for return card cold start detection
            ReturnCardManager.shared.recordActivity()
        @unknown default:
            break
        }
    }

    // MARK: - App Intents Handling
    private func handleAmbientModeIntent(_ notification: Notification) {
        logger.info("🎙️ Siri triggered: Continue Reading intent")

        guard let bookId = notification.userInfo?["bookId"] as? String else {
            logger.error("No book ID provided in intent notification")
            return
        }

        // Find the book in the library
        guard let book = libraryViewModel.books.first(where: { $0.id == bookId }) else {
            logger.error("Could not find book with ID: \(bookId)")
            return
        }

        logger.info("📚 Opening Ambient Mode with: \(book.title)")

        // Launch ambient mode with the selected book
        ambientCoordinator.launch(from: .general, book: book)
    }

    // MARK: - Note/Quote Persistence Handlers

    private func handleCreateNewNote(_ notification: Notification) {
        guard let data = notification.object as? [String: Any],
              let content = data["content"] as? String else {
            logger.warning("CreateNewNote: Missing content in notification")
            return
        }

        // Validate content isn't empty
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            logger.warning("CreateNewNote: Content is empty after trimming - skipping save")
            return
        }

        let bookId = data["bookId"] as? String
        let bookTitle = data["bookTitle"] as? String
        let bookAuthor = data["bookAuthor"] as? String

        logger.info("📝 Creating note with content: \(trimmedContent.prefix(50))...")

        // Find or create BookModel
        var bookModel: BookModel? = nil
        if let bookId = bookId {
            let descriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate { book in book.localId == bookId }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                bookModel = existing
                logger.info("📝 Found existing BookModel for note")
            } else if let libraryBook = libraryViewModel.books.first(where: { $0.localId.uuidString == bookId }) {
                let newModel = BookModel(from: libraryBook)
                modelContext.insert(newModel)
                bookModel = newModel
                logger.info("📝 Created new BookModel for note")
            }
        }

        let note = CapturedNote(
            content: trimmedContent,
            book: bookModel,
            pageNumber: nil,
            timestamp: Date(),
            source: .manual
        )
        modelContext.insert(note)

        do {
            try modelContext.save()
            logger.info("✅ Note saved to SwiftData with ID: \(note.id?.uuidString ?? "nil")")

            // Index for Spotlight
            Task {
                await SpotlightIndexingService.shared.indexNote(note)
            }

            // Show success toast
            appStateCoordinator.toastMessage = bookTitle.map { "Note saved to \($0)" } ?? "Note saved"
            withAnimation { appStateCoordinator.showingGlassToast = true }
        } catch {
            logger.error("❌ Failed to save note: \(error.localizedDescription)")
            // Show error toast
            appStateCoordinator.toastMessage = "Failed to save note"
            withAnimation { appStateCoordinator.showingGlassToast = true }
        }
    }

    private func handleSaveQuote(_ notification: Notification) {
        guard let data = notification.object as? [String: Any],
              let quoteText = data["quote"] as? String else {
            logger.warning("SaveQuote: Missing quote in notification")
            return
        }

        // Validate quote text isn't empty
        let trimmedQuote = quoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuote.isEmpty else {
            logger.warning("SaveQuote: Quote text is empty after trimming - skipping save")
            return
        }

        let attribution = data["attribution"] as? String
        let bookId = data["bookId"] as? String
        let bookTitle = data["bookTitle"] as? String
        let bookAuthor = data["bookAuthor"] as? String
        let pageNumber = data["pageNumber"] as? Int

        logger.info("📖 Creating quote: \(trimmedQuote.prefix(50))...")

        // Find or create BookModel
        var bookModel: BookModel? = nil

        // First try by ID
        if let bookId = bookId {
            let descriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate { book in book.localId == bookId }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                bookModel = existing
                logger.info("📖 Found existing BookModel for quote")
            } else if let libraryBook = libraryViewModel.books.first(where: { $0.localId.uuidString == bookId }) {
                let newModel = BookModel(from: libraryBook)
                modelContext.insert(newModel)
                bookModel = newModel
                logger.info("📖 Created new BookModel for quote")
            }
        }

        // If no bookModel yet but we have title, try to find or create by title
        if bookModel == nil, let title = bookTitle {
            let descriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate { book in book.title == title }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                bookModel = existing
                logger.info("📖 Found BookModel by title for quote")
            } else {
                let newModel = BookModel(
                    id: UUID().uuidString,
                    title: title,
                    author: bookAuthor ?? attribution ?? "Unknown"
                )
                modelContext.insert(newModel)
                bookModel = newModel
                logger.info("📖 Created new BookModel by title for quote")
            }
        }

        let quote = CapturedQuote(
            text: trimmedQuote,
            book: bookModel,
            author: attribution,
            pageNumber: pageNumber,
            timestamp: Date(),
            source: .manual
        )
        modelContext.insert(quote)

        do {
            try modelContext.save()
            logger.info("✅ Quote saved to SwiftData with ID: \(quote.id?.uuidString ?? "nil")")

            // Index for Spotlight
            Task {
                await SpotlightIndexingService.shared.indexQuote(quote)
            }

            // Show success toast
            appStateCoordinator.toastMessage = bookTitle.map { "Quote saved to \($0)" } ?? "Quote saved"
            withAnimation { appStateCoordinator.showingGlassToast = true }
        } catch {
            logger.error("❌ Failed to save quote: \(error.localizedDescription)")
            // Show error toast
            appStateCoordinator.toastMessage = "Failed to save quote"
            withAnimation { appStateCoordinator.showingGlassToast = true }
        }
    }
}
