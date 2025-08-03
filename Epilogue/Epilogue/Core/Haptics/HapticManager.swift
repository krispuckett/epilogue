import UIKit
import CoreHaptics

final class HapticManager {
    static let shared = HapticManager()
    
    // Feedback generators
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // Core Haptics engine for advanced feedback
    private var hapticEngine: CHHapticEngine?
    private let supportsHaptics: Bool
    
    private init() {
        // Check for haptic support
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        
        // Initialize Core Haptics engine if supported
        if supportsHaptics {
            do {
                hapticEngine = try CHHapticEngine()
                try hapticEngine?.start()
            } catch {
                print("Failed to initialize haptic engine: \(error)")
            }
        }
        
        // Prepare all generators for instant response
        prepareGenerators()
    }
    
    private func prepareGenerators() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Public Methods
    
    /// Light tap for selections and UI interactions
    func lightTap() {
        guard supportsHaptics else { return }
        lightImpact.impactOccurred()
        lightImpact.prepare() // Re-prepare for next use
    }
    
    /// Medium tap for actions like starting ambient mode
    func mediumTap() {
        guard supportsHaptics else { return }
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }
    
    /// Heavy tap for significant actions
    func heavyTap() {
        guard supportsHaptics else { return }
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }
    
    /// Soft tap for gentle feedback (iOS 26+)
    func softTap() {
        guard supportsHaptics else { return }
        softImpact.impactOccurred()
        softImpact.prepare()
    }
    
    /// Rigid tap for firm feedback (iOS 26+)
    func rigidTap() {
        guard supportsHaptics else { return }
        rigidImpact.impactOccurred()
        rigidImpact.prepare()
    }
    
    /// Selection changed feedback (e.g., tab changes)
    func selectionChanged() {
        guard supportsHaptics else { return }
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
    }
    
    /// Success notification
    func success() {
        guard supportsHaptics else { return }
        notificationFeedback.notificationOccurred(.success)
        notificationFeedback.prepare()
    }
    
    /// Warning notification
    func warning() {
        guard supportsHaptics else { return }
        notificationFeedback.notificationOccurred(.warning)
        notificationFeedback.prepare()
    }
    
    /// Error notification
    func error() {
        guard supportsHaptics else { return }
        notificationFeedback.notificationOccurred(.error)
        notificationFeedback.prepare()
    }
    
    /// Adaptive button press feedback based on context
    func buttonPress(intensity: Float = 0.5) {
        guard supportsHaptics else { return }
        
        if intensity < 0.3 {
            softTap()
        } else if intensity < 0.7 {
            lightTap()
        } else {
            mediumTap()
        }
    }
    
    /// Custom haptic pattern for complex interactions
    func playCustomPattern(_ pattern: HapticPattern) {
        guard supportsHaptics, let engine = hapticEngine else { return }
        
        do {
            let pattern = try pattern.createCHHapticPattern()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play custom haptic pattern: \(error)")
        }
    }
    
    /// Prepare all generators (call when app becomes active)
    func prepareAll() {
        prepareGenerators()
        
        // Restart haptic engine if needed
        if supportsHaptics {
            do {
                try hapticEngine?.start()
            } catch {
                print("Failed to restart haptic engine: \(error)")
            }
        }
    }
}

// MARK: - Haptic Pattern
struct HapticPattern {
    let events: [CHHapticEvent]
    
    static let buttonTap = HapticPattern(events: [
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                      ],
                      relativeTime: 0)
    ])
    
    static let success = HapticPattern(events: [
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                      ],
                      relativeTime: 0),
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                      ],
                      relativeTime: 0.1)
    ])
    
    func createCHHapticPattern() throws -> CHHapticPattern {
        return try CHHapticPattern(events: events, parameters: [])
    }
}