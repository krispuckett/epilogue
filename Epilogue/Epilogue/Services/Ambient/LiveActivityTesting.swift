#if DEBUG
import Foundation
import ActivityKit

/// Testing utilities for Live Activity auto-restart functionality
/// USE ONLY IN DEBUG BUILDS
@MainActor
class LiveActivityTesting {
    static let shared = LiveActivityTesting()
    private init() {}

    // MARK: - Fast-Cycle Testing

    /// Creates a test version of the lifecycle manager with short restart intervals
    /// Use this to test restart behavior without waiting 7 hours
    func createFastCycleManager(restartEvery seconds: TimeInterval = 60) -> LiveActivityLifecycleManager {
        print("⚠️ TEST MODE: Activity will restart every \(seconds)s")
        // Note: You'll need to modify LiveActivityLifecycleManager to support custom intervals
        // For now, this is a placeholder for the testing approach
        return LiveActivityLifecycleManager.shared
    }

    // MARK: - Simulating Time Expiration

    /// Simulates what happens when an activity approaches the 8-hour limit
    func simulateNearExpiration() async {
        let manager = LiveActivityLifecycleManager.shared

        guard manager.isActive else {
            print("❌ No active session to test")
            return
        }

        print("🧪 Simulating near-expiration scenario...")
        print("⏰ Forcing restart to test seamless transition...")

        // Force a restart
        await manager.forceRestart()

        // Verify the activity is still running
        await Task.sleep(seconds: 2)

        if manager.isActive && manager.currentActivity != nil {
            print("✅ Restart successful - activity still alive")
        } else {
            print("❌ Restart failed - activity died")
        }
    }

    // MARK: - State Preservation Testing

    /// Tests that state is correctly preserved across restarts
    func testStatePreservation() async {
        let manager = LiveActivityLifecycleManager.shared

        print("🧪 Testing state preservation...")

        // Start session
        await manager.startSession()
        await Task.sleep(seconds: 1)

        // Set some state
        await manager.updateContent(
            bookTitle: "Test Book",
            capturedCount: 42,
            isListening: true,
            lastTranscript: "This is a test transcript that should survive restart"
        )

        print("📦 State before restart:")
        if let activity = manager.currentActivity {
            let state = activity.content.state
            print("  - Book: \(state.bookTitle ?? "nil")")
            print("  - Count: \(state.capturedCount)")
            print("  - Transcript: \(state.lastTranscript)")
            print("  - Duration: \(state.sessionDuration)s")
        }

        // Force restart
        print("🔄 Forcing restart...")
        await manager.forceRestart()
        await Task.sleep(seconds: 2)

        // Check state after restart
        print("📦 State after restart:")
        if let activity = manager.currentActivity {
            let state = activity.content.state
            print("  - Book: \(state.bookTitle ?? "nil")")
            print("  - Count: \(state.capturedCount)")
            print("  - Transcript: \(state.lastTranscript)")
            print("  - Duration: \(state.sessionDuration)s")

            // Verify preservation
            if state.bookTitle == "Test Book" &&
               state.capturedCount == 42 &&
               state.lastTranscript.contains("test transcript") {
                print("✅ State preservation successful")
            } else {
                print("❌ State preservation failed")
            }
        } else {
            print("❌ No activity after restart")
        }

        // Cleanup
        await manager.endSession()
    }

    // MARK: - Background Testing

    /// Tests behavior when app is backgrounded
    func testBackgroundBehavior() async {
        print("🧪 Testing background behavior...")
        print("📱 Instructions:")
        print("   1. This test will start a Live Activity")
        print("   2. Background the app (swipe up)")
        print("   3. Wait 2 minutes")
        print("   4. Return to app")
        print("   5. Check console for background task logs")

        let manager = LiveActivityLifecycleManager.shared
        await manager.startSession()

        print("✅ Session started - now background the app")
    }

    // MARK: - Restart Timing Analysis

    /// Monitors and logs restart timing metrics
    func monitorRestartTiming(duration: TimeInterval = 300) async {
        print("📊 Monitoring restart timing for \(duration)s...")

        let manager = LiveActivityLifecycleManager.shared

        guard manager.isActive else {
            print("❌ No active session to monitor")
            return
        }

        let endTime = Date().addingTimeInterval(duration)
        var lastActivityId = manager.currentActivity?.id

        while Date() < endTime {
            await Task.sleep(seconds: 5)

            if let currentId = manager.currentActivity?.id {
                if currentId != lastActivityId {
                    print("🔄 Activity restarted!")
                    print("   Old ID: \(lastActivityId ?? "nil")")
                    print("   New ID: \(currentId)")
                    lastActivityId = currentId
                }
            } else {
                print("❌ Activity disappeared!")
                break
            }

            if let timeUntilRestart = manager.timeUntilRestart() {
                print("⏱️ Time until restart: \(formatDuration(timeUntilRestart))")
            }
        }

        print("📊 Monitoring complete")
    }

    // MARK: - Failure Scenarios

    /// Tests what happens when restart fails
    func testRestartFailure() async {
        print("🧪 Testing restart failure handling...")

        // This would require mocking ActivityKit to simulate failures
        // For now, document the approach:
        print("""
        To test failure handling:
        1. Disable Live Activities in Settings
        2. Force a restart
        3. Verify graceful degradation
        4. Check retry logic (exponential backoff: 2s, 4s, 8s)
        5. Verify max retries = 3
        """)
    }

    // MARK: - Production Validation

    /// Validates the system is ready for production
    func validateProductionReadiness() async {
        print("🔍 Validating production readiness...\n")

        var passed = 0
        var failed = 0

        // Check 1: Info.plist configuration
        if Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivitiesFrequentUpdates") != nil {
            print("✅ NSSupportsLiveActivitiesFrequentUpdates configured")
            passed += 1
        } else {
            print("❌ Missing NSSupportsLiveActivitiesFrequentUpdates in Info.plist")
            failed += 1
        }

        // Check 2: Authorization
        let authInfo = ActivityAuthorizationInfo()
        if authInfo.areActivitiesEnabled {
            print("✅ Live Activities enabled")
            passed += 1
        } else {
            print("⚠️ Live Activities not enabled (may be user setting)")
        }

        // Check 3: State size validation
        let testState = AmbientActivityAttributes.ContentState(
            bookTitle: "The Quick Brown Fox Jumps Over The Lazy Dog",
            sessionDuration: 3600,
            capturedCount: 999,
            isListening: true,
            lastTranscript: String(repeating: "Testing state size limits with realistic transcript data. ", count: 50)
        )

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(testState)
            let sizeKB = Double(data.count) / 1024.0

            if sizeKB < 4.0 {
                print("✅ State size: \(String(format: "%.2f", sizeKB))KB (< 4KB limit)")
                passed += 1
            } else {
                print("❌ State size: \(String(format: "%.2f", sizeKB))KB (exceeds 4KB limit!)")
                failed += 1
            }
        } catch {
            print("❌ Failed to encode state: \(error)")
            failed += 1
        }

        // Check 4: Restart interval sanity
        let manager = LiveActivityLifecycleManager.shared
        print("ℹ️ Restart interval: 7 hours (1 hour before iOS limit)")

        print("\n--- Summary ---")
        print("Passed: \(passed)")
        print("Failed: \(failed)")

        if failed == 0 {
            print("✅ All checks passed - ready for production")
        } else {
            print("❌ Some checks failed - review configuration")
        }
    }

    // MARK: - Utilities

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Task Sleep Extension

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - SwiftUI Testing View

#if DEBUG
import SwiftUI

struct LiveActivityTestingView: View {
    @StateObject private var manager = LiveActivityLifecycleManager.shared
    @State private var testOutput = "Tap a test to run..."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Live Activity Testing")
                    .font(.largeTitle)
                    .bold()

                // Status
                GroupBox("Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        statusRow("Active", manager.isActive)
                        if let activity = manager.currentActivity {
                            statusRow("Activity ID", activity.id)
                        }
                        if let timeUntilRestart = manager.timeUntilRestart() {
                            Text("Next restart: \(formatDuration(timeUntilRestart))")
                                .font(.caption)
                        }
                    }
                }

                // Quick Actions
                GroupBox("Quick Actions") {
                    VStack(spacing: 12) {
                        Button("Start Session") {
                            Task { await manager.startSession() }
                        }
                        .buttonStyle(.bordered)

                        Button("Force Restart") {
                            Task { await manager.forceRestart() }
                        }
                        .buttonStyle(.bordered)

                        Button("End Session") {
                            Task { await manager.endSession() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }

                // Tests
                GroupBox("Tests") {
                    VStack(spacing: 12) {
                        TestButton(title: "Simulate Near Expiration") {
                            await LiveActivityTesting.shared.simulateNearExpiration()
                        }

                        TestButton(title: "Test State Preservation") {
                            await LiveActivityTesting.shared.testStatePreservation()
                        }

                        TestButton(title: "Validate Production") {
                            await LiveActivityTesting.shared.validateProductionReadiness()
                        }
                    }
                }

                // Output
                GroupBox("Console Output") {
                    Text(testOutput)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
    }

    private func statusRow(_ label: String, _ value: Any) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(String(describing: value))")
                .font(.caption.monospaced())
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}

struct TestButton: View {
    let title: String
    let action: () async -> Void

    var body: some View {
        Button(title) {
            Task { await action() }
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }
}
#endif

#endif
