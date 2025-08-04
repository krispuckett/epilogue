import SwiftUI
import Combine

// MARK: - Micro Interactions
struct MicroBounce: ViewModifier {
    @State private var scale: CGFloat = 1
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _, _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 1.1
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) {
                    scale = 1
                }
            }
    }
}

// MARK: - Pulse Animation Effect
struct PulseAnimationEffect: ViewModifier {
    @State private var isPulsing = false
    let duration: Double
    let scale: CGFloat
    
    init(duration: Double = 2, scale: CGFloat = 1.05) {
        self.duration = duration
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? scale : 1)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Wiggle Effect
struct WiggleEffect: ViewModifier {
    @State private var isWiggling = false
    let amount: Double
    let trigger: Bool
    
    init(amount: Double = 3, trigger: Bool) {
        self.amount = amount
        self.trigger = trigger
    }
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isWiggling ? amount : 0))
            .animation(
                .easeInOut(duration: 0.1)
                .repeatCount(3, autoreverses: true),
                value: isWiggling
            )
            .onChange(of: trigger) { _, _ in
                isWiggling.toggle()
            }
    }
}

// MARK: - Glow Animation Effect
struct GlowAnimationEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var isGlowing = false
    
    init(color: Color = .white, radius: CGFloat = 20) {
        self.color = color
        self.radius = radius
    }
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: color.opacity(isGlowing ? 0.6 : 0.3),
                radius: isGlowing ? radius : radius / 2
            )
            .animation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true),
                value: isGlowing
            )
            .onAppear {
                isGlowing = true
            }
    }
}

// MARK: - Floating Effect
struct FloatingEffect: ViewModifier {
    @State private var offset: CGFloat = 0
    let amplitude: CGFloat
    
    init(amplitude: CGFloat = 5) {
        self.amplitude = amplitude
    }
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .animation(
                .easeInOut(duration: 2)
                .repeatForever(autoreverses: true),
                value: offset
            )
            .onAppear {
                offset = amplitude
            }
    }
}

// MARK: - Typewriter Effect
struct TypewriterEffect: ViewModifier {
    let text: String
    @State private var animatedText = ""
    @State private var currentIndex = 0
    let speed: Double
    
    init(text: String, speed: Double = 0.05) {
        self.text = text
        self.speed = speed
    }
    
    func body(content: Content) -> some View {
        Text(animatedText)
            .onAppear {
                animateText()
            }
            .onChange(of: text) { _, newText in
                animatedText = ""
                currentIndex = 0
                animateText()
            }
    }
    
    private func animateText() {
        guard currentIndex < text.count else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            let index = text.index(text.startIndex, offsetBy: currentIndex)
            animatedText.append(text[index])
            currentIndex += 1
            animateText()
        }
    }
}

// MARK: - Parallax Effect
struct ParallaxEffect: ViewModifier {
    @State private var offset: CGSize = .zero
    let magnitude: CGFloat
    
    init(magnitude: CGFloat = 20) {
        self.magnitude = magnitude
    }
    
    func body(content: Content) -> some View {
        content
            .offset(offset)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                withAnimation(.spring()) {
                    updateOffset()
                }
            }
            .onAppear {
                updateOffset()
            }
    }
    
    private func updateOffset() {
        // Simplified parallax based on device orientation
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let orientation = windowScene.interfaceOrientation
            switch orientation {
            case .portrait:
                offset = .zero
            case .landscapeLeft:
                offset = CGSize(width: -magnitude, height: 0)
            case .landscapeRight:
                offset = CGSize(width: magnitude, height: 0)
            default:
                offset = .zero
            }
        }
    }
}

// MARK: - Sparkle Effect
struct SparkleView: View {
    @State private var sparkles: [Sparkle] = []
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    struct Sparkle: Identifiable {
        let id = UUID()
        let position: CGPoint
        let size: CGFloat
        let rotation: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(sparkles) { sparkle in
                Image(systemName: "sparkle")
                    .font(.system(size: sparkle.size))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .yellow.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(sparkle.rotation))
                    .position(sparkle.position)
                    .transition(
                        .asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale(scale: 0.1).combined(with: .opacity)
                        )
                    )
            }
        }
        .onReceive(timer) { _ in
            addSparkle()
        }
    }
    
    private func addSparkle() {
        let sparkle = Sparkle(
            position: CGPoint(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
            ),
            size: CGFloat.random(in: 8...16),
            rotation: Double.random(in: 0...360)
        )
        
        withAnimation(.easeOut(duration: 1)) {
            sparkles.append(sparkle)
        }
        
        // Remove sparkle after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            sparkles.removeAll { $0.id == sparkle.id }
        }
    }
}

// MARK: - View Extensions
extension View {
    func microBounce(trigger: Bool) -> some View {
        modifier(MicroBounce(trigger: trigger))
    }
    
    func pulseAnimation(duration: Double = 2, scale: CGFloat = 1.05) -> some View {
        modifier(PulseAnimationEffect(duration: duration, scale: scale))
    }
    
    func wiggle(amount: Double = 3, trigger: Bool) -> some View {
        modifier(WiggleEffect(amount: amount, trigger: trigger))
    }
    
    func glowAnimation(color: Color = .white, radius: CGFloat = 20) -> some View {
        modifier(GlowAnimationEffect(color: color, radius: radius))
    }
    
    func floating(amplitude: CGFloat = 5) -> some View {
        modifier(FloatingEffect(amplitude: amplitude))
    }
    
    func typewriter(text: String, speed: Double = 0.05) -> some View {
        modifier(TypewriterEffect(text: text, speed: speed))
    }
    
    func parallax(magnitude: CGFloat = 20) -> some View {
        modifier(ParallaxEffect(magnitude: magnitude))
    }
    
    func sparkleOverlay() -> some View {
        overlay(SparkleView())
    }
}