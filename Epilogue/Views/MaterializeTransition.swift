import SwiftUI

// Custom transition that simulates a materialize effect
extension AnyTransition {
    static var glassAppear: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: GlassMaterializeModifier(progress: 0),
                identity: GlassMaterializeModifier(progress: 1)
            ),
            removal: .modifier(
                active: GlassMaterializeModifier(progress: 0),
                identity: GlassMaterializeModifier(progress: 1)
            )
        )
    }
}

struct GlassMaterializeModifier: ViewModifier {
    let progress: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .scaleEffect(
                x: 0.8 + (0.2 * progress),
                y: 0.9 + (0.1 * progress),
                anchor: .bottom
            )
            .blur(radius: (1 - progress) * 3)
            .offset(y: (1 - progress) * 20)
    }
}

// Extension to apply glass-like transitions
extension View {
    func glassTransition(_ type: GlassTransitionType) -> some View {
        switch type {
        case .identity:
            return self.transition(.identity)
        case .materialize:
            return self.transition(.glassAppear)
        case .matchedGeometry:
            return self.transition(.asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .scale(scale: 1.05).combined(with: .opacity)
            ))
        }
    }
}

enum GlassTransitionType {
    case identity
    case materialize
    case matchedGeometry
}