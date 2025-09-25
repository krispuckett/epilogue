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
    @StateObject private var deepLinkHandler = DeepLinkHandler()
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var notesViewModel = NotesViewModel()
    @StateObject private var themeManager = ThemeManager.shared

    // MARK: - State
    @State private var selectedTab = 0
    @State private var showQuickActionCard = false
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
            .setupAmbientMode(libraryViewModel: libraryViewModel, notesViewModel: notesViewModel)
            .simplifiedAmbientPresentation()
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
            .id(themeManager.currentTheme) // Force complete view recreation on theme change
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Use subtle themed gradient like original amber
            SubtleThemedBackground()
                .ignoresSafeArea()

            NavigationContainer(selectedTab: $selectedTab)

            // Action bar hidden when card is shown or when editing note
            if !showQuickActionCard && !notesViewModel.isEditingNote {
                VStack {
                    Spacer()
                    SimpleActionBar(showCard: $showQuickActionCard)
                        .environmentObject(libraryViewModel)
                        .padding(.bottom, 54)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }

            // Input card overlay when plus is tapped
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
        
    }

    // MARK: - Initial Setup
    private func performInitialSetup() {
        logger.info("Performing initial app setup")

        // Set up coordinator dependencies
        appStateCoordinator.libraryViewModel = libraryViewModel
        appStateCoordinator.notesViewModel = notesViewModel
        deepLinkHandler.navigationCoordinator = navigationCoordinator

        // Clear command history
        Task { @MainActor in
            CommandHistoryManager.shared.clearHistory()
        }

        // Clean caches after delay
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            ResponseCache.shared.cleanExpiredEntries()
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
        case .inactive:
            logger.info("App became inactive")
            // Don't end Live Activity here - let it persist
        case .background:
            logger.info("App entered background")
            // Don't end Live Activity here - Live Activities should persist in background
            // They will be ended when the user explicitly exits ambient mode
        @unknown default:
            break
        }
    }
}
