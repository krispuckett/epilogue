import SwiftUI
import Combine
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "Onboarding")

/// Manages onboarding flow and first launch experience
@MainActor
final class OnboardingCoordinator: ObservableObject {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Published var showOnboarding = false

    init() {
        checkOnboardingStatus()
    }

    deinit {
        logger.debug("OnboardingCoordinator deallocated")
    }

    // MARK: - Public Methods

    func checkOnboardingStatus() {
        if !hasCompletedOnboarding {
            logger.info("First launch detected, showing onboarding")
            showOnboarding = true
        } else {
            logger.debug("User has completed onboarding")
        }
    }

    func completeOnboarding() {
        logger.info("Onboarding completed")
        hasCompletedOnboarding = true
        showOnboarding = false

        // Trigger any post-onboarding setup
        Task {
            await performPostOnboardingSetup()
        }
    }

    func resetOnboarding() {
        logger.info("Resetting onboarding status")
        hasCompletedOnboarding = false
        showOnboarding = true
    }

    // MARK: - Private Methods

    private func performPostOnboardingSetup() async {
        logger.debug("Performing post-onboarding setup")

        // Request permissions
        await requestNotificationPermissions()

        // Preload any necessary data
        await preloadEssentialData()

        // Set up default preferences
        setupDefaultPreferences()
    }

    private func requestNotificationPermissions() async {
        logger.debug("Requesting notification permissions")

        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])

            if granted {
                logger.info("Notification permissions granted")
            } else {
                logger.info("Notification permissions denied")
            }
        } catch {
            logger.error("Failed to request notification permissions: \(error.localizedDescription)")
        }
    }

    private func preloadEssentialData() async {
        logger.debug("Preloading essential data")

        // Preload any critical data for first-time users
        // This could include sample books, tutorials, etc.

        // Simulate some async work
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        logger.debug("Essential data preloaded")
    }

    private func setupDefaultPreferences() {
        logger.debug("Setting up default preferences")

        // Set any default user preferences
        UserDefaults.standard.register(defaults: [
            "libraryViewMode": "grid",
            "enableAutoBackup": true,
            "defaultExportFormat": "json",
            "useNewAmbientMode": true
        ])

        logger.debug("Default preferences configured")
    }
}

// MARK: - Onboarding View Wrapper

struct OnboardingWrapper: ViewModifier {
    @StateObject private var coordinator = OnboardingCoordinator()

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $coordinator.showOnboarding) {
                RefinedOnboardingView {
                    coordinator.completeOnboarding()
                }
            }
    }
}

extension View {
    func withOnboarding() -> some View {
        modifier(OnboardingWrapper())
    }
}