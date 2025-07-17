import SwiftUI
import Metal

// MARK: - Ambient Literary Background
struct AmbientLiteraryBackground: View {
    @State private var animationPhase: Double = 0
    @State private var particlePhase: Double = 0
    @State private var isAnimating = false
    let bookContext: Book?
    
    var body: some View {
        TimelineView(.animation) { timeline in
            ZStack {
                // Base warm gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.13, green: 0.12, blue: 0.11), // Slightly warmer dark
                        Color(red: 0.09, green: 0.085, blue: 0.082) // Deep charcoal
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Warm light rays
                ForEach(0..<3) { index in
                    LightRay(
                        phase: timeline.date.timeIntervalSince1970 * 0.5,
                        index: index,
                        color: Color(red: 1.0, green: 0.55, blue: 0.26)
                    )
                }
                
                // Floating dust particles
                FloatingParticles(phase: timeline.date.timeIntervalSince1970 * 0.8)
                    .opacity(isAnimating ? 1 : 0)
                
                // Subtle book spine silhouettes
                BookSpineSilhouettes(phase: timeline.date.timeIntervalSince1970 * 0.3)
            }
            .onAppear {
                withAnimation(.easeIn(duration: 2)) {
                    isAnimating = true
                }
            }
        }
    }
}

// MARK: - Light Ray Component
struct LightRay: View {
    let phase: Double
    let index: Int
    let color: Color
    
    private var offset: Double {
        sin(phase + Double(index) * 1.5) * 50
    }
    
    private var rotation: Double {
        15 + sin(phase * 0.5 + Double(index)) * 10
    }
    
    private var opacity: Double {
        0.3 + sin(phase * 0.7 + Double(index) * 2) * 0.2
    }
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.clear, location: 0),
                .init(color: color.opacity(opacity), location: 0.3),
                .init(color: color.opacity(opacity * 0.5), location: 0.7),
                .init(color: Color.clear, location: 1)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 200, height: 800)
        .rotationEffect(.degrees(rotation))
        .offset(x: offset)
        .blur(radius: 20)
    }
}

// MARK: - Floating Particles
struct FloatingParticles: View {
    let phase: Double
    let particleCount = 20
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<particleCount, id: \.self) { index in
                DustParticle(
                    phase: phase,
                    index: index,
                    screenSize: geometry.size
                )
            }
        }
    }
}

// MARK: - Individual Dust Particle
struct DustParticle: View {
    let phase: Double
    let index: Int
    let screenSize: CGSize
    
    private var position: CGPoint {
        let baseX = CGFloat(index) / CGFloat(20) * screenSize.width
        let baseY = CGFloat(index * 7 % 20) / CGFloat(20) * screenSize.height
        
        let x = baseX + sin(phase + Double(index) * 0.5) * 30
        let y = baseY - abs(sin(phase * 0.3 + Double(index))) * screenSize.height * 0.5
        
        return CGPoint(
            x: x,
            y: y.truncatingRemainder(dividingBy: screenSize.height)
        )
    }
    
    private var opacity: Double {
        0.7 + sin(phase * 0.5 + Double(index) * 0.3) * 0.3
    }
    
    private var size: CGFloat {
        2 + sin(phase + Double(index)) * 1
    }
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1.0, green: 0.7, blue: 0.4).opacity(opacity),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 5
                )
            )
            .frame(width: size, height: size)
            .position(position)
            .blur(radius: 1)
    }
}

// MARK: - Book Spine Silhouettes
struct BookSpineSilhouettes: View {
    let phase: Double
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<8) { index in
                BookSpine(
                    height: 150 + sin(phase + Double(index)) * 20,
                    width: 15 + Double(index % 3) * 5,
                    opacity: 0.1 + sin(phase * 0.3 + Double(index)) * 0.05
                )
            }
        }
        .rotationEffect(.degrees(-5))
        .offset(x: -100, y: 300)
        .blur(radius: 3)
    }
}

// MARK: - Individual Book Spine
struct BookSpine: View {
    let height: Double
    let width: Double
    let opacity: Double
    
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(opacity))
            .frame(width: width, height: height)
    }
}

// MARK: - Book Icon Animation
struct AnimatedBookIcon: View {
    let breathingScale: Double
    let glowOpacity: Double
    let floatingOffset: CGFloat
    let pageRotation: Double
    
    var body: some View {
        ZStack {
            // Warm glow
            WarmGlowCircle(opacity: glowOpacity, offset: floatingOffset)
            
            // Floating pages
            FloatingPages(rotation: pageRotation)
            
            // Main icon
            BookIcon(scale: breathingScale, offset: floatingOffset)
        }
    }
}

// MARK: - Warm Glow Circle
struct WarmGlowCircle: View {
    let opacity: Double
    let offset: CGFloat
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.55, blue: 0.26).opacity(opacity * 0.5),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 80
                )
            )
            .frame(width: 200, height: 200)
            .blur(radius: 50)
            .offset(y: offset)
    }
}

// MARK: - Floating Pages
struct FloatingPages: View {
    let rotation: Double
    
    var body: some View {
        ForEach(0..<3) { i in
            FloatingPage(index: i, baseRotation: rotation)
        }
    }
}

// MARK: - Single Floating Page
struct FloatingPage: View {
    let index: Int
    let baseRotation: Double
    
    private var rotation: Double {
        baseRotation + Double(index) * 120
    }
    
    private var xOffset: CGFloat {
        cos(rotation * .pi / 180) * 60
    }
    
    private var yOffset: CGFloat {
        sin(rotation * .pi / 180) * 40 - 10
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.02),
                        Color.white.opacity(0.01)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 30, height: 40)
            .blur(radius: 1)
            .rotationEffect(.degrees(Double(index) * 15 - 15), anchor: .center)
            .offset(x: xOffset, y: yOffset)
            .opacity(0.5 + sin(baseRotation * .pi / 180 + Double(index)) * 0.3)
    }
}

// MARK: - Book Icon
struct BookIcon: View {
    let scale: Double
    let offset: CGFloat
    
    var body: some View {
        Image(systemName: "books.vertical.fill")
            .font(.system(size: 80, weight: .light))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.55, blue: 0.26),
                        Color(red: 0.9, green: 0.45, blue: 0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .scaleEffect(scale)
            .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), radius: 20)
            .offset(y: offset)
    }
}

// MARK: - Literary Companion Empty State
struct LiteraryCompanionEmptyState: View {
    @State private var titleOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Beautiful silk background
            CalmLiteraryBackground()
                .ignoresSafeArea()
            
            // Centered, focused content
            VStack(spacing: 0) {
                Spacer()
                
                // App icon
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 32)
                    .opacity(titleOpacity)
                
                // Main heading
                Text("Chat with Epilogue")
                    .font(.system(size: 36, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.95))
                    .opacity(titleOpacity)
                
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            // Simple fade in
            withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
                titleOpacity = 1.0
            }
        }
    }
}

// MARK: - Conversation Prompt Component
struct ConversationPrompt: View {
    let text: String
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            // Handle prompt tap
        }) {
            HStack {
                Text(text)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.white.opacity(0.4))
                    .opacity(isHovered ? 1 : 0.6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Alternative Minimal Version
struct MinimalLiteraryEmptyState: View {
    var body: some View {
        ZStack {
            CalmLiteraryBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Single focused message
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Text("What are you reading?")
                        .font(.system(size: 28, weight: .light, design: .serif))
                        .foregroundStyle(.white.opacity(0.9))
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Empty State Background
struct EmptyStateBackground: View {
    var body: some View {
        ZStack {
            // Ambient background
            AmbientLiteraryBackground(bookContext: nil)
                .ignoresSafeArea()
            
            // Vignette
            VignetteOverlay()
        }
    }
}

// MARK: - Vignette Overlay
struct VignetteOverlay: View {
    var body: some View {
        RadialGradient(
            colors: [
                Color.clear,
                Color.black.opacity(0.4)
            ],
            center: .center,
            startRadius: 200,
            endRadius: 500
        )
        .ignoresSafeArea()
    }
}

// MARK: - Empty State Content
struct EmptyStateContent: View {
    let breathingScale: Double
    let glowOpacity: Double
    let floatingOffset: CGFloat
    let pageRotation: Double
    
    var body: some View {
        VStack(spacing: 40) {
            // Animated icon
            AnimatedBookIcon(
                breathingScale: breathingScale,
                glowOpacity: glowOpacity,
                floatingOffset: floatingOffset,
                pageRotation: pageRotation
            )
            
            // Text content
            EmptyStateText()
            
            // Floating quotes
            FloatingQuotesRow()
                .padding(.top, 40)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Empty State Text
struct EmptyStateText: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Your Literary Companion")
                .font(.custom("Georgia", size: 32))
                .fontWeight(.light)
                .foregroundStyle(.white.opacity(0.95))
            
            Text("Discuss books, explore themes, and deepen your understanding")
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(4)
        }
    }
}

// MARK: - Floating Quotes Row
struct FloatingQuotesRow: View {
    var body: some View {
        HStack(spacing: 20) {
            FloatingQuote(text: "\"The only way out is through\"", delay: 0)
            FloatingQuote(text: "\"Stories are light\"", delay: 2)
            FloatingQuote(text: "\"Read, reflect, remember\"", delay: 4)
        }
    }
}

// MARK: - Floating Quote
struct FloatingQuote: View {
    let text: String
    let delay: Double
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 20
    
    var body: some View {
        Text(text)
            .font(.custom("Georgia-Italic", size: 13))
            .foregroundStyle(.white.opacity(opacity * 0.3))
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 3).delay(delay).repeatForever(autoreverses: true)) {
                    opacity = 0.8
                    offset = -15
                }
            }
    }
}

// MARK: - Preview
struct AmbientLiteraryBackground_Previews: PreviewProvider {
    static var previews: some View {
        LiteraryCompanionEmptyState()
            .preferredColorScheme(.dark)
    }
}