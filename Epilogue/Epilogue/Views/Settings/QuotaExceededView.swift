import SwiftUI

struct QuotaExceededView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var quotaManager = PerplexityQuotaManager.shared

    // Animation states
    @State private var contentOpacity: Double = 0
    @State private var gradientOpacity: Double = 0

    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()

            // Amber gradient overlay from top to bottom
            VStack {
                Spacer()
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: Color.clear, location: 0.5),
                        .init(color: themeManager.currentTheme.primaryAccent.opacity(0.15), location: 0.7),
                        .init(color: themeManager.currentTheme.primaryAccent.opacity(0.3), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: UIScreen.main.bounds.height * 0.6)
            }
            .ignoresSafeArea()
            .opacity(gradientOpacity)

            // Content overlay
            VStack {
                Spacer()

                // Quota Card
                VStack(spacing: 16) {
                    // Icon
                    Image(systemName: "hourglass.tophalf.filled")
                        .font(.system(size: 48))
                        .foregroundStyle(themeManager.currentTheme.primaryAccent)
                        .padding(.bottom, 8)

                    // Title
                    VStack(spacing: 8) {
                        Text("DAILY LIMIT REACHED")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)

                        Text("You've used all 10 Perplexity questions today")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }

                    // Reset time
                    VStack(spacing: 6) {
                        Text("Questions reset in")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))

                        Text(quotaManager.timeUntilReset)
                            .font(.system(size: 24, weight: .semibold, design: .monospaced))
                            .foregroundStyle(themeManager.currentTheme.primaryAccent)
                    }
                    .padding(.vertical, 8)

                    Divider()
                        .background(Color.white.opacity(0.2))

                    // TestFlight info
                    VStack(spacing: 8) {
                        Text("TestFlight Beta")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))

                        Text("Daily limits help us manage API costs during beta.\nThank you for understanding!")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }

                    // Continue without AI button
                    Button {
                        dismiss()
                    } label: {
                        Text("Continue Reading")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .glassEffect(in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                themeManager.currentTheme.primaryAccent.opacity(0.5),
                                                themeManager.currentTheme.primaryAccent.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 20)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .opacity(contentOpacity)
            }
        }
        .presentationDetents([.fraction(0.75)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(false)
        .onAppear {
            animateContent()
        }
    }

    private func animateContent() {
        withAnimation(.easeOut(duration: 0.5)) {
            gradientOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            contentOpacity = 1
        }
    }
}

// MARK: - Preview

#Preview {
    QuotaExceededView()
        .preferredColorScheme(.dark)
}