import SwiftUI

// MARK: - Subtle Themed Background
/// Matches the original amber gradient's subtlety - just a gentle glow at the bottom
struct SubtleThemedBackground: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var breathe = false

    var body: some View {
        ZStack {
            // Pure black background
            Color.black
                .ignoresSafeArea()

            // Theme-specific gradient - forces complete redraw
            gradientForTheme(themeManager.currentTheme)
                .id(themeManager.currentTheme) // Force complete redraw on theme change
        }
        .onAppear {
            startBreathing()
        }
        .onChange(of: themeManager.currentTheme) { _, _ in
            // Reset animation on theme change
            breathe = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startBreathing()
            }
        }
    }

    @ViewBuilder
    private func gradientForTheme(_ theme: GradientTheme) -> some View {
        ZStack {
            // Very subtle gradient at bottom only
            VStack {
                Spacer()

                // Bottom gradient - subtle like the original
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: Color.clear, location: 0.4),
                        .init(color: theme.primaryAccent.opacity(0.1), location: 0.7),
                        .init(color: theme.primaryAccent.opacity(0.2), location: 0.85),
                        .init(color: theme.primaryAccent.opacity(0.25), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: UIScreen.main.bounds.height * 0.5)
                .blur(radius: 60)
                .opacity(breathe ? 0.9 : 0.75)
            }
            .ignoresSafeArea()

            // Extra subtle radial glow at very bottom
            VStack {
                Spacer()

                RadialGradient(
                    colors: [
                        theme.primaryAccent.opacity(0.2),
                        theme.primaryAccent.opacity(0.1),
                        Color.clear
                    ],
                    center: .bottom,
                    startRadius: 0,
                    endRadius: 200
                )
                .frame(height: 150)
                .blur(radius: 40)
                .opacity(breathe ? 0.8 : 0.6)
            }
            .ignoresSafeArea()
        }
    }

    private func startBreathing() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            breathe = true
        }
    }
}

// MARK: - Preview
#Preview {
    SubtleThemedBackground()
        .preferredColorScheme(.dark)
}