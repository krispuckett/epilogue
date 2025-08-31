import SwiftUI
import UIKit

// MARK: - Sensory Feedback Manager
struct SensoryFeedback {
    
    // MARK: - Impact Feedback
    enum ImpactStyle {
        case light
        case medium
        case heavy
        case soft
        case rigid
        
        var generator: UIImpactFeedbackGenerator {
            switch self {
            case .light:
                return UIImpactFeedbackGenerator(style: .light)
            case .medium:
                return UIImpactFeedbackGenerator(style: .medium)
            case .heavy:
                return UIImpactFeedbackGenerator(style: .heavy)
            case .soft:
                return UIImpactFeedbackGenerator(style: .soft)
            case .rigid:
                return UIImpactFeedbackGenerator(style: .rigid)
            }
        }
    }
    
    // MARK: - Selection Feedback
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    // MARK: - Impact Feedback
    static func impact(_ style: ImpactStyle = .light) {
        let generator = style.generator
        generator.prepare()
        generator.impactOccurred()
    }
    
    // MARK: - Convenience Methods
    static func light() {
        impact(.light)
    }
    
    static func medium() {
        impact(.medium)
    }
    
    static func heavy() {
        impact(.heavy)
    }
    
    static func soft() {
        impact(.soft)
    }
    
    static func rigid() {
        impact(.rigid)
    }
    
    // MARK: - Notification Feedback
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    // MARK: - Custom Patterns
    static func bookAdded() {
        impact(.medium)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            success()
        }
    }
    
    static func bookDeleted() {
        impact(.rigid)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            warning()
        }
    }
    
    static func noteCreated() {
        impact(.soft)
    }
    
    static func toggleChanged() {
        selection()
    }
    
    static func pageTransition() {
        impact(.light)
    }
    
    static func pullToRefresh() {
        impact(.soft)
    }
    
    static func buttonTap() {
        impact(.light)
    }
    
    static func destructiveAction() {
        impact(.heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            warning()
        }
    }
}

// MARK: - View Modifier for Buttons
struct HapticButtonStyle: ButtonStyle {
    let feedbackStyle: SensoryFeedback.ImpactStyle
    
    init(feedbackStyle: SensoryFeedback.ImpactStyle = .light) {
        self.feedbackStyle = feedbackStyle
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    SensoryFeedback.impact(feedbackStyle)
                }
            }
    }
}

// MARK: - View Extensions
extension View {
    func hapticFeedback(_ style: SensoryFeedback.ImpactStyle = .light) -> some View {
        self.buttonStyle(HapticButtonStyle(feedbackStyle: style))
    }
    
    func onTapWithFeedback(_ style: SensoryFeedback.ImpactStyle = .light, action: @escaping () -> Void) -> some View {
        self.onTapGesture {
            SensoryFeedback.impact(style)
            action()
        }
    }
    
    func onToggleWithFeedback(action: @escaping () -> Void) -> some View {
        self.onChange(of: true) { _, _ in
            SensoryFeedback.toggleChanged()
            action()
        }
    }
}