import SwiftUI
import Combine

// MARK: - Cognitive Pattern Visualizer
struct CognitivePatternVisualizer: View {
    let patterns: [PatternMatch]
    @State private var animatedPatterns: [AnimatedPattern] = []
    @State private var particleSystem = ParticleSystem()
    
    var body: some View {
        ZStack {
            // Pattern indicators
            ForEach(animatedPatterns) { pattern in
                PatternIndicator(pattern: pattern)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.1).combined(with: .opacity),
                        removal: .scale(scale: 1.5).combined(with: .opacity)
                    ))
            }
            
            // Particle effects
            Canvas { context, size in
                particleSystem.draw(in: context, size: size)
            }
            .allowsHitTesting(false)
            .animation(.linear(duration: 0.016).repeatForever(autoreverses: false), value: particleSystem.time)
            .onAppear {
                particleSystem.startAnimation()
            }
        }
        .onChange(of: patterns) { _, newPatterns in
            updateAnimatedPatterns(newPatterns)
        }
    }
    
    private func updateAnimatedPatterns(_ newPatterns: [PatternMatch]) {
        // Add new patterns with animation
        for pattern in newPatterns {
            if !animatedPatterns.contains(where: { $0.pattern.pattern == pattern.pattern }) {
                let animated = AnimatedPattern(
                    id: UUID(),
                    pattern: pattern,
                    position: randomPosition(),
                    scale: 1.0,
                    opacity: 1.0
                )
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animatedPatterns.append(animated)
                    
                    // Add particles for this pattern
                    particleSystem.emitParticles(
                        at: animated.position,
                        color: Color(hexString: pattern.pattern.color),
                        count: 10
                    )
                }
                
                // Remove after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        animatedPatterns.removeAll { $0.id == animated.id }
                    }
                }
            }
        }
    }
    
    private func randomPosition() -> CGPoint {
        CGPoint(
            x: CGFloat.random(in: 100...300),
            y: CGFloat.random(in: 100...400)
        )
    }
}

// MARK: - Animated Pattern Model
struct AnimatedPattern: Identifiable {
    let id: UUID
    let pattern: PatternMatch
    var position: CGPoint
    var scale: CGFloat
    var opacity: Double
}

// MARK: - Pattern Indicator View
struct PatternIndicator: View {
    let pattern: AnimatedPattern
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Pattern icon
            ZStack {
                // Glowing background
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hexString: pattern.pattern.pattern.color).opacity(0.3),
                                Color(hexString: pattern.pattern.pattern.color).opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // Central icon
                Image(systemName: iconForPattern(pattern.pattern.pattern))
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Color(hexString: pattern.pattern.pattern.color))
                    .shadow(color: Color(hexString: pattern.pattern.pattern.color), radius: 10)
            }
            
            // Pattern label
            Text(pattern.pattern.pattern.rawValue)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(hexString: pattern.pattern.pattern.color).opacity(0.3))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(hexString: pattern.pattern.pattern.color).opacity(0.5), lineWidth: 1)
                        )
                )
            
            // Confidence indicator
            ConfidenceBar(confidence: pattern.pattern.confidence, color: Color(hexString: pattern.pattern.pattern.color))
        }
        .position(pattern.position)
        .scaleEffect(pattern.scale)
        .opacity(pattern.opacity)
        .onAppear {
            isAnimating = true
        }
    }
    
    private func iconForPattern(_ pattern: CognitivePattern) -> String {
        switch pattern {
        case .quoting: return "quote.bubble"
        case .reflecting: return "person.fill.questionmark"
        case .questioning: return "questionmark.circle"
        case .connecting: return "link"
        case .analyzing: return "chart.xyaxis.line"
        case .synthesizing: return "square.stack.3d.up"
        case .evaluating: return "checkmark.seal"
        case .creating: return "sparkles"
        }
    }
}

// MARK: - Confidence Bar
struct ConfidenceBar: View {
    let confidence: Float
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(color.opacity(0.2))
                
                // Fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(confidence))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: confidence)
            }
        }
        .frame(width: 80, height: 6)
    }
}

// MARK: - Particle System
class ParticleSystem: ObservableObject {
    struct Particle {
        var position: CGPoint
        var velocity: CGPoint
        var color: Color
        var size: CGFloat
        var life: Double
        var maxLife: Double
    }
    
    @Published var particles: [Particle] = []
    @Published var time: Double = 0
    private var timer: Timer?
    
    func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            self.update()
        }
    }
    
    func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
    
    func emitParticles(at position: CGPoint, color: Color, count: Int) {
        for _ in 0..<count {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 50...150)
            let velocity = CGPoint(
                x: cos(angle) * speed,
                y: sin(angle) * speed
            )
            
            let particle = Particle(
                position: position,
                velocity: velocity,
                color: color,
                size: CGFloat.random(in: 2...6),
                life: 1.0,
                maxLife: Double.random(in: 1.0...2.0)
            )
            
            particles.append(particle)
        }
    }
    
    private func update() {
        time += 0.016
        
        // Update particles
        particles = particles.compactMap { particle in
            var updated = particle
            
            // Apply physics
            updated.position.x += updated.velocity.x * 0.016
            updated.position.y += updated.velocity.y * 0.016
            
            // Apply gravity
            updated.velocity.y += 50 * 0.016
            
            // Apply drag
            updated.velocity.x *= 0.98
            updated.velocity.y *= 0.98
            
            // Update life
            updated.life -= 0.016 / updated.maxLife
            
            // Remove dead particles
            return updated.life > 0 ? updated : nil
        }
    }
    
    func draw(in context: GraphicsContext, size: CGSize) {
        for particle in particles {
            let opacity = particle.life
            
            context.fill(
                Circle().path(in: CGRect(
                    x: particle.position.x - particle.size / 2,
                    y: particle.position.y - particle.size / 2,
                    width: particle.size,
                    height: particle.size
                )),
                with: .color(particle.color.opacity(opacity))
            )
        }
    }
}

// MARK: - Real-time Pattern Display
struct RealTimePatternDisplay: View {
    @ObservedObject var recognizer = CognitivePatternRecognizer.shared
    @State private var currentPatterns: [PatternMatch] = []
    @State private var patternHistory: [PatternMatch] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Current pattern
            if let current = currentPatterns.first {
                HStack {
                    Image(systemName: iconForPattern(current.pattern))
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hexString: current.pattern.color))
                    
                    Text(current.pattern.rawValue)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // Confidence meter
                    CircularProgressView(progress: Double(current.confidence), accentColor: Color(hexString: current.pattern.color))
                        .frame(width: 40, height: 40)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hexString: current.pattern.color).opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color(hexString: current.pattern.color).opacity(0.3), lineWidth: 1)
                        )
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            
            // Pattern history
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(patternHistory.suffix(5), id: \.pattern.rawValue) { pattern in
                        PatternChip(pattern: pattern)
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPatterns)
    }
    
    private func iconForPattern(_ pattern: CognitivePattern) -> String {
        switch pattern {
        case .quoting: return "quote.bubble"
        case .reflecting: return "person.fill.questionmark"
        case .questioning: return "questionmark.circle"
        case .connecting: return "link"
        case .analyzing: return "chart.xyaxis.line"
        case .synthesizing: return "square.stack.3d.up"
        case .evaluating: return "checkmark.seal"
        case .creating: return "sparkles"
        }
    }
    
    func updateWithTranscript(_ text: String) {
        let patterns = recognizer.recognizePatterns(in: text)
        
        if !patterns.isEmpty {
            currentPatterns = patterns
            patternHistory.append(contentsOf: patterns)
            
            // Clear current after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                currentPatterns.removeAll()
            }
        }
    }
}

// MARK: - Pattern Chip
struct PatternChip: View {
    let pattern: PatternMatch
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hexString: pattern.pattern.color))
                .frame(width: 8, height: 8)
            
            Text(pattern.pattern.rawValue)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hexString: pattern.pattern.color).opacity(0.2))
                .overlay(
                    Capsule()
                        .strokeBorder(Color(hexString: pattern.pattern.color).opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}


// Color extension moved to Core/Extensions/Color+Hex.swift