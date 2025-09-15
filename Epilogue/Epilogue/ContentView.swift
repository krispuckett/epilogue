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

    // MARK: - State
    @State private var selectedTab = 0
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
    }

    // MARK: - Main Content
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            DesignSystem.Colors.surfaceBackground
                .ignoresSafeArea()

            NavigationContainer(selectedTab: $selectedTab)
                .safeAreaInset(edge: .bottom) {
                    if !appStateCoordinator.showingCommandInput && !notesViewModel.isEditingNote {
                        EnhancedQuickActionsBar()
                            .environmentObject(libraryViewModel)
                            .environmentObject(notesViewModel)
                            .padding(.bottom, 56)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                    }
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