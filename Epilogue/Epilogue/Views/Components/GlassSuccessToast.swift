import SwiftUI

// MARK: - Simple Success Toast
struct GlassSuccessToast: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                Capsule()
                    .fill(.regularMaterial)
                    .overlay {
                        Capsule()
                            .fill(Color.black.opacity(0.2))
                    }
            }
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
    }
}

// MARK: - Toast Modifier
struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isShowing {
                    GlassSuccessToast(message: message)
                        .padding(.bottom, 140) // Position above command palette
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .identity
                        ))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isShowing = false
                                }
                            }
                        }
                }
            }
    }
}

// MARK: - View Extension
extension View {
    func glassToast(isShowing: Binding<Bool>, message: String, duration: Double = 3.0) -> some View {
        modifier(ToastModifier(
            isShowing: isShowing,
            message: message,
            duration: duration
        ))
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VStack(spacing: 40) {
            GlassSuccessToast(message: "Book added to library")
            GlassSuccessToast(message: "Note saved")
            GlassSuccessToast(message: "Quote captured")
            GlassSuccessToast(message: "Chat deleted")
        }
    }
}