import SwiftUI

// MARK: - Liquid Glass Action Pills
/// iOS 26 Liquid Glass design for quote capture actions
/// Beautiful, translucent pills with smooth spring animations

struct LiquidGlassActionPills: View {
    let selectedText: String
    let onSave: () -> Void
    let onAsk: () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 20) {
            // Save Quote Pill
            LiquidGlassPill(
                icon: "quote.bubble.fill",
                label: "Save",
                color: .white,
                action: onSave
            )

            // Ask Epilogue Pill
            LiquidGlassPill(
                icon: "bubble.left.and.text.bubble.right",
                label: "Ask",
                color: .orange,
                action: onAsk,
                hasSymbolEffect: false
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)  // Lower for thumb reach
        .offset(y: appeared ? 0 : 100)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}

// MARK: - Single Liquid Glass Pill

struct LiquidGlassPill: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    var hasSymbolEffect: Bool = false

    @State private var isPressed = false
    @State private var isHovering = false

    var body: some View {
        Button(action: {
            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // Visual feedback
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }

            // Delayed action for animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolEffect(.bounce, value: isPressed)

                Text(label)
                    .font(.system(size: 18, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
        }
        .glassEffect(in: .capsule)  // iOS 26 Liquid Glass
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .shadow(
            color: color.opacity(isPressed ? 0.4 : 0.2),
            radius: isPressed ? 16 : 8,
            y: isPressed ? 4 : 2
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            LiquidGlassActionPills(
                selectedText: "Example quote text",
                onSave: {
                    print("Save tapped")
                },
                onAsk: {
                    print("Ask tapped")
                }
            )
        }
    }
}
