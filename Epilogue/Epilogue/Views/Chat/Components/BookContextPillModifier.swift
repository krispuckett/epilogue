import SwiftUI

// MARK: - Conditional Glass Effect Modifier

struct ConditionalGlassEffectModifier: ViewModifier {
    let disableGlassEffect: Bool
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        if disableGlassEffect {
            content
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }
        } else {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                }
        }
    }
}