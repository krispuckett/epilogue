import SwiftUI

// MARK: - Subtle Breathing Effect (Most Ethereal)
struct EtherealBreathingTranscription: View {
    let text: String
    @State private var displayText: String = ""
    @State private var breathScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        GeometryReader { geometry in
            Text(displayText)
            .font(.system(size: 19, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .truncationMode(.head)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: geometry.size.width - 80)
            .scaleEffect(breathScale)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .white.opacity(glowOpacity), radius: 20)
            .onChange(of: text) { _, newText in
                // Smooth text update
                withAnimation(.easeInOut(duration: 0.3)) {
                    // Pulse on new text
                    breathScale = 1.02
                    glowOpacity = 0.5
                }
                
                displayText = String(newText.suffix(80))
                
                // Return to normal
                withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                    breathScale = 1.0
                    glowOpacity = 0.3
                }
            }
            .onAppear {
                displayText = String(text.suffix(80))
                startBreathing()
            }
    }
    
    private func startBreathing() {
        // Subtle continuous breathing
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            breathScale = 1.01
            glowOpacity = 0.4
        }
        }
    }
}