import SwiftUI

// MARK: - Subtle Liquid Thinking Effect
// Minimal, ambient-friendly thinking indicator that morphs the message bubble

struct SubtleLiquidThinking: View {
    let bookColor: Color
    @State private var morphPhase: CGFloat = 0
    
    var body: some View {
        // Vibrant amber glass dots animation
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2))
                    .frame(width: 12, height: 12)
                    .glassEffect()
                    .overlay {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.55, blue: 0.26))
                            .frame(width: 4, height: 4)
                            .opacity(0.6 + morphPhase * 0.4)
                    }
                    .scaleEffect(1.0 + morphPhase * 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: morphPhase
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                morphPhase = 1.0
            }
        }
    }
}

// MARK: - Message with Thinking State
struct MessageWithThinking: View {
    let message: String?
    let isThinking: Bool
    let bookColor: Color
    
    var body: some View {
        Group {
            if isThinking && message == nil {
                // Show subtle thinking indicator
                SubtleLiquidThinking(bookColor: bookColor)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 1.1).combined(with: .opacity)
                    ))
            } else if let message = message {
                // Show the actual message
                Text(message)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isThinking)
    }
}