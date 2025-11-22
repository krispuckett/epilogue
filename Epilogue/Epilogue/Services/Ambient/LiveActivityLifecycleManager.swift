import ActivityKit
import Foundation
import Combine
import UIKit

/// Manages the lifecycle of Live Activities with automatic restart to work around iOS time limits
///
/// iOS Live Activities have an 8-hour limit in Dynamic Island, after which they're automatically terminated.
/// This manager implements a pre-emptive restart pattern inspired by Raycast's approach:
/// - Monitors activity age
/// - Restarts before hitting the limit
/// - Preserves state across restarts
/// - Handles errors gracefully
///
@MainActor
class LiveActivityLifecycleManager: ObservableObject {
    static let shared = LiveActivityLifecycleManager()

    // MARK: - Configuration

    /// How long before the 8-hour limit to restart (in seconds)
    /// Default: 7 hours (1 hour buffer before iOS kills it)
    private let restartInterval: TimeInterval = 7 * 60 * 60 // 7 hours

    /// How often to check if restart is needed (in seconds)
    private let checkInterval: TimeInterval = 60 // 1 minute

    /// Maximum retries if restart fails
    private let maxRestartRetries = 3

    // MARK: - State

    @Published private(set) var isActive = false
    @Published private(set) var currentActivity: Activity<AmbientActivityAttributes>?
    @Published private(set) var sessionStartTime: Date?
    @Published private(set) var totalSessionDuration: TimeInterval = 0

    private var activityStartTime: Date?
    private var lifecycleTimer: Timer?
    private var updateTimer: Timer?
    private var restartRetries = 0
    private var preservedState: PreservedSessionState?

    // Background task
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    // Observers
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Preserved State

    /// State that must survive activity restarts
    private struct PreservedSessionState: Codable {
        let sessionStartTime: Date
        let bookTitle: String?
        let capturedCount: Int
        let lastTranscript: String
        let totalDuration: TimeInterval

        var currentState: AmbientActivityAttributes.ContentState {
            AmbientActivityAttributes.ContentState(
                bookTitle: bookTitle,
                sessionDuration: totalDuration,
                capturedCount: capturedCount,
                isListening: true,
                lastTranscript: lastTranscript
            )
        }
    }

    // MARK: - Initialization

    private init() {
        setupObservers()
    }

    // MARK: - Public API

    /// Starts a new Live Activity session with automatic restart support
    func startSession() async {
        guard !isActive else {
            #if DEBUG
            print("⚠️ LiveActivity session already active")
            #endif
            return
        }

        // Check for existing activities from previous sessions
        await recoverExistingActivity()

        if currentActivity == nil {
            await createNewActivity()
        }

        isActive = true
        sessionStartTime = Date()
        totalSessionDuration = 0

        startLifecycleMonitoring()
        startUpdateTimer()

        #if DEBUG
        print("✅ LiveActivity session started (restart interval: \(restartInterval/3600)h)")
        #endif
    }

    /// Updates the Live Activity with new content
    func updateContent(
        bookTitle: String? = nil,
        capturedCount: Int? = nil,
        isListening: Bool? = nil,
        lastTranscript: String? = nil
    ) async {
        guard let activity = currentActivity else { return }

        let state = activity.content.state
        let currentDuration = totalSessionDuration + (activityStartTime.map { Date().timeIntervalSince($0) } ?? 0)

        let updatedState = AmbientActivityAttributes.ContentState(
            bookTitle: bookTitle ?? state.bookTitle,
            sessionDuration: currentDuration,
            capturedCount: capturedCount ?? state.capturedCount,
            isListening: isListening ?? state.isListening,
            lastTranscript: lastTranscript ?? state.lastTranscript
        )

        // Preserve state for potential restart
        preserveState(updatedState)

        await activity.update(.init(state: updatedState, staleDate: nil))
    }

    /// Ends the Live Activity session
    func endSession() async {
        guard isActive else { return }

        isActive = false
        stopLifecycleMonitoring()
        stopUpdateTimer()

        if let activity = currentActivity {
            let finalDuration = totalSessionDuration + (activityStartTime.map { Date().timeIntervalSince($0) } ?? 0)
            let finalState = AmbientActivityAttributes.ContentState(
                bookTitle: activity.content.state.bookTitle,
                sessionDuration: finalDuration,
                capturedCount: activity.content.state.capturedCount,
                isListening: false,
                lastTranscript: "Session ended"
            )

            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(5))
            )
        }

        // Cleanup
        currentActivity = nil
        activityStartTime = nil
        sessionStartTime = nil
        totalSessionDuration = 0
        preservedState = nil
        restartRetries = 0

        #if DEBUG
        print("✅ LiveActivity session ended")
        #endif
    }

    // MARK: - Activity Lifecycle

    private func createNewActivity() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            #if DEBUG
            print("❌ Live Activities not enabled")
            #endif
            return
        }

        let now = Date()
        let attributes = AmbientActivityAttributes(startTime: sessionStartTime ?? now)

        // Use preserved state if available, otherwise create initial state
        let initialState: AmbientActivityAttributes.ContentState
        if let preserved = preservedState {
            initialState = preserved.currentState
        } else {
            initialState = AmbientActivityAttributes.ContentState(
                bookTitle: nil,
                sessionDuration: 0,
                capturedCount: 0,
                isListening: true,
                lastTranscript: ""
            )
        }

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            activityStartTime = now
            restartRetries = 0

            #if DEBUG
            print("✅ Live Activity created: \(currentActivity?.id ?? "unknown")")
            if preservedState != nil {
                print("📦 Restored from preserved state")
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to create Live Activity: \(error)")
            #endif

            // Retry with exponential backoff
            await handleRestartFailure()
        }
    }

    private func recoverExistingActivity() async {
        // Check if there's an existing activity from a previous session
        let existingActivities = Activity<AmbientActivityAttributes>.activities

        if let existing = existingActivities.first {
            #if DEBUG
            print("♻️ Recovered existing Live Activity: \(existing.id)")
            #endif

            currentActivity = existing
            activityStartTime = existing.attributes.startTime

            // Calculate how old this activity is
            let age = Date().timeIntervalSince(existing.attributes.startTime)

            // If it's close to the limit, restart immediately
            if age >= restartInterval {
                #if DEBUG
                print("⏰ Existing activity is old (\(age/3600)h), restarting...")
                #endif
                await restartActivity()
            }
        }
    }

    /// Restarts the Live Activity to reset the 8-hour timer
    private func restartActivity() async {
        guard let oldActivity = currentActivity else { return }

        #if DEBUG
        print("🔄 Restarting Live Activity...")
        #endif

        // 1. Capture current state
        let state = oldActivity.content.state
        totalSessionDuration += Date().timeIntervalSince(activityStartTime ?? Date())
        preserveState(state)

        // 2. End old activity immediately (no dismissal delay for restart)
        await oldActivity.end(
            .init(state: state, staleDate: nil),
            dismissalPolicy: .immediate
        )

        // 3. Small delay to ensure clean transition
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // 4. Create new activity with preserved state
        currentActivity = nil
        activityStartTime = nil

        await createNewActivity()

        #if DEBUG
        if currentActivity != nil {
            print("✅ Live Activity restarted successfully")
        } else {
            print("❌ Live Activity restart failed")
        }
        #endif
    }

    private func handleRestartFailure() async {
        restartRetries += 1

        guard restartRetries < maxRestartRetries else {
            #if DEBUG
            print("❌ Max restart retries reached, giving up")
            #endif
            isActive = false
            return
        }

        // Exponential backoff: 2s, 4s, 8s
        let delay = pow(2.0, Double(restartRetries))
        #if DEBUG
        print("⏳ Retrying in \(delay)s (attempt \(restartRetries)/\(maxRestartRetries))")
        #endif

        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        await createNewActivity()
    }

    // MARK: - State Preservation

    private func preserveState(_ state: AmbientActivityAttributes.ContentState) {
        preservedState = PreservedSessionState(
            sessionStartTime: sessionStartTime ?? Date(),
            bookTitle: state.bookTitle,
            capturedCount: state.capturedCount,
            lastTranscript: state.lastTranscript,
            totalDuration: state.sessionDuration
        )
    }

    // MARK: - Lifecycle Monitoring

    private func startLifecycleMonitoring() {
        stopLifecycleMonitoring()

        lifecycleTimer = Timer.scheduledTimer(
            withTimeInterval: checkInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForRestart()
            }
        }

        #if DEBUG
        print("👁️ Lifecycle monitoring started (check every \(checkInterval)s)")
        #endif
    }

    private func stopLifecycleMonitoring() {
        lifecycleTimer?.invalidate()
        lifecycleTimer = nil
    }

    private func checkForRestart() async {
        guard isActive,
              let startTime = activityStartTime else { return }

        let age = Date().timeIntervalSince(startTime)

        #if DEBUG
        if Int(age) % 300 == 0 { // Log every 5 minutes
            print("⏱️ Activity age: \(age/3600)h / \(restartInterval/3600)h")
        }
        #endif

        // Restart if we've hit the interval
        if age >= restartInterval {
            #if DEBUG
            print("⏰ Restart interval reached (\(age/3600)h), restarting...")
            #endif
            await restartActivity()
        }
    }

    // MARK: - Update Timer

    private func startUpdateTimer() {
        stopUpdateTimer()

        // Update every 10 seconds for duration display
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: 10,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.updateDuration()
            }
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateDuration() async {
        guard let activity = currentActivity,
              let startTime = activityStartTime else { return }

        let currentDuration = totalSessionDuration + Date().timeIntervalSince(startTime)

        let state = activity.content.state
        let updatedState = AmbientActivityAttributes.ContentState(
            bookTitle: state.bookTitle,
            sessionDuration: currentDuration,
            capturedCount: state.capturedCount,
            isListening: state.isListening,
            lastTranscript: state.lastTranscript
        )

        await activity.update(.init(state: updatedState, staleDate: nil))
    }

    // MARK: - App Lifecycle Observers

    private func setupObservers() {
        // Monitor app state changes
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleDidEnterBackground()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleWillEnterForeground()
                }
            }
            .store(in: &cancellables)
    }

    private func handleDidEnterBackground() async {
        #if DEBUG
        print("📱 App entering background")
        #endif

        // Start background task to keep monitoring alive
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            Task { @MainActor in
                await self?.endBackgroundTask()
            }
        }
    }

    private func handleWillEnterForeground() async {
        #if DEBUG
        print("📱 App entering foreground")
        #endif

        // End background task
        await endBackgroundTask()

        // Check if we need to restart after being backgrounded
        if isActive {
            await checkForRestart()
        }
    }

    private func endBackgroundTask() async {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}

// MARK: - Testing Support

#if DEBUG
extension LiveActivityLifecycleManager {
    /// For testing: forces an immediate restart
    func forceRestart() async {
        await restartActivity()
    }

    /// For testing: returns how long until next restart
    func timeUntilRestart() -> TimeInterval? {
        guard let startTime = activityStartTime else { return nil }
        let age = Date().timeIntervalSince(startTime)
        return max(0, restartInterval - age)
    }

    /// For testing: sets a custom restart interval (in seconds)
    func setRestartInterval(_ interval: TimeInterval) {
        // Note: This would need to be made variable in production
        #if DEBUG
        print("⚠️ Custom restart intervals not supported - modify restartInterval constant")
        #endif
    }
}
#endif
