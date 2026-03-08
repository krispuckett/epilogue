import SwiftUI
import Observation

/// Card type for the two-tier welcome system
enum WelcomeCardType: Equatable {
    case none           // Don't show any card
    case inline         // Quick return (1-24 hours) - compact card in library
    case modal          // Long absence (24+ hours) - dramatic Dynamic Island animation
}

/// Manages the "Welcome Back" return card display logic
/// Two-tier system: inline card for quick returns, modal for long absence
@Observable
@MainActor
final class ReturnCardManager {
    static let shared = ReturnCardManager()

    // MARK: - Configuration

    private let inlineCooldown: TimeInterval = 3600       // 1 hour
    private let modalThreshold: TimeInterval = 86400      // 24 hours

    // MARK: - State

    /// The type of card to show this session
    private(set) var cardType: WelcomeCardType = .none

    /// Legacy property for backward compatibility with existing modal code
    var shouldShowReturnCard: Bool {
        cardType == .modal
    }

    /// Whether the inline card should be shown
    var shouldShowInlineCard: Bool {
        cardType == .inline
    }

    /// Whether either card has been shown this session
    private var hasShownModalThisSession: Bool = false
    private var hasShownInlineThisSession: Bool = false

    /// Whether onboarding is complete (cards only show after onboarding)
    private var onboardingComplete: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    // MARK: - Initialization

    private init() {
        checkColdStart()
    }

    // MARK: - Cold Start Detection

    /// Called on app init to determine card type
    private func checkColdStart() {
        // Only show if onboarding is complete
        guard onboardingComplete else {
            cardType = .none
            return
        }

        let lastActiveKey = "returnCard.lastActiveTimestamp"
        let lastActive = UserDefaults.standard.double(forKey: lastActiveKey)
        let now = Date().timeIntervalSince1970

        if lastActive > 0 {
            let timeSinceActive = now - lastActive

            if timeSinceActive >= modalThreshold && !hasShownModalThisSession {
                // Long absence (24+ hours) → dramatic modal
                cardType = .modal
            } else if timeSinceActive >= inlineCooldown && !hasShownInlineThisSession {
                // Quick return (1-24 hours) → inline card
                cardType = .inline
            } else {
                cardType = .none
            }

            #if DEBUG
            let hours = Int(timeSinceActive / 3600)
            let minutes = Int((timeSinceActive.truncatingRemainder(dividingBy: 3600)) / 60)
            print("🎴 ReturnCardManager: Cold start - cardType: \(cardType), away: \(hours)h \(minutes)m")
            #endif
        } else {
            // First launch → show modal for warm welcome
            cardType = .modal

            #if DEBUG
            print("🎴 ReturnCardManager: First launch - showing modal")
            #endif
        }
    }

    // MARK: - Public Methods

    /// Call this when the modal card is dismissed
    func markModalShown() {
        hasShownModalThisSession = true
        hasShownInlineThisSession = true // Don't show inline after modal
        cardType = .none
        recordActivity()

        #if DEBUG
        print("🎴 ReturnCardManager: Modal dismissed")
        #endif
    }

    /// Call this when the inline card is dismissed
    func markInlineShown() {
        hasShownInlineThisSession = true
        cardType = .none
        recordActivity()

        #if DEBUG
        print("🎴 ReturnCardManager: Inline card dismissed")
        #endif
    }

    /// Legacy method for backward compatibility
    func markCardShown() {
        if cardType == .modal {
            markModalShown()
        } else {
            markInlineShown()
        }
    }

    /// Call this when app becomes active to record activity timestamp
    func recordActivity() {
        let lastActiveKey = "returnCard.lastActiveTimestamp"
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastActiveKey)
    }

    /// Force show the modal card (for testing/developer options)
    func forceShow() {
        hasShownModalThisSession = false
        hasShownInlineThisSession = false
        cardType = .modal

        #if DEBUG
        print("🎴 ReturnCardManager: Force showing modal")
        #endif
    }

    /// Force show the Dynamic Island toast (for testing)
    func forceShowToast() {
        hasShownModalThisSession = false
        cardType = .modal

        #if DEBUG
        print("🎴 ReturnCardManager: Force showing Dynamic Island toast")
        #endif

        NotificationCenter.default.post(
            name: .forceShowDynamicIslandToast,
            object: nil
        )
    }

    /// Force show the inline card (for testing)
    func forceShowInline() {
        hasShownInlineThisSession = false
        cardType = .inline

        #if DEBUG
        print("🎴 ReturnCardManager: Force showing inline card")
        #endif
    }

    /// Reset for testing
    func reset() {
        hasShownModalThisSession = false
        hasShownInlineThisSession = false
        cardType = .none
        UserDefaults.standard.removeObject(forKey: "returnCard.lastActiveTimestamp")

        #if DEBUG
        print("🎴 ReturnCardManager: Reset complete")
        #endif
    }
}
