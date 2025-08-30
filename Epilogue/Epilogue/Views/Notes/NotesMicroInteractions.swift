import SwiftUI

// MARK: - Notes Micro Interactions
struct NotesMicroInteractions {
    
    // MARK: - Parallax Effect
    struct ParallaxModifier: ViewModifier {
        let offset: CGFloat
        let sensitivity: CGFloat
        
        func body(content: Content) -> some View {
            content
                .offset(y: offset * sensitivity)
        }
    }
    
    // MARK: - Breathing Animation
    struct BreathingModifier: ViewModifier {
        @State private var scale: CGFloat = 1.0
        @State private var opacity: Double = 1.0
        let duration: Double
        
        func body(content: Content) -> some View {
            content
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                        scale = 1.02
                        opacity = 0.95
                    }
                }
        }
    }
    
    // MARK: - Hero Card Animation
    struct HeroCardModifier: ViewModifier {
        @State private var appeared = false
        let delay: Double
        
        func body(content: Content) -> some View {
            content
                .scaleEffect(appeared ? 1.0 : 0.9)
                .opacity(appeared ? 1.0 : 0)
                .rotation3DEffect(
                    .degrees(appeared ? 0 : 10),
                    axis: (x: 1, y: 0, z: 0)
                )
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                        appeared = true
                    }
                }
        }
    }
    
    // MARK: - Hover Effect
    struct HoverEffectModifier: ViewModifier {
        @State private var isHovered = false
        
        func body(content: Content) -> some View {
            content
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .shadow(
                    color: DesignSystem.Colors.primaryAccent.opacity(isHovered ? 0.2 : 0),
                    radius: isHovered ? 20 : 10,
                    y: isHovered ? 5 : 2
                )
                .animation(DesignSystem.Animation.springStandard, value: isHovered)
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
    
    // MARK: - Stagger Animation
    struct StaggeredAppearModifier: ViewModifier {
        let index: Int
        @State private var appeared = false
        
        private var delay: Double {
            Double(index) * 0.05
        }
        
        func body(content: Content) -> some View {
            content
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                        appeared = true
                    }
                }
        }
    }
    
    // MARK: - Section Header Sticky Effect
    struct StickyHeaderModifier: ViewModifier {
        @State private var offset: CGFloat = 0
        
        func body(content: Content) -> some View {
            GeometryReader { geometry in
                content
                    .offset(y: min(0, -offset))
                    .opacity(1.0 - min(0.3, abs(offset / 100)))
                    .blur(radius: min(3, abs(offset / 50)))
                    .onChange(of: geometry.frame(in: .global).minY) { _, newValue in
                        offset = -newValue
                    }
            }
        }
    }
    
    // MARK: - Pull to Refresh Indicator
    struct PullToRefreshIndicator: View {
        let progress: CGFloat
        @State private var rotation: Double = 0
        
        var body: some View {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 30, height: 30)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primaryAccent,
                                Color(red: 1.0, green: 0.45, blue: 0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(rotation))
                
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .scaleEffect(progress)
                    .opacity(Double(progress))
            }
            .onChange(of: progress) { _, _ in
                if progress >= 1.0 {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                } else {
                    rotation = 0
                }
            }
        }
    }
    
    // MARK: - Save Pulse Animation
    struct SavePulseModifier: ViewModifier {
        @Binding var trigger: Bool
        
        func body(content: Content) -> some View {
            ZStack {
                if trigger {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .scaleEffect(trigger ? 1.5 : 1.0)
                        .opacity(trigger ? 0 : 1)
                        .animation(.easeOut(duration: 0.5), value: trigger)
                }
                
                content
                    .scaleEffect(trigger ? 1.1 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: trigger)
            }
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        trigger = false
                    }
                }
            }
        }
    }
    
    // MARK: - Ripple Effect
    struct RippleEffectModifier: ViewModifier {
        @State private var ripples: [RippleData] = []
        
        struct RippleData: Identifiable {
            let id = UUID()
            let position: CGPoint
            let startTime: Date
        }
        
        func body(content: Content) -> some View {
            content
                .overlay(
                    GeometryReader { geometry in
                        ZStack {
                            ForEach(ripples) { ripple in
                                RippleView(data: ripple)
                            }
                        }
                    }
                    .allowsHitTesting(false)
                )
                .onTapGesture { location in
                    let newRipple = RippleData(position: location, startTime: Date())
                    ripples.append(newRipple)
                    
                    // Remove after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        ripples.removeAll { $0.id == newRipple.id }
                    }
                }
        }
    }
    
    struct RippleView: View {
        let data: RippleEffectModifier.RippleData
        @State private var scale: CGFloat = 0.5
        @State private var opacity: Double = 0.6
        
        var body: some View {
            Circle()
                .fill(DesignSystem.Colors.primaryAccent)
                .frame(width: 50, height: 50)
                .scaleEffect(scale)
                .opacity(opacity)
                .position(data.position)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.8)) {
                        scale = 3
                        opacity = 0
                    }
                }
        }
    }
    
    // MARK: - Shake to Shuffle
    struct ShakeDetector: ViewModifier {
        let onShake: () -> Void
        @State private var lastShakeTime = Date()
        
        func body(content: Content) -> some View {
            content
                .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                    let now = Date()
                    if now.timeIntervalSince(lastShakeTime) > 2 {
                        onShake()
                        lastShakeTime = now
                        DesignSystem.HapticFeedback.success()
                    }
                }
        }
    }
    
    // MARK: - Connection Lines
    struct ConnectionLinesView: View {
        let connections: [UUID: Set<UUID>]
        let notePositions: [UUID: CGPoint]
        
        var body: some View {
            Canvas { context, size in
                for (noteId, connectedIds) in connections {
                    guard let startPos = notePositions[noteId] else { continue }
                    
                    for connectedId in connectedIds {
                        guard let endPos = notePositions[connectedId] else { continue }
                        
                        let path = Path { p in
                            p.move(to: startPos)
                            
                            // Create a curved connection
                            let controlPoint1 = CGPoint(
                                x: startPos.x + (endPos.x - startPos.x) * 0.5,
                                y: startPos.y
                            )
                            let controlPoint2 = CGPoint(
                                x: startPos.x + (endPos.x - startPos.x) * 0.5,
                                y: endPos.y
                            )
                            
                            p.addCurve(to: endPos, control1: controlPoint1, control2: controlPoint2)
                        }
                        
                        context.stroke(
                            path,
                            with: .linearGradient(
                                Gradient(colors: [
                                    DesignSystem.Colors.primaryAccent.opacity(0.3),
                                    DesignSystem.Colors.primaryAccent.opacity(0.1)
                                ]),
                                startPoint: startPos,
                                endPoint: endPos
                            ),
                            lineWidth: 1
                        )
                    }
                }
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func parallax(offset: CGFloat, sensitivity: CGFloat = 0.1) -> some View {
        modifier(NotesMicroInteractions.ParallaxModifier(offset: offset, sensitivity: sensitivity))
    }
    
    func breathing(duration: Double = 4) -> some View {
        modifier(NotesMicroInteractions.BreathingModifier(duration: duration))
    }
    
    func heroCard(delay: Double = 0) -> some View {
        modifier(NotesMicroInteractions.HeroCardModifier(delay: delay))
    }
    
    func hoverEffect() -> some View {
        modifier(NotesMicroInteractions.HoverEffectModifier())
    }
    
    func staggeredAppear(index: Int) -> some View {
        modifier(NotesMicroInteractions.StaggeredAppearModifier(index: index))
    }
    
    func stickyHeader() -> some View {
        modifier(NotesMicroInteractions.StickyHeaderModifier())
    }
    
    func savePulse(trigger: Binding<Bool>) -> some View {
        modifier(NotesMicroInteractions.SavePulseModifier(trigger: trigger))
    }
    
    func rippleEffect() -> some View {
        modifier(NotesMicroInteractions.RippleEffectModifier())
    }
    
    func shakeDetector(onShake: @escaping () -> Void) -> some View {
        modifier(NotesMicroInteractions.ShakeDetector(onShake: onShake))
    }
}

// MARK: - Helper Extensions
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Device Shake Detection
extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}