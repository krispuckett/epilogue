import UIKit
import CoreHaptics

@MainActor
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
    
    // MARK: - Sophisticated Haptic Experiences
    
    /// Play haptic when opening a book
    func bookOpen() {
        playCustomPattern(.bookOpen)
    }
    
    /// Play haptic when capturing a quote
    func quoteCapture() {
        playCustomPattern(.quoteCapture)
    }
    
    /// Play haptic when starting voice mode
    func voiceModeStart() {
        playCustomPattern(.voiceModeStart)
    }
    
    /// Play haptic for page turn effect
    func pageTurn() {
        playCustomPattern(.pageTurn)
    }
    
    /// Play haptic when command palette opens
    func commandPaletteOpen() {
        playCustomPattern(.commandPaletteOpen)
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
    
    // Sophisticated patterns for awards-worthy experience
    
    /// Book opening pattern - like turning a page
    static let bookOpen = HapticPattern(events: [
        CHHapticEvent(eventType: .hapticContinuous,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                      ],
                      relativeTime: 0,
                      duration: 0.2),
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                      ],
                      relativeTime: 0.15)
    ])
    
    /// Quote capture - elegant double tap
    static let quoteCapture = HapticPattern(events: [
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                      ],
                      relativeTime: 0),
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                      ],
                      relativeTime: 0.08)
    ])
    
    /// Voice mode activation - smooth crescendo
    static let voiceModeStart = HapticPattern(events: [
        CHHapticEvent(eventType: .hapticContinuous,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.1),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                      ],
                      relativeTime: 0,
                      duration: 0.3),
        CHHapticEvent(eventType: .hapticContinuous,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                      ],
                      relativeTime: 0.2,
                      duration: 0.2),
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                      ],
                      relativeTime: 0.4)
    ])
    
    /// Page turn - subtle swipe feeling
    static let pageTurn = HapticPattern(events: [
        CHHapticEvent(eventType: .hapticContinuous,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                      ],
                      relativeTime: 0,
                      duration: 0.15),
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                      ],
                      relativeTime: 0.12)
    ])
    
    /// Command palette appearance - magical emergence
    static let commandPaletteOpen = HapticPattern(events: [
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                      ],
                      relativeTime: 0),
        CHHapticEvent(eventType: .hapticContinuous,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                      ],
                      relativeTime: 0.05,
                      duration: 0.1),
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                      ],
                      relativeTime: 0.15)
    ])
    
    func createCHHapticPattern() throws -> CHHapticPattern {
        return try CHHapticPattern(events: events, parameters: [])
    }
}