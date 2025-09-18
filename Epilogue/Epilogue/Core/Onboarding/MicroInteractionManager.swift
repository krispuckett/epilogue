import SwiftUI
import Combine

/// Manages one-time micro-interactions for post-onboarding guidance
@MainActor
final class MicroInteractionManager: ObservableObject {
    // MARK: - Singleton
    static let shared = MicroInteractionManager()

    // MARK: - Published States
    @Published var showAddBookBorderAnimation = false
    @Published var showFirstBookShake = false
    @Published var showAmbientIconAnimation = false
    @Published var showDoubleTapHint = false

    // MARK: - AppStorage for persistence
    @AppStorage("hasShownAddBookAnimation") private var hasShownAddBookAnimation = false
    @AppStorage("hasShownFirstBookShake") private var hasShownFirstBookShake = false
    @AppStorage("hasShownAmbientAnimation") private var hasShownAmbientAnimation = false
    @AppStorage("hasShownDoubleTapHint") private var hasShownDoubleTapHint = false
    @AppStorage("firstBookAddedID") private var firstBookAddedID: String = ""

    private init() {}

    // MARK: - Public Methods

    /// Called when onboarding completes to trigger add book animation
    func onboardingCompleted() {
        if !hasShownAddBookAnimation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showAddBookBorderAnimation = true
                self.hasShownAddBookAnimation = true
            }
        }
    }

    /// Called when a book is added to trigger shake animation (only once)
    func bookAdded(bookID: String) {
        if !hasShownFirstBookShake && firstBookAddedID.isEmpty {
            firstBookAddedID = bookID
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showFirstBookShake = true
                self.hasShownFirstBookShake = true

                // Auto-hide shake after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.showFirstBookShake = false
                }
            }
        }
    }

    /// Check if a specific book should show shake animation
    func shouldShowShake(for bookID: String) -> Bool {
        return bookID == firstBookAddedID && showFirstBookShake
    }

    /// Called when entering BookView to trigger ambient icon animation
    func enteredBookView() {
        if !hasShownAmbientAnimation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showAmbientIconAnimation = true
                self.hasShownAmbientAnimation = true

                // Auto-hide after animation completes (longer duration)
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        self.showAmbientIconAnimation = false
                    }
                }
            }
        }
    }

    /// Called when entering Ambient Mode to show double-tap hint
    func enteredAmbientMode() {
        if !hasShownDoubleTapHint {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.showDoubleTapHint = true
                self.hasShownDoubleTapHint = true

                // Auto-hide hint after 8 seconds (longer display time)
                DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.showDoubleTapHint = false
                    }
                }
            }
        }
    }

    /// Reset all micro-interactions (for testing)
    func resetAllInteractions() {
        hasShownAddBookAnimation = false
        hasShownFirstBookShake = false
        hasShownAmbientAnimation = false
        hasShownDoubleTapHint = false
        firstBookAddedID = ""

        showAddBookBorderAnimation = false
        showFirstBookShake = false
        showAmbientIconAnimation = false
        showDoubleTapHint = false
    }
}

// MARK: - Border Animation View
struct AnimatedBorderButton: ViewModifier {
    @StateObject private var manager = MicroInteractionManager.shared
    @State private var pulseOpacity: Double = 0
    @State private var blur: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        ThemeManager.shared.currentTheme.primaryAccent.opacity(pulseOpacity),
                        lineWidth: 2
                    )
                    .blur(radius: blur)
                    .opacity(manager.showAddBookBorderAnimation ? 1 : 0)
            )
            .onChange(of: manager.showAddBookBorderAnimation) { _, show in
                if show {
                    // Pulse the border 3 times with blur
                    for i in 0..<3 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.8) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                pulseOpacity = 1
                                blur = 4
                            }
                            withAnimation(.easeIn(duration: 0.3).delay(0.3)) {
                                pulseOpacity = 0.3
                                blur = 0
                            }
                        }
                    }

                    // Hide after completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            manager.showAddBookBorderAnimation = false
                            pulseOpacity = 0
                            blur = 0
                        }
                    }
                }
            }
    }
}

// MARK: - Shake Animation
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

extension View {
    func shakeEffect(trigger: Bool) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

struct ShakeModifier: ViewModifier {
    let trigger: Bool
    @State private var shakes: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: shakes))
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    withAnimation(.default.repeatCount(3, autoreverses: true).speed(2)) {
                        shakes += 1
                    }
                }
            }
    }
}

// MARK: - Blur to Amber Animation for Ambient Icon
struct BlurToAmberAnimation: ViewModifier {
    @State private var blur: CGFloat = 0
    @State private var amberOpacity: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var showAnimation = false
    let isActive: Bool

    private let warmAmber = DesignSystem.Colors.primaryAccent

    func body(content: Content) -> some View {
        Group {
            if showAnimation {
                ZStack {
                    // Original icon with blur
                    content
                        .blur(radius: blur)
                        .scaleEffect(scale)
                        .opacity(1 - amberOpacity * 0.5)  // Stronger fade

                    // Amber version that fades in with glow
                    content
                        .foregroundStyle(warmAmber)
                        .blur(radius: blur * 0.3)
                        .scaleEffect(scale)
                        .opacity(amberOpacity)
                        .shadow(color: warmAmber.opacity(amberOpacity * 0.6), radius: 8)  // Glow effect
                }
            } else {
                // Normal icon when animation is not active
                content
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                // Start animation with more dramatic initial state
                showAnimation = true
                blur = 12  // More blur
                scale = 0.6  // Smaller initial scale
                amberOpacity = 0

                // Slower, more dramatic animation
                withAnimation(.easeOut(duration: 1.8)) {
                    blur = 0
                    scale = 1.3  // Bigger scale up
                }
                withAnimation(.easeIn(duration: 1.0).delay(0.5)) {
                    amberOpacity = 1
                }

                // Multiple pulse effects for attention
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                        scale = 1.0
                    }
                }

                // Second pulse
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        scale = 1.15
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        scale = 1.0
                    }
                }

                // Complete reset after animation (extended time)
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        blur = 0
                        amberOpacity = 0
                        scale = 1.0
                        showAnimation = false
                    }
                }
            }
        }
    }
}

// MARK: - Double Tap Hint Pill
struct DoubleTapHintPill: View {
    @StateObject private var manager = MicroInteractionManager.shared
    @State private var opacity: Double = 0

    var body: some View {
        if manager.showDoubleTapHint {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 14, weight: .semibold))
                Text("Double tap screen to switch to keyboard mode")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Spacing.cardPadding)
            .padding(.vertical, 12)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large, style: .continuous))
            .opacity(opacity)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    opacity = 1
                }
            }
        }
    }
}