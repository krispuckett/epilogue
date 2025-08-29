import SwiftUI
import UIKit
import CoreHaptics
import Combine

// MARK: - Enhanced Haptic Manager
@MainActor
final class EnhancedHapticManager: ObservableObject {
    static let shared = EnhancedHapticManager()
    
    private var engine: CHHapticEngine?
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        setupHapticEngine()
        prepareGenerators()
    }
    
    // MARK: - Setup
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            
            // Handle engine reset
            engine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                do {
                    try self?.engine?.start()
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
            
            // Handle engine stop
            engine?.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason)")
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    private func prepareGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Basic Haptics
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        case .heavy:
            impactHeavy.impactOccurred()
        case .soft:
            if #available(iOS 13.0, *) {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } else {
                impactLight.impactOccurred()
            }
        case .rigid:
            if #available(iOS 13.0, *) {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            } else {
                impactHeavy.impactOccurred()
            }
        @unknown default:
            impactMedium.impactOccurred()
        }
    }
    
    func selection() {
        selectionFeedback.selectionChanged()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationFeedback.notificationOccurred(type)
    }
    
    // MARK: - Custom Haptic Patterns
    
    func bookOpen() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            impact(.medium)
            return
        }
        
        do {
            let pattern = try bookOpenPattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            impact(.medium)
        }
    }
    
    func pageFlip() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            impact(.light)
            return
        }
        
        do {
            let pattern = try pageFlipPattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            impact(.light)
        }
    }
    
    func noteCapture() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            impact(.light)
            return
        }
        
        do {
            let pattern = try noteCapturePattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            impact(.light)
        }
    }
    
    func success() {
        notification(.success)
    }
    
    func warning() {
        notification(.warning)
    }
    
    func error() {
        notification(.error)
    }
    
    func lightTap() {
        impact(.light)
    }
    
    func mediumTap() {
        impact(.medium)
    }
    
    func heavyTap() {
        impact(.heavy)
    }
    
    // MARK: - Haptic Patterns
    
    private func bookOpenPattern() throws -> CHHapticPattern {
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                ],
                relativeTime: 0.05,
                duration: 0.15
            )
        ]
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    private func pageFlipPattern() throws -> CHHapticPattern {
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0
            )
        ]
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    private func noteCapturePattern() throws -> CHHapticPattern {
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0.1
            )
        ]
        
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    // MARK: - Contextual Haptics
    
    func buttonTap() {
        impact(.light)
    }
    
    func toggleSwitch() {
        selection()
    }
    
    func sliderChange() {
        selection()
    }
    
    func pullToRefreshTriggered() {
        impact(.medium)
    }
    
    func pullToRefreshProgress() {
        selection()
    }
    
    func swipeAction() {
        impact(.light)
    }
    
    func deleteConfirmation() {
        impact(.medium)
    }
    
    func itemAdded() {
        success()
    }
    
    func itemRemoved() {
        impact(.light)
    }
    
    func dragStarted() {
        impact(.light)
    }
    
    func dragEnded() {
        impact(.light)
    }
    
    func longPressStarted() {
        impact(.medium)
    }
    
    func contextMenuOpened() {
        impact(.light)
    }
}

// MARK: - Haptic Feedback View Modifier
struct HapticFeedback: ViewModifier {
    let type: HapticType
    
    enum HapticType {
        case impact(UIImpactFeedbackGenerator.FeedbackStyle)
        case selection
        case notification(UINotificationFeedbackGenerator.FeedbackType)
        case custom(() -> Void)
    }
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                performHaptic()
            }
    }
    
    private func performHaptic() {
        switch type {
        case .impact(let style):
            EnhancedHapticManager.shared.impact(style)
        case .selection:
            EnhancedHapticManager.shared.selection()
        case .notification(let type):
            EnhancedHapticManager.shared.notification(type)
        case .custom(let action):
            action()
        }
    }
}

extension View {
    func hapticFeedback(_ type: HapticFeedback.HapticType) -> some View {
        modifier(HapticFeedback(type: type))
    }
    
    func hapticOnTap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        onTapGesture {
            EnhancedHapticManager.shared.impact(style)
        }
    }
    
    func hapticOnAppear(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        onAppear {
            EnhancedHapticManager.shared.impact(style)
        }
    }
}