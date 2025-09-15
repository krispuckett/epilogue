import Foundation
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "FeatureFlags")

// MARK: - Feature Flag Protocol

protocol FeatureFlagService {
    func bool(for key: String) -> Bool
    func string(for key: String) -> String?
    func number(for key: String) -> Double?
    func json(for key: String) -> [String: Any]?
    func refresh() async
    func addListener(_ listener: FeatureFlagListener)
    func removeListener(_ listener: FeatureFlagListener)
}

// MARK: - Feature Flag Listener

protocol FeatureFlagListener: AnyObject {
    func featureFlagsDidUpdate(_ flags: [String: Any])
}

// MARK: - Feature Flags

enum FeatureFlag: String, CaseIterable {
    // Ambient Mode Features
    case newAmbientMode = "feature.ambient.new_mode"
    case ambientVoiceCommands = "feature.ambient.voice_commands"
    case ambientAutoTranscription = "feature.ambient.auto_transcription"

    // AI Features
    case aiQuoteAnalysis = "feature.ai.quote_analysis"
    case aiBookRecommendations = "feature.ai.book_recommendations"
    case aiSessionSummaries = "feature.ai.session_summaries"
    case aiEnhancedChat = "feature.ai.enhanced_chat"

    // Library Features
    case advancedBookSearch = "feature.library.advanced_search"
    case batchBookImport = "feature.library.batch_import"
    case bookCollections = "feature.library.collections"

    // Performance Features
    case aggressiveCaching = "feature.performance.aggressive_caching"
    case imagePreloading = "feature.performance.image_preloading"
    case backgroundSync = "feature.performance.background_sync"

    // Experimental Features
    case experimentalGestures = "feature.experimental.gestures"
    case experimentalAnimations = "feature.experimental.animations"
    case debugMode = "feature.experimental.debug_mode"

    var defaultValue: Bool {
        switch self {
        case .newAmbientMode: return true
        case .ambientVoiceCommands: return false
        case .ambientAutoTranscription: return false
        case .aiQuoteAnalysis: return true
        case .aiBookRecommendations: return true
        case .aiSessionSummaries: return false
        case .aiEnhancedChat: return false
        case .advancedBookSearch: return true
        case .batchBookImport: return true
        case .bookCollections: return false
        case .aggressiveCaching: return true
        case .imagePreloading: return true
        case .backgroundSync: return false
        case .experimentalGestures: return false
        case .experimentalAnimations: return false
        case .debugMode: return false
        }
    }

    var description: String {
        switch self {
        case .newAmbientMode: return "New Ambient Mode UI"
        case .ambientVoiceCommands: return "Voice Commands in Ambient Mode"
        case .ambientAutoTranscription: return "Automatic Voice Transcription"
        case .aiQuoteAnalysis: return "AI Quote Analysis"
        case .aiBookRecommendations: return "AI Book Recommendations"
        case .aiSessionSummaries: return "AI Session Summaries"
        case .aiEnhancedChat: return "Enhanced AI Chat"
        case .advancedBookSearch: return "Advanced Book Search"
        case .batchBookImport: return "Batch Book Import"
        case .bookCollections: return "Book Collections"
        case .aggressiveCaching: return "Aggressive Caching"
        case .imagePreloading: return "Image Preloading"
        case .backgroundSync: return "Background Sync"
        case .experimentalGestures: return "Experimental Gestures"
        case .experimentalAnimations: return "Experimental Animations"
        case .debugMode: return "Debug Mode"
        }
    }
}

// MARK: - Feature Flag Property Wrapper

@propertyWrapper
struct Feature {
    private let flag: FeatureFlag

    init(_ flag: FeatureFlag) {
        self.flag = flag
    }

    var wrappedValue: Bool {
        return FeatureFlags.shared.isEnabled(flag)
    }
}

// MARK: - Remote Config Implementation

final class RemoteConfig: FeatureFlagService {
    static let shared = RemoteConfig()

    private var flags: [String: Any] = [:]
    private var listeners: [WeakBox<AnyObject>] = []
    private let queue = DispatchQueue(label: "com.epilogue.featureflags")
    private var refreshTimer: Timer?

    private init() {
        loadLocalFlags()
        startAutoRefresh()
    }

    func bool(for key: String) -> Bool {
        queue.sync {
            return flags[key] as? Bool ?? false
        }
    }

    func string(for key: String) -> String? {
        queue.sync {
            return flags[key] as? String
        }
    }

    func number(for key: String) -> Double? {
        queue.sync {
            return flags[key] as? Double
        }
    }

    func json(for key: String) -> [String: Any]? {
        queue.sync {
            return flags[key] as? [String: Any]
        }
    }

    func refresh() async {
        logger.info("Refreshing feature flags")

        do {
            let remoteFlags = try await fetchRemoteFlags()
            updateFlags(remoteFlags)
            saveLocalFlags(remoteFlags)
            notifyListeners()

            logger.info("Feature flags refreshed successfully")
        } catch {
            logger.error("Failed to refresh feature flags: \(error.localizedDescription)")
        }
    }

    func addListener(_ listener: FeatureFlagListener) {
        queue.async {
            self.listeners.append(WeakBox(listener as AnyObject))
            self.cleanupListeners()
        }
    }

    func removeListener(_ listener: FeatureFlagListener) {
        queue.async {
            self.listeners.removeAll { $0.value === listener }
        }
    }

    // MARK: - Private Methods

    private func loadLocalFlags() {
        // Load from UserDefaults for offline support
        if let savedFlags = UserDefaults.standard.dictionary(forKey: "com.epilogue.featureflags") {
            queue.async {
                self.flags = savedFlags
            }
            logger.info("Loaded \(savedFlags.count) feature flags from local storage")
        } else {
            // Use default values
            loadDefaultFlags()
        }
    }

    private func loadDefaultFlags() {
        var defaults: [String: Any] = [:]
        for flag in FeatureFlag.allCases {
            defaults[flag.rawValue] = flag.defaultValue
        }
        queue.async {
            self.flags = defaults
        }
        logger.info("Loaded default feature flags")
    }

    private func saveLocalFlags(_ flags: [String: Any]) {
        UserDefaults.standard.set(flags, forKey: "com.epilogue.featureflags")
        logger.debug("Saved feature flags to local storage")
    }

    private func fetchRemoteFlags() async throws -> [String: Any] {
        // In production, this would fetch from your remote config service
        // For now, return current flags with some mock changes

        #if DEBUG
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)

        // Return current flags (no changes in debug)
        return queue.sync { self.flags }
        #else
        // Production implementation would go here
        // Example:
        // let url = URL(string: "https://api.epilogue.com/config/flags")!
        // let (data, _) = try await URLSession.shared.data(from: url)
        // return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        return queue.sync { self.flags }
        #endif
    }

    private func updateFlags(_ newFlags: [String: Any]) {
        queue.async {
            self.flags = newFlags
        }
    }

    private func notifyListeners() {
        let currentFlags = queue.sync { self.flags }

        queue.async {
            self.cleanupListeners()
            for weakListener in self.listeners {
                if let listener = weakListener.value as? FeatureFlagListener {
                    listener.featureFlagsDidUpdate(currentFlags)
                }
            }
        }
    }

    private func cleanupListeners() {
        listeners.removeAll { $0.value == nil }
    }

    private func startAutoRefresh() {
        #if !DEBUG
        // Refresh every 30 minutes in production
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in
            Task {
                await self.refresh()
            }
        }
        #endif
    }

    deinit {
        refreshTimer?.invalidate()
    }
}

// MARK: - Feature Flags Manager

@MainActor
final class FeatureFlags {
    static let shared = FeatureFlags()
    private let service: FeatureFlagService = RemoteConfig.shared

    private init() {
        logger.info("FeatureFlags initialized")
    }

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        let isEnabled = service.bool(for: flag.rawValue)

        if isEnabled && !flag.defaultValue {
            // Flag is enabled but not by default - track it
            Analytics.shared.track(
                AnalyticsEvent(
                    name: "feature_flag_enabled",
                    category: .settings,
                    properties: [
                        "flag": flag.rawValue,
                        "description": flag.description
                    ]
                )
            )
        }

        return isEnabled
    }

    func string(for key: String) -> String? {
        return service.string(for: key)
    }

    func number(for key: String) -> Double? {
        return service.number(for: key)
    }

    func refresh() async {
        logger.info("Manually refreshing feature flags")
        await service.refresh()
    }

    // MARK: - Convenience Methods

    var isNewAmbientModeEnabled: Bool {
        isEnabled(.newAmbientMode)
    }

    var isAIQuoteAnalysisEnabled: Bool {
        isEnabled(.aiQuoteAnalysis)
    }

    var isAdvancedSearchEnabled: Bool {
        isEnabled(.advancedBookSearch)
    }

    var isDebugModeEnabled: Bool {
        #if DEBUG
        return true
        #else
        return isEnabled(.debugMode)
        #endif
    }
}

// MARK: - Weak Box for Listeners

private class WeakBox<T: AnyObject> {
    weak var value: T?

    init(_ value: T) {
        self.value = value
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

struct FeatureFlagView<Content: View, Alternative: View>: View {
    let flag: FeatureFlag
    let content: () -> Content
    let alternative: () -> Alternative

    @State private var isEnabled = false

    init(
        _ flag: FeatureFlag,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder alternative: @escaping () -> Alternative = { EmptyView() }
    ) {
        self.flag = flag
        self.content = content
        self.alternative = alternative
    }

    var body: some View {
        Group {
            if isEnabled {
                content()
            } else {
                alternative()
            }
        }
        .onAppear {
            isEnabled = FeatureFlags.shared.isEnabled(flag)
        }
    }
}

extension View {
    func featureFlag(_ flag: FeatureFlag) -> some View {
        FeatureFlagView(flag) {
            self
        }
    }

    func featureFlag<Alternative: View>(
        _ flag: FeatureFlag,
        alternative: @escaping () -> Alternative
    ) -> some View {
        FeatureFlagView(flag, content: { self }, alternative: alternative)
    }
}