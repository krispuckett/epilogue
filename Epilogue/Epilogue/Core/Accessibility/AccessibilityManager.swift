import SwiftUI
import UIKit
import Combine

// MARK: - Accessibility Manager
final class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    
    @Published var isVoiceOverEnabled: Bool = UIAccessibility.isVoiceOverRunning
    @Published var isReduceMotionEnabled: Bool = UIAccessibility.isReduceMotionEnabled
    @Published var isDynamicTypeEnabled: Bool = false
    @Published var preferredContentSizeCategory: ContentSizeCategory = .large
    
    private init() {
        setupNotifications()
        updateSettings()
    }
    
    private func setupNotifications() {
        // VoiceOver status
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        // Reduce Motion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionStatusChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        
        // Dynamic Type
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryChanged),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }
    
    @objc private func voiceOverStatusChanged() {
        DispatchQueue.main.async {
            self.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        }
    }
    
    @objc private func reduceMotionStatusChanged() {
        DispatchQueue.main.async {
            self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        }
    }
    
    @objc private func contentSizeCategoryChanged() {
        DispatchQueue.main.async {
            self.updateSettings()
        }
    }
    
    private func updateSettings() {
        let currentCategory = UIApplication.shared.preferredContentSizeCategory
        isDynamicTypeEnabled = currentCategory.isAccessibilityCategory
        
        // Map UIContentSizeCategory to SwiftUI ContentSizeCategory
        switch currentCategory {
        case .extraSmall: preferredContentSizeCategory = .extraSmall
        case .small: preferredContentSizeCategory = .small
        case .medium: preferredContentSizeCategory = .medium
        case .large: preferredContentSizeCategory = .large
        case .extraLarge: preferredContentSizeCategory = .extraLarge
        case .extraExtraLarge: preferredContentSizeCategory = .extraExtraLarge
        case .extraExtraExtraLarge: preferredContentSizeCategory = .extraExtraExtraLarge
        case .accessibilityMedium: preferredContentSizeCategory = .accessibilityMedium
        case .accessibilityLarge: preferredContentSizeCategory = .accessibilityLarge
        case .accessibilityExtraLarge: preferredContentSizeCategory = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: preferredContentSizeCategory = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        default: preferredContentSizeCategory = .large
        }
    }
    
    // MARK: - Accessibility Helpers
    
    /// Announce a message to VoiceOver users
    func announce(_ message: String, delay: Double = 0.1) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    /// Post a screen change notification
    func announceScreenChange() {
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
    
    /// Post a layout change notification
    func announceLayoutChange() {
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
}

// MARK: - Accessibility View Modifiers
struct AccessibleAnimation: ViewModifier {
    @StateObject private var accessibility = AccessibilityManager.shared
    let animation: Animation?
    
    func body(content: Content) -> some View {
        if accessibility.isReduceMotionEnabled {
            content
        } else {
            content.animation(animation, value: UUID())
        }
    }
}

struct AccessibleScale: ViewModifier {
    @StateObject private var accessibility = AccessibilityManager.shared
    
    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(...DynamicTypeSize.accessibility5)
    }
}

struct VoiceOverLabel: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    
    init(label: String, hint: String? = nil, traits: AccessibilityTraits = []) {
        self.label = label
        self.hint = hint
        self.traits = traits
    }
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
}

struct AccessibleFocus: ViewModifier {
    @AccessibilityFocusState var isFocused: Bool
    let shouldFocus: Bool
    
    func body(content: Content) -> some View {
        content
            .accessibilityFocused($isFocused)
            .onChange(of: shouldFocus) { _, newValue in
                if newValue {
                    isFocused = true
                }
            }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply animation only if reduce motion is not enabled
    func accessibleAnimation(_ animation: Animation? = .default) -> some View {
        modifier(AccessibleAnimation(animation: animation))
    }
    
    /// Apply dynamic type scaling with accessibility limits
    func accessibleScale() -> some View {
        modifier(AccessibleScale())
    }
    
    /// Add VoiceOver label and hint
    func voiceOverLabel(_ label: String, hint: String? = nil, traits: AccessibilityTraits = []) -> some View {
        modifier(VoiceOverLabel(label: label, hint: hint, traits: traits))
    }
    
    /// Control accessibility focus
    func accessibleFocus(when shouldFocus: Bool) -> some View {
        modifier(AccessibleFocus(shouldFocus: shouldFocus))
    }
    
    /// Group elements for VoiceOver
    func accessibilityGroup(_ label: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
    }
    
    /// Make interactive elements more accessible
    func accessibleButton(_ label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Add accessibility sort priority (lower numbers are read first)
    func accessibilityOrder(_ priority: Double) -> some View {
        self.accessibilitySortPriority(priority)
    }
}

// MARK: - Semantic Content Size Categories
extension ContentSizeCategory {
    var isAccessibilitySize: Bool {
        switch self {
        case .accessibilityMedium,
             .accessibilityLarge,
             .accessibilityExtraLarge,
             .accessibilityExtraExtraLarge,
             .accessibilityExtraExtraExtraLarge:
            return true
        default:
            return false
        }
    }
    
    /// Scale factor for custom sizing
    var scaleFactor: CGFloat {
        switch self {
        case .extraSmall: return 0.8
        case .small: return 0.9
        case .medium: return 0.95
        case .large: return 1.0
        case .extraLarge: return 1.1
        case .extraExtraLarge: return 1.2
        case .extraExtraExtraLarge: return 1.3
        case .accessibilityMedium: return 1.4
        case .accessibilityLarge: return 1.6
        case .accessibilityExtraLarge: return 1.8
        case .accessibilityExtraExtraLarge: return 2.0
        case .accessibilityExtraExtraExtraLarge: return 2.5
        @unknown default: return 1.0
        }
    }
}