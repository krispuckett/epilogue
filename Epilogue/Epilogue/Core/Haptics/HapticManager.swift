import UIKit

final class HapticManager {
    static let shared = HapticManager()
    
    // Feedback generators
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        // Prepare all generators for instant response
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Public Methods
    
    /// Light tap for selections and UI interactions
    func lightTap() {
        lightImpact.impactOccurred()
        lightImpact.prepare() // Re-prepare for next use
    }
    
    /// Medium tap for actions like starting ambient mode
    func mediumTap() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }
    
    /// Heavy tap for significant actions
    func heavyTap() {
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }
    
    /// Selection changed feedback (e.g., tab changes)
    func selectionChanged() {
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
    }
    
    /// Success notification
    func success() {
        notificationFeedback.notificationOccurred(.success)
        notificationFeedback.prepare()
    }
    
    /// Warning notification
    func warning() {
        notificationFeedback.notificationOccurred(.warning)
        notificationFeedback.prepare()
    }
    
    /// Error notification
    func error() {
        notificationFeedback.notificationOccurred(.error)
        notificationFeedback.prepare()
    }
    
    /// Prepare all generators (call when app becomes active)
    func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
}