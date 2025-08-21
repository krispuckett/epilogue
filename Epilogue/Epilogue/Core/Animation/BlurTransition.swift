import SwiftUI

// MARK: - Custom Blur Transition
struct BlurTransitionModifier: ViewModifier {
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .blur(radius: radius, opaque: true) // opaque: true for better performance
    }
}

extension AnyTransition {
    static func blur(radius: CGFloat) -> AnyTransition {
        .modifier(
            active: BlurTransitionModifier(radius: radius),
            identity: BlurTransitionModifier(radius: 0)
        )
    }
    
    static var blurIn: AnyTransition {
        .modifier(
            active: BlurTransitionModifier(radius: 10),
            identity: BlurTransitionModifier(radius: 0)
        )
    }
    
    static var blurOut: AnyTransition {
        .modifier(
            active: BlurTransitionModifier(radius: 5),
            identity: BlurTransitionModifier(radius: 0)
        )
    }
    
    // Combined transitions for ambient effects
    static var ambientAppear: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.8))
                .combined(with: .modifier(
                    active: BlurTransitionModifier(radius: 10),
                    identity: BlurTransitionModifier(radius: 0)
                )),
            removal: .opacity
                .combined(with: .scale(scale: 1.1))
                .combined(with: .modifier(
                    active: BlurTransitionModifier(radius: 5),
                    identity: BlurTransitionModifier(radius: 0)
                ))
        )
    }
    
    static var etherealAppear: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .modifier(
                    active: BlurTransitionModifier(radius: 8),
                    identity: BlurTransitionModifier(radius: 0)
                )),
            removal: .opacity
                .combined(with: .scale(scale: 0.98))
        )
    }
}