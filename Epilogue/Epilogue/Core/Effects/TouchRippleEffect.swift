import SwiftUI
import Combine

// MARK: - Ripple Data Model

/// Represents a single ripple emanating from a touch point
struct TouchRipple: Identifiable {
    let id = UUID()
    let position: CGPoint
    let birthTime: Date
    let intensity: CGFloat

    var age: TimeInterval {
        Date().timeIntervalSince(birthTime)
    }
}

// MARK: - Ripple State Manager

/// Manages active ripples with automatic cleanup
@Observable
final class RippleStateManager {
    private(set) var ripples: [TouchRipple] = []
    private var cleanupTimer: Timer?

    /// Maximum simultaneous ripples (shader supports 3)
    let maxRipples = 3

    /// How long ripples live before removal
    let rippleLifetime: TimeInterval = 2.0

    init() {
        startCleanupTimer()
    }

    deinit {
        cleanupTimer?.invalidate()
    }

    /// Add a new ripple at the specified position
    func addRipple(at position: CGPoint, intensity: CGFloat = 1.0) {
        let ripple = TouchRipple(
            position: position,
            birthTime: Date(),
            intensity: min(1.0, max(0.0, intensity))
        )

        // Remove oldest if at capacity
        if ripples.count >= maxRipples {
            ripples.removeFirst()
        }

        ripples.append(ripple)
    }

    /// Remove expired ripples
    func cleanup() {
        ripples.removeAll { $0.age >= rippleLifetime }
    }

    /// Clear all ripples immediately
    func clearAll() {
        ripples.removeAll()
    }

    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.cleanup()
        }
    }
}

// MARK: - Touch Ripple View Modifier

/// Applies interactive touch ripple distortion effect to any view
struct TouchRippleModifier: ViewModifier {
    @State private var rippleManager = RippleStateManager()
    @State private var currentTime: Date = .now

    let isEnabled: Bool
    let waveSpeed: CGFloat
    let waveFrequency: CGFloat
    let maxAmplitude: CGFloat
    let lifetime: CGFloat

    private let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content
            .onReceive(timer) { _ in
                currentTime = .now
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard isEnabled else { return }
                        rippleManager.addRipple(at: value.location)
                    }
            )
            .distortionEffect(
                ShaderLibrary.touch_ripple_distortion(
                    .float(currentTime.timeIntervalSinceReferenceDate),
                    // Ripple 1
                    .float2(ripplePosition(at: 0)),
                    .float(rippleBirthTime(at: 0)),
                    .float(rippleIntensity(at: 0)),
                    // Ripple 2
                    .float2(ripplePosition(at: 1)),
                    .float(rippleBirthTime(at: 1)),
                    .float(rippleIntensity(at: 1)),
                    // Ripple 3
                    .float2(ripplePosition(at: 2)),
                    .float(rippleBirthTime(at: 2)),
                    .float(rippleIntensity(at: 2)),
                    // Global parameters
                    .float(waveSpeed),
                    .float(waveFrequency),
                    .float(maxAmplitude),
                    .float(lifetime)
                ),
                maxSampleOffset: CGSize(width: 60, height: 60)
            )
    }

    private func ripplePosition(at index: Int) -> CGPoint {
        guard index < rippleManager.ripples.count else {
            return .zero
        }
        return rippleManager.ripples[index].position
    }

    private func rippleBirthTime(at index: Int) -> CGFloat {
        guard index < rippleManager.ripples.count else {
            return -1000 // Far in the past = inactive
        }
        return rippleManager.ripples[index].birthTime.timeIntervalSinceReferenceDate
    }

    private func rippleIntensity(at index: Int) -> CGFloat {
        guard index < rippleManager.ripples.count else {
            return 0
        }
        return rippleManager.ripples[index].intensity
    }
}

// MARK: - Simple Single-Touch Ripple Modifier

/// Simplified modifier for single ripple scenarios
struct SingleTouchRippleModifier: ViewModifier {
    @State private var touchPosition: CGPoint = .zero
    @State private var touchTime: Date = .distantPast
    @State private var currentTime: Date = .now
    @State private var isActive = false

    let isEnabled: Bool
    let intensity: CGFloat
    let speed: CGFloat
    let frequency: CGFloat

    private let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content
            .onReceive(timer) { _ in
                currentTime = .now
                // Deactivate after 2 seconds
                if isActive && currentTime.timeIntervalSince(touchTime) > 2.0 {
                    isActive = false
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard isEnabled else { return }
                        touchPosition = value.location
                        touchTime = .now
                        isActive = true
                    }
            )
            .distortionEffect(
                ShaderLibrary.single_touch_ripple_distortion(
                    .float2(touchPosition),
                    .float(isActive ? currentTime.timeIntervalSince(touchTime) : -1),
                    .float(isActive ? intensity : 0),
                    .float(speed),
                    .float(frequency),
                    .float(25) // amplitude
                ),
                maxSampleOffset: CGSize(width: 40, height: 40)
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Adds multi-touch ripple distortion effect
    /// - Parameters:
    ///   - isEnabled: Whether the effect responds to touches
    ///   - waveSpeed: Speed of wave propagation (default: 1.0)
    ///   - waveFrequency: Frequency of ripple waves (default: 1.0)
    ///   - maxAmplitude: Maximum pixel displacement (default: 20)
    ///   - lifetime: How long ripples last in seconds (default: 2.0)
    func touchRippleEffect(
        isEnabled: Bool = true,
        waveSpeed: CGFloat = 1.0,
        waveFrequency: CGFloat = 1.0,
        maxAmplitude: CGFloat = 20,
        lifetime: CGFloat = 2.0
    ) -> some View {
        modifier(TouchRippleModifier(
            isEnabled: isEnabled,
            waveSpeed: waveSpeed,
            waveFrequency: waveFrequency,
            maxAmplitude: maxAmplitude,
            lifetime: lifetime
        ))
    }

    /// Adds simple single-touch ripple effect
    /// - Parameters:
    ///   - isEnabled: Whether the effect responds to touches
    ///   - intensity: Strength of the ripple (0-1, default: 1.0)
    ///   - speed: Wave propagation speed (default: 1.0)
    ///   - frequency: Wave frequency (default: 1.0)
    func singleTouchRipple(
        isEnabled: Bool = true,
        intensity: CGFloat = 1.0,
        speed: CGFloat = 1.0,
        frequency: CGFloat = 1.0
    ) -> some View {
        modifier(SingleTouchRippleModifier(
            isEnabled: isEnabled,
            intensity: intensity,
            speed: speed,
            frequency: frequency
        ))
    }
}

// MARK: - Preview

#Preview("Touch Ripple Effect") {
    ZStack {
        // Sample gradient to show effect
        LinearGradient(
            colors: [.purple, .blue, .cyan, .mint],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .touchRippleEffect()

        Text("Tap anywhere")
            .font(.title2)
            .foregroundStyle(.white)
            .allowsHitTesting(false)
    }
    .ignoresSafeArea()
}

#Preview("Single Touch Ripple") {
    ZStack {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, 0.5], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: [
                .indigo, .purple, .pink,
                .blue, .cyan, .mint,
                .teal, .green, .yellow
            ]
        )
        .singleTouchRipple(intensity: 0.8, speed: 1.2)

        Text("Tap for ripple")
            .font(.headline)
            .foregroundStyle(.white)
            .allowsHitTesting(false)
    }
    .ignoresSafeArea()
}
