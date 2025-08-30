import SwiftUI

struct SettingsButton: View {
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
            DesignSystem.HapticFeedback.light()
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                .rotationEffect(.degrees(rotation))
                .scaleEffect(isPressed ? 0.85 : 1.0)
                .opacity(isPressed ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isPressed)
    }
}

// MARK: - Alternative Icon Styles
extension SettingsButton {
    // Clean vector-based settings icon
    struct CleanSettingsIcon: View {
        let size: CGFloat
        let color: Color
        
        var body: some View {
            ZStack {
                // Main gear body
                Circle()
                    .stroke(color, lineWidth: size * 0.12)
                    .frame(width: size * 0.6, height: size * 0.6)
                
                // Gear teeth
                ForEach(0..<8) { index in
                    Rectangle()
                        .fill(color)
                        .frame(width: size * 0.08, height: size * 0.25)
                        .offset(y: -size * 0.375)
                        .rotationEffect(.degrees(Double(index) * 45))
                }
                
                // Center circle
                Circle()
                    .fill(color)
                    .frame(width: size * 0.25, height: size * 0.25)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Settings Button Style
struct SettingsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#if DEBUG
struct SettingsButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 40) {
            // SF Symbol version
            SettingsButton(isPressed: .constant(false)) {
                print("Settings tapped")
            }
            
            // Custom icon version
            Button(action: {}) {
                SettingsButton.CleanSettingsIcon(
                    size: 24,
                    color: Color(red: 0.98, green: 0.97, blue: 0.96)
                )
            }
            .buttonStyle(SettingsButtonStyle())
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
#endif