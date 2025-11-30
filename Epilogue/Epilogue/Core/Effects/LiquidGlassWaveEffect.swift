import SwiftUI
import Combine

// MARK: - Touch State for Liquid Glass

/// Tracks a single touch point for liquid glass effect
struct LiquidGlassTouch: Identifiable {
    let id = UUID()
    var origin: CGPoint
    var startTime: TimeInterval
    var isActive: Bool

    init(origin: CGPoint, startTime: TimeInterval) {
        self.origin = origin
        self.startTime = startTime
        self.isActive = true
    }
}

// MARK: - Liquid Glass State Manager

/// Manages touch state and animation timing for liquid glass effect
@Observable
final class LiquidGlassState {
    private(set) var touches: [LiquidGlassTouch] = []
    private(set) var elapsedTime: TimeInterval = 0
    private var startTime: Date?
    private var displayLink: CADisplayLink?

    let maxTouches = 3

    init() {}

    func startAnimation() {
        guard displayLink == nil else { return }
        startTime = Date()
        elapsedTime = 0

        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func update() {
        guard let start = startTime else { return }
        elapsedTime = Date().timeIntervalSince(start)

        // Clean up old inactive touches (after 4 seconds)
        touches.removeAll { !$0.isActive && (elapsedTime - $0.startTime) > 4.0 }
    }

    func addTouch(at point: CGPoint) {
        // Remove oldest if at capacity
        if touches.count >= maxTouches {
            if let oldestIndex = touches.firstIndex(where: { !$0.isActive }) {
                touches.remove(at: oldestIndex)
            } else {
                touches.removeFirst()
            }
        }

        touches.append(LiquidGlassTouch(origin: point, startTime: elapsedTime))
    }

    func updateTouch(id: UUID, to point: CGPoint) {
        if let index = touches.firstIndex(where: { $0.id == id }) {
            touches[index].origin = point
        }
    }

    func endTouch(id: UUID) {
        if let index = touches.firstIndex(where: { $0.id == id }) {
            touches[index].isActive = false
        }
    }

    func endAllTouches() {
        for i in touches.indices {
            touches[i].isActive = false
        }
    }

    deinit {
        stopAnimation()
    }
}

// MARK: - Single Touch Liquid Glass Modifier

/// Applies liquid glass wave effect with single touch support
struct LiquidGlassWaveModifier: ViewModifier {
    @State private var touchOrigin: CGPoint = .zero
    @State private var touchStartTime: TimeInterval = 0
    @State private var currentTime: TimeInterval = 0
    @State private var isAnimating: Bool = false
    @State private var viewSize: CGSize = .zero

    let waveSpeed: CGFloat
    let displacementAmount: CGFloat
    let refractionStrength: CGFloat
    let noiseScale: CGFloat
    let isEnabled: Bool

    private let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                Color.clear.onAppear { viewSize = geo.size }
                    .onChange(of: geo.size) { _, new in viewSize = new }
            })
            .onReceive(timer) { _ in
                if isAnimating {
                    currentTime += 1/60
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        if !isAnimating {
                            // New touch - reset everything
                            touchOrigin = value.location
                            touchStartTime = currentTime
                            currentTime = 0 // Reset time for new ripple
                            isAnimating = true
                        } else {
                            // Update touch position while dragging
                            touchOrigin = value.location
                        }
                    }
                    .onEnded { _ in
                        // Keep animating after touch ends (ripple continues)
                        // It will auto-stop after the effect fades
                    }
            )
            // Tap gesture for quick taps
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard isEnabled else { return }
                        touchOrigin = value.location
                        currentTime = 0 // Reset time for new ripple
                        isAnimating = true
                    }
            )
            .layerEffect(
                ShaderLibrary.liquidGlassWave(
                    .float2(touchOrigin),
                    .float(currentTime),
                    .float(waveSpeed),
                    .float(displacementAmount),
                    .float(refractionStrength),
                    .float(noiseScale),
                    .float2(viewSize)
                ),
                maxSampleOffset: CGSize(
                    width: displacementAmount + refractionStrength * 60,
                    height: displacementAmount + refractionStrength * 60
                ),
                isEnabled: isEnabled && isAnimating
            )
            .onChange(of: currentTime) { _, newTime in
                // Stop animating after ripple has faded (about 5 seconds)
                if newTime > 5.0 {
                    isAnimating = false
                }
            }
    }
}

// MARK: - ULTRA Liquid Glass Modifier

/// Applies ULTRA liquid glass wave effect with chromatic aberration, vortex, and turbulence
struct LiquidGlassWaveUltraModifier: ViewModifier {
    @State private var touchOrigin: CGPoint = .zero
    @State private var currentTime: TimeInterval = 0
    @State private var isAnimating: Bool = false
    @State private var viewSize: CGSize = .zero

    let waveSpeed: CGFloat
    let displacementAmount: CGFloat
    let refractionStrength: CGFloat
    let noiseScale: CGFloat
    let chromaticAberration: CGFloat
    let vortexStrength: CGFloat
    let waveRingCount: CGFloat
    let turbulence: CGFloat
    let isEnabled: Bool

    private let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                Color.clear.onAppear { viewSize = geo.size }
                    .onChange(of: geo.size) { _, new in viewSize = new }
            })
            .onReceive(timer) { _ in
                if isAnimating {
                    currentTime += 1/60
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        if !isAnimating {
                            touchOrigin = value.location
                            currentTime = 0
                            isAnimating = true
                        } else {
                            touchOrigin = value.location
                        }
                    }
                    .onEnded { _ in }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard isEnabled else { return }
                        touchOrigin = value.location
                        currentTime = 0
                        isAnimating = true
                    }
            )
            .layerEffect(
                ShaderLibrary.liquidGlassWaveUltra(
                    .float2(touchOrigin),
                    .float(currentTime),
                    .float(waveSpeed),
                    .float(displacementAmount),
                    .float(refractionStrength),
                    .float(noiseScale),
                    .float2(viewSize),
                    .float(chromaticAberration),
                    .float(vortexStrength),
                    .float(waveRingCount),
                    .float(turbulence)
                ),
                maxSampleOffset: CGSize(
                    width: displacementAmount + refractionStrength * 60 + chromaticAberration * 30,
                    height: displacementAmount + refractionStrength * 60 + chromaticAberration * 30
                ),
                isEnabled: isEnabled && isAnimating
            )
            .onChange(of: currentTime) { _, newTime in
                if newTime > 6.0 {
                    isAnimating = false
                }
            }
    }
}

// MARK: - Multi-Touch Liquid Glass Modifier

/// Applies liquid glass wave effect with multi-touch support (up to 3 touches)
struct MultiTouchLiquidGlassModifier: ViewModifier {
    @State private var state = LiquidGlassState()
    @State private var viewSize: CGSize = .zero

    let waveSpeed: CGFloat
    let displacementAmount: CGFloat
    let refractionStrength: CGFloat
    let noiseScale: CGFloat
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                Color.clear.onAppear { viewSize = geo.size }
                    .onChange(of: geo.size) { _, new in viewSize = new }
            })
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        // For simplicity, treat drag as single moving touch
                        // For true multi-touch, would need UIKit gesture recognizer
                        if state.touches.isEmpty || !state.touches.contains(where: { $0.isActive }) {
                            state.addTouch(at: value.location)
                        } else if let activeTouch = state.touches.first(where: { $0.isActive }) {
                            state.updateTouch(id: activeTouch.id, to: value.location)
                        }
                    }
                    .onEnded { _ in
                        state.endAllTouches()
                    }
            )
            // Tap gesture for quick ripples
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard isEnabled else { return }
                        state.addTouch(at: value.location)
                        // Auto-end after brief moment to create ripple
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if let touch = state.touches.last {
                                state.endTouch(id: touch.id)
                            }
                        }
                    }
            )
            .layerEffect(
                ShaderLibrary.multiTouchLiquidGlass(
                    .float2(viewSize),
                    .float(state.elapsedTime),
                    // Touch 1
                    .float2(touch(at: 0)?.origin ?? .zero),
                    .float(touch(at: 0)?.startTime ?? 0),
                    .float(touch(at: 0) != nil ? 1.0 : 0.0),
                    // Touch 2
                    .float2(touch(at: 1)?.origin ?? .zero),
                    .float(touch(at: 1)?.startTime ?? 0),
                    .float(touch(at: 1) != nil ? 1.0 : 0.0),
                    // Touch 3
                    .float2(touch(at: 2)?.origin ?? .zero),
                    .float(touch(at: 2)?.startTime ?? 0),
                    .float(touch(at: 2) != nil ? 1.0 : 0.0),
                    // Parameters
                    .float(waveSpeed),
                    .float(displacementAmount),
                    .float(refractionStrength),
                    .float(noiseScale)
                ),
                maxSampleOffset: CGSize(
                    width: displacementAmount + refractionStrength * 60,
                    height: displacementAmount + refractionStrength * 60
                ),
                isEnabled: isEnabled && hasActiveTouches
            )
            .onAppear {
                state.startAnimation()
            }
            .onDisappear {
                state.stopAnimation()
            }
    }

    private func touch(at index: Int) -> LiquidGlassTouch? {
        // Return touches that are either active or recently ended (still animating)
        let relevantTouches = state.touches.filter {
            $0.isActive || (state.elapsedTime - $0.startTime) < 3.5
        }
        guard index < relevantTouches.count else { return nil }
        return relevantTouches[index]
    }

    private var hasActiveTouches: Bool {
        state.touches.contains { $0.isActive || (state.elapsedTime - $0.startTime) < 3.5 }
    }
}

// MARK: - Ambient Liquid Glass Modifier (Always Active)

/// Applies continuous ambient liquid glass effect without touch
struct AmbientLiquidGlassModifier: ViewModifier {
    @State private var elapsedTime: TimeInterval = 0
    @State private var viewSize: CGSize = .zero

    let flowSpeed: CGFloat
    let displacementAmount: CGFloat
    let refractionStrength: CGFloat
    let noiseScale: CGFloat
    let isEnabled: Bool

    private let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                Color.clear.onAppear { viewSize = geo.size }
                    .onChange(of: geo.size) { _, new in viewSize = new }
            })
            .onReceive(timer) { _ in
                elapsedTime += 1/60
            }
            .layerEffect(
                ShaderLibrary.ambientLiquidGlass(
                    .float2(viewSize),
                    .float(elapsedTime),
                    .float(flowSpeed),
                    .float(displacementAmount),
                    .float(refractionStrength),
                    .float(noiseScale)
                ),
                maxSampleOffset: CGSize(
                    width: displacementAmount + refractionStrength * 40,
                    height: displacementAmount + refractionStrength * 40
                ),
                isEnabled: isEnabled
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Applies liquid glass wave effect that responds to touch
    /// - Parameters:
    ///   - isEnabled: Whether the effect is active
    ///   - waveSpeed: How fast waves propagate (default: 1.0)
    ///   - displacementAmount: Pixel displacement intensity (default: 30)
    ///   - refractionStrength: Glass refraction intensity 0-1 (default: 0.5)
    ///   - noiseScale: Detail level of liquid motion (default: 3.0)
    func liquidGlassWave(
        isEnabled: Bool = true,
        waveSpeed: CGFloat = 1.0,
        displacementAmount: CGFloat = 30,
        refractionStrength: CGFloat = 0.5,
        noiseScale: CGFloat = 3.0
    ) -> some View {
        modifier(LiquidGlassWaveModifier(
            waveSpeed: waveSpeed,
            displacementAmount: displacementAmount,
            refractionStrength: refractionStrength,
            noiseScale: noiseScale,
            isEnabled: isEnabled
        ))
    }

    /// Applies ULTRA liquid glass wave effect with all the bells and whistles
    /// - Parameters:
    ///   - isEnabled: Whether the effect is active
    ///   - waveSpeed: How fast waves propagate (default: 1.0)
    ///   - displacementAmount: Pixel displacement intensity (default: 35)
    ///   - refractionStrength: Glass refraction intensity 0-1 (default: 0.5)
    ///   - noiseScale: Detail level of liquid motion (default: 3.0)
    ///   - chromaticAberration: RGB channel separation 0-1 (default: 0.3)
    ///   - vortexStrength: Spiral swirl amount 0-1 (default: 0.0)
    ///   - waveRingCount: Number of concentric wave rings 1-10 (default: 3)
    ///   - turbulence: High-frequency chaos factor 0-1 (default: 0.2)
    func liquidGlassWaveUltra(
        isEnabled: Bool = true,
        waveSpeed: CGFloat = 1.0,
        displacementAmount: CGFloat = 35,
        refractionStrength: CGFloat = 0.5,
        noiseScale: CGFloat = 3.0,
        chromaticAberration: CGFloat = 0.3,
        vortexStrength: CGFloat = 0.0,
        waveRingCount: CGFloat = 3,
        turbulence: CGFloat = 0.2
    ) -> some View {
        modifier(LiquidGlassWaveUltraModifier(
            waveSpeed: waveSpeed,
            displacementAmount: displacementAmount,
            refractionStrength: refractionStrength,
            noiseScale: noiseScale,
            chromaticAberration: chromaticAberration,
            vortexStrength: vortexStrength,
            waveRingCount: waveRingCount,
            turbulence: turbulence,
            isEnabled: isEnabled
        ))
    }

    /// Applies multi-touch liquid glass effect (up to 3 simultaneous touches)
    func multiTouchLiquidGlass(
        isEnabled: Bool = true,
        waveSpeed: CGFloat = 1.0,
        displacementAmount: CGFloat = 25,
        refractionStrength: CGFloat = 0.4,
        noiseScale: CGFloat = 3.0
    ) -> some View {
        modifier(MultiTouchLiquidGlassModifier(
            waveSpeed: waveSpeed,
            displacementAmount: displacementAmount,
            refractionStrength: refractionStrength,
            noiseScale: noiseScale,
            isEnabled: isEnabled
        ))
    }

    /// Applies continuous ambient liquid glass effect (no touch required)
    func ambientLiquidGlass(
        isEnabled: Bool = true,
        flowSpeed: CGFloat = 0.5,
        displacementAmount: CGFloat = 15,
        refractionStrength: CGFloat = 0.3,
        noiseScale: CGFloat = 2.0
    ) -> some View {
        modifier(AmbientLiquidGlassModifier(
            flowSpeed: flowSpeed,
            displacementAmount: displacementAmount,
            refractionStrength: refractionStrength,
            noiseScale: noiseScale,
            isEnabled: isEnabled
        ))
    }
}

// MARK: - Preview

#Preview("Liquid Glass Wave") {
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
        .liquidGlassWave(
            waveSpeed: 1.0,
            displacementAmount: 35,
            refractionStrength: 0.6,
            noiseScale: 3.0
        )

        Text("Touch & Hold")
            .font(.title2.bold())
            .foregroundStyle(.white)
            .allowsHitTesting(false)
    }
    .ignoresSafeArea()
}

#Preview("Ambient Liquid Glass") {
    LinearGradient(
        colors: [.purple, .blue, .cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    .ambientLiquidGlass(
        flowSpeed: 0.8,
        displacementAmount: 20,
        refractionStrength: 0.4
    )
    .ignoresSafeArea()
}
