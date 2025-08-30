import SwiftUI

// MARK: - Helper Modifiers
struct BlurModifier: ViewModifier {
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

// MARK: - iOS 26 Liquid Glass Effects
struct LiquidGlassModifier: ViewModifier {
    let intensity: Double
    let tint: Color
    let blur: Double
    
    init(intensity: Double = 0.8, tint: Color = .clear, blur: Double = 20) {
        self.intensity = intensity
        self.tint = tint
        self.blur = blur
    }
    
    func body(content: Content) -> some View {
        content
            .background {
                // Multi-layer glass effect for depth
                ZStack {
                    // Base glass layer
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(intensity)
                    
                    // Tint layer
                    if tint != .clear {
                        Rectangle()
                            .fill(tint.opacity(0.1))
                    }
                    
                    // Shimmer effect
                    LiquidShimmerView()
                        .opacity(0.3)
                }
            }
            .overlay {
                // Subtle inner glow
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
    }
}

// MARK: - Liquid Shimmer Effect
struct LiquidShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.1), location: 0.5),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .scaleEffect(x: 3, y: 3)
            .rotationEffect(.degrees(30))
            .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
            .mask(Rectangle())
            .onAppear {
                withAnimation(
                    .linear(duration: 3)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
        }
    }
}

// MARK: - Liquid Morph Transition
struct LiquidMorphTransition: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1 : 0.8)
            .opacity(isActive ? 1 : 0)
            .blur(radius: isActive ? 0 : 10)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3),
                value: isActive
            )
    }
}

// MARK: - Ripple Touch Effect
struct RippleTouchEffect: ViewModifier {
    @State private var ripples: [Ripple] = []
    
    struct Ripple: Identifiable {
        let id = UUID()
        let position: CGPoint
        let startTime: Date
    }
    
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    ForEach(ripples) { ripple in
                        RippleView(
                            position: ripple.position,
                            startTime: ripple.startTime,
                            size: geometry.size
                        )
                    }
                }
                .allowsHitTesting(false)
            }
            .onTapGesture { location in
                let newRipple = Ripple(position: location, startTime: Date())
                ripples.append(newRipple)
                
                // Remove ripple after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    ripples.removeAll { $0.id == newRipple.id }
                }
            }
    }
}

struct RippleView: View {
    let position: CGPoint
    let startTime: Date
    let size: CGSize
    
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0.8
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        DesignSystem.Colors.textQuaternary,
                        Color.white.opacity(0.1),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 50
                )
            )
            .frame(width: 100, height: 100)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(position)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    scale = 4
                    opacity = 0
                }
            }
    }
}

// MARK: - Glass Morph Card
struct GlassMorphCard<Content: View>: View {
    let content: () -> Content
    @State private var isPressed = false
    
    var body: some View {
        content()
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .strokeBorder(
                        Color.white.opacity(0.2),
                        lineWidth: 0.5
                    )
            }
            .scaleEffect(isPressed ? 0.97 : 1)
            .animation(DesignSystem.Animation.springStandard, value: isPressed)
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

// MARK: - View Extensions
extension View {
    func liquidGlass(intensity: Double = 0.8, tint: Color = .clear, blur: Double = 20) -> some View {
        modifier(LiquidGlassModifier(intensity: intensity, tint: tint, blur: blur))
    }
    
    func liquidMorph(isActive: Bool) -> some View {
        modifier(LiquidMorphTransition(isActive: isActive))
    }
    
    func rippleTouchEffect() -> some View {
        modifier(RippleTouchEffect())
    }
    
    func glassMorphCard() -> some View {
        GlassMorphCard { self }
    }
}

// MARK: - Animated Glass Transitions
extension AnyTransition {
    static var liquidGlass: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8, anchor: .bottom)
                .combined(with: .opacity)
                .combined(with: .modifier(
                    active: BlurModifier(radius: 20),
                    identity: BlurModifier(radius: 0)
                ))
                .animation(.spring(response: 0.5, dampingFraction: 0.7)),
            removal: .scale(scale: 1.1, anchor: .top)
                .combined(with: .opacity)
                .combined(with: .modifier(
                    active: BlurModifier(radius: 20),
                    identity: BlurModifier(radius: 0)
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.8))
        )
    }
    
    static var glassMelt: AnyTransition {
        .modifier(
            active: GlassMeltModifier(progress: 0),
            identity: GlassMeltModifier(progress: 1)
        )
    }
}

struct GlassMeltModifier: ViewModifier {
    let progress: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(
                x: 1 + (1 - progress) * 0.2,
                y: 1 - (1 - progress) * 0.3,
                anchor: .bottom
            )
            .opacity(progress)
            .blur(radius: (1 - progress) * 20)
            .offset(y: (1 - progress) * 100)
    }
}