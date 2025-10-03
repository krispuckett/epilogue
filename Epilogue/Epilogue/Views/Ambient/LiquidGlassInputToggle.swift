import SwiftUI

/// Clean toggle matching iOS style - just two icons in glass background
struct LiquidGlassInputToggle: View {
    @Binding var isVoiceMode: Bool

    private let toggleWidth: CGFloat = 80
    private let toggleHeight: CGFloat = 40

    var body: some View {
        HStack(spacing: 0) {
            // Keyboard icon (left side)
            Image(systemName: "keyboard")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(isVoiceMode ? 0.4 : 1.0))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(isVoiceMode ? 0.9 : 1.0)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isVoiceMode {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isVoiceMode = false
                        }
                        SensoryFeedback.selection()
                    }
                }

            // Waveform icon (right side)
            Image(systemName: "waveform")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(isVoiceMode ? 1.0 : 0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(isVoiceMode ? 1.0 : 0.9)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isVoiceMode {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isVoiceMode = true
                        }
                        SensoryFeedback.selection()
                    }
                }
        }
        .frame(width: toggleWidth, height: toggleHeight)
        .glassEffect(in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        VStack(spacing: 40) {
            LiquidGlassInputToggle(isVoiceMode: .constant(false))
            LiquidGlassInputToggle(isVoiceMode: .constant(true))
        }
    }
}