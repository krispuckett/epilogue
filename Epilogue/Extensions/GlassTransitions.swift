import SwiftUI

// MARK: - Glass Effect Modifiers
struct GlassEffectModifier: ViewModifier {
    let phase: CommandPhase
    let intensity: Double
    
    enum CommandPhase {
        case collapsed
        case expanding
        case expanded
        case intent(CommandIntent)
    }
    
    func body(content: Content) -> some View {
        content
            .background(glassBackground)
            .overlay(glassOverlay)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                y: 4
            )
    }
    
    @ViewBuilder
    private var glassBackground: some View {
        switch phase {
        case .collapsed:
            Circle()
                .fill(.ultraThinMaterial)
        case .expanding:
            RoundedRectangle(cornerRadius: 40)
                .fill(.thinMaterial)
        case .expanded:
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
        case .intent(let intent):
            RoundedRectangle(cornerRadius: 24)
                .fill(intentMaterial(for: intent))
        }
    }
    
    @ViewBuilder
    private var glassOverlay: some View {
        switch phase {
        case .collapsed:
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        case .expanding, .expanded:
            RoundedRectangle(cornerRadius: phase == .expanding ? 40 : 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.1), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        case .intent(let intent):
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    intentGradient(for: intent),
                    lineWidth: 1
                )
        }
    }
    
    private var shadowColor: Color {
        switch phase {
        case .collapsed:
            return Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3)
        case .expanding:
            return Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2)
        case .expanded:
            return Color.black.opacity(0.2)
        case .intent(let intent):
            return intentColor(for: intent).opacity(0.3)
        }
    }
    
    private var shadowRadius: Double {
        switch phase {
        case .collapsed:
            return 12
        case .expanding:
            return 16
        case .expanded:
            return 20
        case .intent:
            return 24
        }
    }
    
    private func intentMaterial(for intent: CommandIntent) -> Material {
        switch intent {
        case .createQuote:
            return .thick
        case .createNote:
            return .regular
        case .addBook:
            return .thin
        case .searchLibrary:
            return .regular
        default:
            return .ultraThin
        }
    }
    
    private func intentGradient(for intent: CommandIntent) -> LinearGradient {
        let color = intentColor(for: intent)
        return LinearGradient(
            colors: [color, color.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func intentColor(for intent: CommandIntent) -> Color {
        switch intent {
        case .createQuote:
            return Color(red: 1.0, green: 0.55, blue: 0.26)
        case .createNote:
            return Color(red: 0.4, green: 0.6, blue: 0.9)
        case .addBook:
            return Color(red: 0.6, green: 0.4, blue: 0.8)
        case .searchLibrary:
            return Color(red: 0.3, green: 0.7, blue: 0.5)
        default:
            return .white.opacity(0.5)
        }
    }
}

// MARK: - Custom Transitions
extension AnyTransition {
    static var glassExpand: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: GlassExpandModifier(progress: 0),
                identity: GlassExpandModifier(progress: 1)
            ),
            removal: .modifier(
                active: GlassExpandModifier(progress: 0),
                identity: GlassExpandModifier(progress: 1)
            )
        )
    }
    
    static var glassCollapse: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: GlassCollapseModifier(progress: 1),
                identity: GlassCollapseModifier(progress: 0)
            ),
            removal: .modifier(
                active: GlassCollapseModifier(progress: 1),
                identity: GlassCollapseModifier(progress: 0)
            )
        )
    }
    
    static var glassShatter: AnyTransition {
        .modifier(
            active: GlassShatterModifier(shattered: true),
            identity: GlassShatterModifier(shattered: false)
        )
    }
}

// MARK: - Transition Modifiers
struct GlassExpandModifier: ViewModifier {
    let progress: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(0.1 + (0.9 * progress))
            .opacity(progress)
            .blur(radius: (1 - progress) * 20)
            .rotation3DEffect(
                .degrees((1 - progress) * 180),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
    }
}

struct GlassCollapseModifier: ViewModifier {
    let progress: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(1 - (0.9 * progress))
            .opacity(1 - progress)
            .blur(radius: progress * 10)
            .rotation3DEffect(
                .degrees(progress * 90),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
    }
}

struct GlassShatterModifier: ViewModifier {
    let shattered: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(shattered ? 1.2 : 1.0)
            .opacity(shattered ? 0 : 1)
            .blur(radius: shattered ? 10 : 0)
            .overlay {
                if shattered {
                    // Shatter effect overlay
                    ZStack {
                        ForEach(0..<8, id: \.self) { index in
                            GlassShardView(index: index)
                        }
                    }
                }
            }
    }
}

// MARK: - Supporting Views
struct GlassShardView: View {
    let index: Int
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.ultraThinMaterial)
            .frame(width: 40, height: 60)
            .offset(offset)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    let angle = Double(index) * (360.0 / 8.0)
                    let distance = 150.0
                    offset = CGSize(
                        width: cos(angle * .pi / 180) * distance,
                        height: sin(angle * .pi / 180) * distance
                    )
                    rotation = Double.random(in: -180...180)
                    opacity = 0
                }
            }
    }
}

// MARK: - Gesture Modifiers
struct GlassDistortionModifier: ViewModifier {
    let dragAmount: CGSize
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(
                x: 1 + (abs(dragAmount.width) / 500),
                y: 1 - (dragAmount.height / 300)
            )
            .rotation3DEffect(
                .degrees(Double(dragAmount.width / 10)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
    }
}