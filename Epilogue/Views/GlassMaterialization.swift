import SwiftUI

// MARK: - Glass Materialization Transition
struct MaterializeModifier: ViewModifier {
    let progress: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .scaleEffect(
                0.5 + (0.5 * progress),
                anchor: .bottom
            )
            .blur(radius: progress < 0.5 ? 10 * (1 - progress * 2) : 0)
            .offset(y: 50 * (1 - progress))
            .rotation3DEffect(
                .degrees((1 - progress) * 15),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
    }
}

// MARK: - Glass Shatter Effect
struct GlassShatterModifier: ViewModifier {
    let isShattered: Bool
    @State private var shardOffsets: [CGSize] = []
    @State private var shardRotations: [Double] = []
    
    func body(content: Content) -> some View {
        if isShattered {
            ZStack {
                ForEach(0..<6, id: \.self) { index in
                    content
                        .mask(ShardShape(index: index))
                        .offset(shardOffsets.indices.contains(index) ? shardOffsets[index] : .zero)
                        .rotationEffect(.degrees(shardRotations.indices.contains(index) ? shardRotations[index] : 0))
                        .opacity(isShattered ? 0 : 1)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    shardOffsets = (0..<6).map { _ in
                        CGSize(
                            width: Double.random(in: -100...100),
                            height: Double.random(in: -100...100)
                        )
                    }
                    shardRotations = (0..<6).map { _ in
                        Double.random(in: -180...180)
                    }
                }
            }
        } else {
            content
        }
    }
}

// MARK: - Shard Shape for Glass Effect
struct ShardShape: Shape {
    let index: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch index {
        case 0:
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.4, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.5))
            path.addLine(to: CGPoint(x: 0, y: rect.height * 0.3))
        case 1:
            path.move(to: CGPoint(x: rect.width * 0.4, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.8, y: rect.height * 0.4))
            path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.5))
        case 2:
            path.move(to: CGPoint(x: 0, y: rect.height * 0.3))
            path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.5))
            path.addLine(to: CGPoint(x: rect.width * 0.2, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
        case 3:
            path.move(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.5))
            path.addLine(to: CGPoint(x: rect.width * 0.8, y: rect.height * 0.4))
            path.addLine(to: CGPoint(x: rect.width * 0.7, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width * 0.2, y: rect.height))
        case 4:
            path.move(to: CGPoint(x: rect.width * 0.8, y: rect.height * 0.4))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.3))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width * 0.7, y: rect.height))
        default:
            path.move(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.3))
            path.addLine(to: CGPoint(x: rect.width * 0.8, y: rect.height * 0.4))
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Liquid Glass Transition
extension AnyTransition {
    static var glassMaterialize: AnyTransition {
        .modifier(
            active: MaterializeModifier(progress: 0),
            identity: MaterializeModifier(progress: 1)
        )
    }
    
    static func glassMaterialize(from anchor: UnitPoint = .bottom) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: MaterializeModifier(progress: 0),
                identity: MaterializeModifier(progress: 1)
            ).combined(with: .move(edge: .bottom)),
            removal: .modifier(
                active: MaterializeModifier(progress: 0),
                identity: MaterializeModifier(progress: 1)
            ).combined(with: .scale(scale: 0.8))
        )
    }
}

// MARK: - Glass Particle Emitter
struct GlassParticleView: View {
    let isEmitting: Bool
    @State private var particles: [GlassParticle] = []
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(.white.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .blur(radius: particle.blur)
            }
        }
        .onAppear {
            if isEmitting {
                startEmitting()
            }
        }
        .onChange(of: isEmitting) { _, newValue in
            if newValue {
                startEmitting()
            } else {
                withAnimation(.easeOut(duration: 1)) {
                    particles.removeAll()
                }
            }
        }
    }
    
    private func startEmitting() {
        for i in 0..<20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                let particle = GlassParticle()
                particles.append(particle)
                
                withAnimation(.easeOut(duration: 1.5)) {
                    if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                        particles[index].position.y -= 100
                        particles[index].opacity = 0
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    particles.removeAll { $0.id == particle.id }
                }
            }
        }
    }
}

struct GlassParticle: Identifiable {
    let id = UUID()
    var position: CGPoint = CGPoint(
        x: CGFloat.random(in: -50...50),
        y: 0
    )
    var size: CGFloat = CGFloat.random(in: 2...6)
    var opacity: Double = Double.random(in: 0.3...0.7)
    var blur: CGFloat = CGFloat.random(in: 0...2)
}

// MARK: - View Extension for Conditional Modifiers
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}