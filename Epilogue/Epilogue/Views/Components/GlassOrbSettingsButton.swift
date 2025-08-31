import SwiftUI

struct GlassOrbSettingsButton: View {
    @Binding var isPressed: Bool
    let action: () -> Void
    
    @State private var rotation: Double = 0
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: {
            // Trigger action
            action()
            
            // Animate rotation
            withAnimation(.interpolatingSpring(mass: 0.5, stiffness: 200, damping: 15)) {
                rotation += 360
                isAnimating = true
            }
            
            // Reset animation state after completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAnimating = false
            }
            
            // Haptic feedback
            SensoryFeedback.light()
        }) {
            ZStack {
                // Glass orb background
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.textQuaternary,
                                        .white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                
                // Settings icon
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .rotationEffect(.degrees(rotation))
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isPressed)
    }
}

// MARK: - Preview
#if DEBUG
struct GlassOrbSettingsButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            GlassOrbSettingsButton(isPressed: .constant(false)) {
                print("Settings tapped")
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif