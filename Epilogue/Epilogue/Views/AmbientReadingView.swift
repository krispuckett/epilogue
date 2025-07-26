import SwiftUI
import Combine

struct AmbientReadingView: View {
    @StateObject private var intelligence = AmbientIntelligence()
    @State private var showOrb = true
    @State private var orbPosition = CGPoint(x: 350, y: 600) // Will be updated in onAppear
    @State private var isDraggingOrb = false
    @State private var showResponse = false
    @State private var currentResponse: IntelligenceResponse?
    @State private var visualEffect: VisualHint?
    @State private var screenSize: CGSize = .zero
    
    // Demo content
    @State private var bookTitle = "The Nature of Reality"
    @State private var chapterTitle = "Chapter 3: Quantum Consciousness"
    @State private var demoText = """
    The human mind, in its quest to understand consciousness, has often turned to quantum mechanics for answers. The mysterious behavior of particles at the quantum level—existing in multiple states simultaneously until observed—mirrors the enigmatic nature of conscious experience itself.
    
    Consider the famous double-slit experiment: when unobserved, particles behave as waves, passing through both slits simultaneously. Yet the moment we attempt to measure which slit the particle passes through, the wave function collapses, and the particle behaves as a discrete entity. This phenomenon has led some theorists to propose that consciousness itself plays a fundamental role in the collapse of quantum states.
    
    But what does this mean for our understanding of free will? If consciousness can influence quantum events, does this provide the indeterminacy needed for genuine choice? Or are we merely sophisticated biological machines, our sense of agency an elaborate illusion crafted by evolution?
    
    The implications extend beyond philosophy into the very fabric of reality. Some interpretations of quantum mechanics suggest that all possible outcomes exist in parallel universes, with consciousness selecting which reality we experience. This many-worlds interpretation transforms every decision into a branching point where all possibilities are realized—somewhere.
    """
    
    var body: some View {
        ZStack {
            // Main reading interface
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Book header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(bookTitle)
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(.primary)
                        
                        Text(chapterTitle)
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 40)
                    
                    // Reading content
                    Text(demoText)
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .lineSpacing(8)
                        .foregroundStyle(.primary)
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                }
            }
            .background(Color(UIColor.systemBackground))
            
            // Visual effects layer
            if let effect = visualEffect {
                VisualEffectLayer(hint: effect)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            
            // Response card
            if showResponse, let response = currentResponse {
                VStack {
                    Spacer()
                    
                    ResponseCard(response: response) {
                        withAnimation(.spring()) {
                            showResponse = false
                        }
                    }
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Floating orb
            if showOrb {
                AmbientOrbView()
                    .position(orbPosition)
                    .scaleEffect(isDraggingOrb ? 1.2 : 1.0)
                    .animation(.spring(), value: isDraggingOrb)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingOrb = true
                                orbPosition = value.location
                            }
                            .onEnded { _ in
                                isDraggingOrb = false
                                // Snap to edges
                                withAnimation(.spring()) {
                                    let midX = screenSize.width / 2
                                    
                                    if orbPosition.x < midX {
                                        orbPosition.x = 80
                                    } else {
                                        orbPosition.x = screenSize.width - 80
                                    }
                                }
                            }
                    )
            }
            
            // Status indicator
            if intelligence.isActive {
                VStack {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("Ambient intelligence active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            setupIntelligence()
            setupNotifications()
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        screenSize = geometry.size
                        orbPosition = CGPoint(x: geometry.size.width - 80, y: geometry.size.height - 200)
                    }
            }
        )
    }
    
    private func setupIntelligence() {
        // Set up the reading context
        let context = ReadingContext(
            currentBook: bookTitle,
            currentChapter: chapterTitle,
            genre: "Philosophy"
        )
        
        intelligence.updateContext(
            book: bookTitle,
            chapter: chapterTitle,
            genre: "Philosophy"
        )
    }
    
    private func setupNotifications() {
        // Listen for intelligence responses
        NotificationCenter.default.publisher(for: Notification.Name("IntelligenceResponseReady"))
            .compactMap { $0.object as? IntelligenceResponse }
            .sink { response in
                currentResponse = response
                withAnimation(.spring()) {
                    showResponse = true
                }
                
                // Auto-hide after 10 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    if currentResponse?.reaction.timestamp == response.reaction.timestamp {
                        withAnimation(.spring()) {
                            showResponse = false
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for visual feedback
        NotificationCenter.default.publisher(for: Notification.Name("VisualFeedbackRequested"))
            .compactMap { $0.object as? VisualHint }
            .sink { hint in
                withAnimation(.easeInOut(duration: 0.3)) {
                    visualEffect = hint
                }
                
                // Clear effect after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        visualEffect = nil
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}

// MARK: - Response Card
struct ResponseCard: View {
    let response: IntelligenceResponse
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: iconForAction(response.action))
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: response.reaction.type.color))
                
                Text(response.reaction.type.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(response.suggestion)
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 16) {
                Button("Yes, please") {
                    // Handle acceptance
                    HapticManager.shared.lightTap()
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Not now") {
                    HapticManager.shared.lightTap()
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: Color(hex: response.reaction.type.color).opacity(0.3), radius: 20)
        )
    }
    
    private func iconForAction(_ action: IntelligenceAction) -> String {
        switch action {
        case .offer:
            return "questionmark.circle"
        case .search:
            return "magnifyingglass"
        case .explain:
            return "book"
        case .connect:
            return "link"
        case .clarify:
            return "lightbulb"
        case .expand:
            return "arrow.up.right.square"
        case .wait:
            return "ellipsis.circle"
        }
    }
}

// MARK: - Visual Effect Layer
struct VisualEffectLayer: View {
    let hint: VisualHint
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch hint.animation {
                case .pulse:
                    PulseEffect(color: Color(hex: hint.color), intensity: hint.intensity)
                case .ripple:
                    RippleEffect(color: Color(hex: hint.color), intensity: hint.intensity)
                case .sparkle:
                    SparkleEffect(color: Color(hex: hint.color), intensity: hint.intensity)
                case .glow:
                    GlowEffect(color: Color(hex: hint.color), intensity: hint.intensity)
                case .swirl:
                    SwirlEffect(color: Color(hex: hint.color), intensity: hint.intensity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

// Visual effects implementations
struct PulseEffect: View {
    let color: Color
    let intensity: Float
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        Circle()
            .fill(color.opacity(Double(intensity) * 0.3))
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5)) {
                    scale = 2.0
                }
            }
    }
}

struct RippleEffect: View {
    let color: Color
    let intensity: Float
    
    var body: some View {
        ForEach(0..<3) { index in
            Circle()
                .stroke(color.opacity(Double(intensity) * 0.3), lineWidth: 2)
                .scaleEffect(1 + CGFloat(index) * 0.5)
                .opacity(1 - Double(index) * 0.3)
        }
    }
}

struct SparkleEffect: View {
    let color: Color
    let intensity: Float
    
    var body: some View {
        // Simple sparkle placeholder
        Image(systemName: "sparkles")
            .font(.system(size: 100))
            .foregroundStyle(color.opacity(Double(intensity)))
    }
}

struct GlowEffect: View {
    let color: Color
    let intensity: Float
    
    var body: some View {
        Rectangle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(Double(intensity) * 0.3),
                        color.opacity(0)
                    ],
                    center: .center,
                    startRadius: 50,
                    endRadius: 200
                )
            )
    }
}

struct SwirlEffect: View {
    let color: Color
    let intensity: Float
    @State private var rotation: Double = 0
    
    var body: some View {
        Image(systemName: "tornado")
            .font(.system(size: 100))
            .foregroundStyle(color.opacity(Double(intensity)))
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}


struct AmbientReadingView_Previews: PreviewProvider {
    static var previews: some View {
        AmbientReadingView()
    }
}