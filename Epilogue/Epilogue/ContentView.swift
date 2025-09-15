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
            .setupAmbientMode()
            .simplifiedAmbientPresentation()
            .onAppear {
                performInitialSetup()
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
}