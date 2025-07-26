import SwiftUI

struct AmbientOrbButton: View {
    @Binding var isActive: Bool
    @State private var isPressed = false
    @State private var breathingScale: CGFloat = 1.0
    let onTap: (() -> Void)?
    
    init(isActive: Binding<Bool>, onTap: (() -> Void)? = nil) {
        self._isActive = isActive
        self.onTap = onTap
    }
    
    var body: some View {
        // Glass container with waveform icon
        Button(action: {
            HapticManager.shared.mediumTap()
            onTap?()
        }) {
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.warmAmber)
                .frame(width: 36, height: 36)
                .glassEffect(in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.warmAmber.opacity(0.3), lineWidth: 0.5)
                }
                .scaleEffect(isPressed ? 0.9 : breathingScale)
                .shadow(color: .warmAmber.opacity(0.3), radius: 8)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: breathingScale)
        .onAppear {
            breathingScale = 1.05
        }
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
    }
}