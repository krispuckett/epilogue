import ActivityKit
import SwiftUI
import AppIntents

// AmbientActivityAttributes is defined in Models/AmbientActivityAttributes.swift
// Widget views are in EpilogueWidgets/ReadingSessionLiveActivity.swift

// MARK: - App Intents for Live Activity Controls
// These use LiveActivityIntent (not AppIntent) so they execute in the main app
// process where TrueAmbientProcessor.shared is valid, without bringing the app
// to the foreground. Plain AppIntent runs in the widget extension process where
// app singletons are unavailable, causing silent failures.

struct ToggleAmbientListeningIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Toggle Ambient Listening"

    func perform() async throws -> some IntentResult {
        await TrueAmbientProcessor.shared.toggleListening()

        let isListening = await TrueAmbientProcessor.shared.sessionActive
        await AmbientLiveActivityManager.shared.updateActivity(isListening: isListening)

        return .result()
    }
}

struct EndAmbientSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Ambient Session"

    func perform() async throws -> some IntentResult {
        _ = await TrueAmbientProcessor.shared.endSession()
        await AmbientLiveActivityManager.shared.endActivity()

        return .result()
    }
}

// MARK: - Live Activity Manager (Legacy Facade)
// Delegates to LiveActivityLifecycleManager for backward compatibility.

@MainActor
class AmbientLiveActivityManager {
    static let shared = AmbientLiveActivityManager()

    private init() {}

    func startActivity() async {
        await LiveActivityLifecycleManager.shared.startSession()
    }

    func updateActivity(
        bookTitle: String? = nil,
        capturedCount: Int? = nil,
        isListening: Bool? = nil,
        lastTranscript: String? = nil
    ) async {
        await LiveActivityLifecycleManager.shared.updateContent(
            bookTitle: bookTitle,
            capturedCount: capturedCount,
            isListening: isListening,
            lastTranscript: lastTranscript
        )
    }

    func endActivity() async {
        await LiveActivityLifecycleManager.shared.endSession()
    }
}
