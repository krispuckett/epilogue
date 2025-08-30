import SwiftUI

// MARK: - Shimmer Effect Modifier
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    let bounce: Bool
    
    init(duration: Double = 2.5, bounce: Bool = false) {
        self.duration = duration
        self.bounce = bounce
    }
    
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: DesignSystem.Colors.textQuaternary, location: 0.5),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                    .mask(content)
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                withAnimation(
                    Animation.linear(duration: duration)
                        .repeatForever(autoreverses: bounce)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer(duration: Double = 2.5, bounce: Bool = false) -> some View {
        modifier(ShimmerEffect(duration: duration, bounce: bounce))
    }
}

// MARK: - Parallax Motion Effect
struct ParallaxMotionModifier: ViewModifier {
    @State private var motionX: Double = 0
    @State private var motionY: Double = 0
    let magnitude: Double
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(motionY * magnitude),
                axis: (x: 1, y: 0, z: 0)
            )
            .rotation3DEffect(
                .degrees(motionX * magnitude),
                axis: (x: 0, y: 1, z: 0)
            )
            .onReceive(NotificationCenter.default.publisher(for: .deviceMotionUpdate)) { notification in
                if let motion = notification.object as? (x: Double, y: Double) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        motionX = motion.x
                        motionY = motion.y
                    }
                }
            }
    }
}

extension View {
    func parallaxMotion(magnitude: Double = 10) -> some View {
        modifier(ParallaxMotionModifier(magnitude: magnitude))
    }
}

// Device motion notification extension
extension Notification.Name {
    static let deviceMotionUpdate = Notification.Name("deviceMotionUpdate")
}