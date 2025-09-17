import SwiftUI

// MARK: - Themed Gradient Background
/// Ultra-premium gradient background that responds to theme selection
struct ThemedGradientBackground: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var breathe = false
    @State private var morph = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            ThemedBreathingGradient(
                theme: themeManager.currentTheme,
                breathe: breathe,
                morph: morph,
                pulse: pulse
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: themeManager.currentTheme)
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: themeManager.currentTheme) { _, newTheme in
            // Restart animations with new theme's timing
            restartAnimations(for: newTheme)
        }
    }

    private func startAnimations() {
        let theme = themeManager.currentTheme

        withAnimation(.easeInOut(duration: theme.animationDuration).repeatForever()) {
            breathe = true
        }

        withAnimation(.easeInOut(duration: theme.animationDuration * 1.6).repeatForever()) {
            morph = true
        }

        // Add subtle pulse for certain themes
        if theme == .volcanic || theme == .aurora {
            withAnimation(.easeInOut(duration: theme.animationDuration * 0.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func restartAnimations(for theme: GradientTheme) {
        // Reset states
        breathe = false
        morph = false
        pulse = false

        // Restart with new timing after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startAnimations()
        }
    }
}

// MARK: - Themed Breathing Gradient
struct ThemedBreathingGradient: View {
    let theme: GradientTheme
    let breathe: Bool
    let morph: Bool
    let pulse: Bool

    var body: some View {
        ZStack {
            // Primary gradient layer
            primaryGradient

            // Secondary accent layer
            secondaryGradient
                .opacity(theme.animationIntensity)

            // Special effects for specific themes
            themeSpecificEffects
        }
    }

    @ViewBuilder
    private var primaryGradient: some View {
        let colors = theme.gradientColors

        // Top breathing gradient
        RadialGradient(
            colors: [
                colors[0],
                colors[0].opacity(0.6),
                colors[1].opacity(0.3),
                .clear
            ],
            center: UnitPoint(x: 0.5, y: breathe ? -0.1 : 0.1),
            startRadius: breathe ? 50 : 100,
            endRadius: breathe ? 400 : 350
        )
        .scaleEffect(pulse ? 1.05 : 1.0)

        // Bottom breathing gradient
        RadialGradient(
            colors: [
                colors[1],
                colors[1].opacity(0.6),
                colors[2].opacity(0.3),
                .clear
            ],
            center: UnitPoint(x: 0.5, y: breathe ? 1.1 : 0.9),
            startRadius: breathe ? 50 : 100,
            endRadius: breathe ? 400 : 350
        )
        .scaleEffect(pulse ? 1.05 : 1.0)
    }

    @ViewBuilder
    private var secondaryGradient: some View {
        let colors = theme.gradientColors

        // Morphing center blob
        Circle()
            .fill(
                RadialGradient(
                    colors: [colors[2].opacity(0.3), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
            )
            .scaleEffect(morph ? 1.5 : 1.0)
            .offset(y: morph ? -50 : 50)
            .blur(radius: 30)

        // Side accent blobs
        HStack(spacing: 0) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [colors[0].opacity(0.2), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .scaleEffect(morph ? 1.2 : 0.8)
                .offset(x: morph ? 30 : -30)
                .blur(radius: 40)

            Spacer()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [colors[3].opacity(0.2), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .scaleEffect(morph ? 0.8 : 1.2)
                .offset(x: morph ? -30 : 30)
                .blur(radius: 40)
        }
    }

    @ViewBuilder
    private var themeSpecificEffects: some View {
        switch theme {
        case .aurora:
            // Aurora borealis flowing effect
            AuroraEffect(breathe: breathe, colors: theme.gradientColors)

        case .nebula:
            // Subtle glow dots for nebula
            NebulaGlowEffect(pulse: pulse, color: theme.gradientColors[0])

        case .ocean:
            // Wave-like overlay for ocean
            WaveEffect(breathe: breathe, color: theme.gradientColors[1])

        case .volcanic:
            // Ember particles for volcanic
            EmberEffect(pulse: pulse, colors: theme.gradientColors)

        default:
            EmptyView()
        }
    }
}

// MARK: - Theme-Specific Effects

struct AuroraEffect: View {
    let breathe: Bool
    let colors: [Color]

    var body: some View {
        LinearGradient(
            colors: [
                colors[0].opacity(0.3),
                colors[1].opacity(0.2),
                colors[2].opacity(0.3),
                .clear
            ],
            startPoint: breathe ? .topLeading : .topTrailing,
            endPoint: breathe ? .bottomTrailing : .bottomLeading
        )
        .blur(radius: 60)
        .blendMode(.screen)
    }
}

struct NebulaGlowEffect: View {
    let pulse: Bool
    let color: Color

    var body: some View {
        ZStack {
            // Simple subtle glow dots without sparkles
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(pulse ? 0.3 : 0.2), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .position(
                        x: CGFloat(100 + index * 100),
                        y: CGFloat(200 + index * 150)
                    )
                    .blur(radius: 15)
                    .scaleEffect(pulse ? 1.2 : 0.8)
            }
        }
    }
}

struct WaveEffect: View {
    let breathe: Bool
    let color: Color

    var body: some View {
        Wave(phase: breathe ? .pi : 0)
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.1), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 200)
            .offset(y: 300)
            .blur(radius: 20)
    }
}

struct EmberEffect: View {
    let pulse: Bool
    let colors: [Color]

    var body: some View {
        VStack {
            Spacer()

            LinearGradient(
                colors: [
                    colors[0].opacity(pulse ? 0.4 : 0.2),
                    colors[1].opacity(pulse ? 0.3 : 0.15),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 300)
            .blur(radius: 30)
            .blendMode(.plusLighter)
        }
    }
}

// MARK: - Wave Shape
struct Wave: Shape {
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2

        path.move(to: CGPoint(x: 0, y: midHeight))

        for x in stride(from: 0, to: width, by: 1) {
            let relativeX = x / width
            let y = midHeight + sin(relativeX * .pi * 2 + phase) * 20
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}