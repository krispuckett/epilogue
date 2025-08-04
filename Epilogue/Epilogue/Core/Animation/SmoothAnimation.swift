import SwiftUI

// MARK: - Smooth Animation Types
enum SmoothAnimationType {
    case bouncy
    case smooth
    case snappy
    case gentle
    
    var animation: Animation {
        switch self {
        case .bouncy:
            return .spring(response: 0.4, dampingFraction: 0.65, blendDuration: 0.25)
        case .smooth:
            return .spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.25)
        case .snappy:
            return .spring(response: 0.3, dampingFraction: 0.75, blendDuration: 0.25)
        case .gentle:
            return .spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.25)
        }
    }
}

// MARK: - Smooth Transition Modifier
struct SmoothTransition: ViewModifier {
    let type: SmoothAnimationType
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .animation(type.animation, value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Interruptible Animation Modifier
struct InterruptibleAnimation<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value
    @State private var previousValue: Value?
    @State private var animationID = UUID()
    
    init(animation: Animation = .smooth, value: Value) {
        self.animation = animation
        self.value = value
    }
    
    func body(content: Content) -> some View {
        content
            .animation(animation, value: animationID)
            .onChange(of: value) { oldValue, newValue in
                // Cancel previous animation by changing ID
                animationID = UUID()
                previousValue = oldValue
            }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply smooth, awards-worthy animation
    func smoothAnimation(_ type: SmoothAnimationType = .smooth) -> some View {
        modifier(SmoothTransition(type: type))
    }
    
    /// Apply interruptible animation that can be cancelled mid-flight
    func interruptibleAnimation<V: Equatable>(_ type: SmoothAnimationType = .smooth, value: V) -> some View {
        modifier(InterruptibleAnimation(animation: type.animation, value: value))
    }
    
    /// Smooth scale effect with proper interruption handling
    func smoothScale(_ scale: CGFloat, isActive: Bool) -> some View {
        self
            .scaleEffect(isActive ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.25), value: isActive)
    }
    
    /// Smooth opacity transition
    func smoothOpacity(_ opacity: Double, isVisible: Bool) -> some View {
        self
            .opacity(isVisible ? opacity : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.25), value: isVisible)
    }
}

// MARK: - Custom Transitions
extension AnyTransition {
    /// Smooth slide transition with proper interruption
    static var smoothSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom)
                .combined(with: .opacity)
                .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.25)),
            removal: .move(edge: .bottom)
                .combined(with: .opacity)
                .animation(.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.25))
        )
    }
    
    /// Glass effect appearance
    static var glassAppear: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.95, anchor: .center)
                .combined(with: .opacity)
                .animation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.25)),
            removal: .scale(scale: 0.95, anchor: .center)
                .combined(with: .opacity)
                .animation(.spring(response: 0.3, dampingFraction: 0.85, blendDuration: 0.25))
        )
    }
    
    /// Book card transition
    static var bookCard: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9, anchor: .bottom)
                .combined(with: .opacity)
                .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.25)),
            removal: .scale(scale: 0.9, anchor: .bottom)
                .combined(with: .opacity)
                .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.25))
        )
    }
}

// MARK: - Animation Completion Handler
struct AnimationWithCompletion: ViewModifier {
    let animation: Animation
    let completion: () -> Void
    @State private var animationFlag = false
    
    func body(content: Content) -> some View {
        content
            .animation(animation, value: animationFlag)
            .onAppear {
                DispatchQueue.main.async {
                    animationFlag = true
                    
                    // Calculate animation duration and call completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        completion()
                    }
                }
            }
    }
}

extension View {
    func animationWithCompletion(_ animation: Animation = .smooth, completion: @escaping () -> Void) -> some View {
        modifier(AnimationWithCompletion(animation: animation, completion: completion))
    }
}