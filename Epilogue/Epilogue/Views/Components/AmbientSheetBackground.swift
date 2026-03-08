import SwiftUI

// MARK: - Shared Ambient Sheet Backgrounds

/// Subtle radial glow background for sheets (companion, invite flows)
struct AmbientRadialGlowBackground: View {
    var glowOpacity: Double = 0.15

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [
                    DesignSystem.Colors.primaryAccent.opacity(glowOpacity),
                    DesignSystem.Colors.primaryAccent.opacity(0.08),
                    Color.clear
                ],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()

            Color.white.opacity(0.02)
                .ignoresSafeArea()
        }
    }
}

/// Ambient chat gradient overlay for sheets (quote share, book search)
struct AmbientChatGradientBackground: View {
    var body: some View {
        ZStack {
            AmbientChatGradientView()
                .opacity(0.4)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            Color.black.opacity(0.15)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
        }
    }
}

/// Progress-responsive radial gradient for reading progress sheets
struct AmbientProgressBackground: View {
    let primaryColor: Color
    let secondaryColor: Color
    let displayProgress: Double

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [
                    primaryColor.opacity(0.3 * displayProgress),
                    secondaryColor.opacity(0.2 * displayProgress),
                    primaryColor.opacity(0.1 * displayProgress),
                    Color.clear
                ],
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: displayProgress)

            Color.white.opacity(0.02)
                .ignoresSafeArea()
        }
    }
}
