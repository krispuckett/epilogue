import SwiftUI
import simd

/// Manages touch impulses and ambient motion for gradient interaction.
/// Feeds into MeshGradient point displacement, chroma bloom, and specular effects.
@Observable
final class InteractionField {

    /// Active impulses (touch events + ambient)
    private(set) var impulses: [Impulse] = []

    /// Ambient breathing phase (0-2π, cycles continuously)
    private(set) var ambientPhase: Float = 0

    /// Reading energy level (0-1, increases with time spent reading)
    var readingEnergy: Float = 0

    /// Focus area for reduced motion (e.g., near text content)
    var focusRect: CGRect?

    /// Maximum simultaneous impulses
    private let maxImpulses = 5

    /// Impulse lifetime in seconds
    private let impulseLifetime: Float = 3.0

    // MARK: - Impulse Types

    struct Impulse: Identifiable {
        let id = UUID()
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        var intensity: Float
        let kind: ImpulseKind
        var age: Float = 0
        let birthTime: Date = .now

        /// Normalized intensity factoring in age decay
        var effectiveIntensity: Float {
            let ageFactor = max(0, 1.0 - age / 3.0) // 3s decay
            return intensity * ageFactor * ageFactor // Quadratic falloff
        }

        /// Whether this impulse is still alive
        var isAlive: Bool { age < 3.0 }
    }

    enum ImpulseKind {
        case tap        // Brief burst
        case drag       // Sustained directional
        case dwell      // Long press — growing intensity
        case page       // Page turn event
        case ambient    // Background breathing
    }

    // MARK: - Touch Input

    /// Register a tap at normalized coordinates (0-1)
    func tap(at position: CGPoint, in size: CGSize) {
        let normalized = SIMD2<Float>(
            Float(position.x / size.width),
            Float(position.y / size.height)
        )
        addImpulse(Impulse(
            position: normalized,
            velocity: .zero,
            intensity: 0.8,
            kind: .tap
        ))
    }

    /// Register a drag with velocity
    func drag(at position: CGPoint, velocity: CGSize, in size: CGSize) {
        let normalized = SIMD2<Float>(
            Float(position.x / size.width),
            Float(position.y / size.height)
        )
        let vel = SIMD2<Float>(
            Float(velocity.width / size.width),
            Float(velocity.height / size.height)
        )
        let speed = length(vel)
        addImpulse(Impulse(
            position: normalized,
            velocity: vel,
            intensity: min(0.6 + speed * 0.3, 1.0),
            kind: .drag
        ))
    }

    /// Register a page turn event
    func pageTurn() {
        addImpulse(Impulse(
            position: SIMD2<Float>(0.5, 0.5),
            velocity: SIMD2<Float>(1.0, 0.0),
            intensity: 0.5,
            kind: .page
        ))
    }

    // MARK: - Update Loop

    /// Advance the simulation by dt seconds. Call from TimelineView.
    func update(dt: Float) {
        // Age and cull impulses
        impulses = impulses.compactMap { var imp = $0; imp.age += dt; return imp.isAlive ? imp : nil }

        // Advance ambient phase
        ambientPhase += dt * 0.3 // ~20s full cycle
        if ambientPhase > .pi * 2 { ambientPhase -= .pi * 2 }
    }

    // MARK: - Mesh Point Displacement

    /// Calculate displacement for a mesh control point based on all active impulses.
    /// Returns offset in normalized coordinates (typically small, <0.05).
    func displacement(at point: SIMD2<Float>) -> SIMD2<Float> {
        var total = SIMD2<Float>.zero

        for impulse in impulses {
            let delta = point - impulse.position
            let dist = length(delta)
            guard dist > 0.001 else { continue }

            let falloff = exp(-dist * 8) // Localized effect
            let direction = delta / dist

            switch impulse.kind {
            case .tap:
                // Radial push away from touch
                total += direction * impulse.effectiveIntensity * falloff * 0.04
            case .drag:
                // Follow velocity direction
                let dragDir = normalize(impulse.velocity + SIMD2<Float>(0.001, 0.001))
                total += dragDir * impulse.effectiveIntensity * falloff * 0.03
            case .dwell:
                // Pull toward touch (attraction)
                total -= direction * impulse.effectiveIntensity * falloff * 0.02
            case .page:
                // Horizontal sweep
                total += SIMD2<Float>(impulse.effectiveIntensity * falloff * 0.03, 0)
            case .ambient:
                break
            }
        }

        // Ambient breathing displacement
        let breathX = sin(ambientPhase + point.x * 3) * 0.008
        let breathY = cos(ambientPhase * 0.7 + point.y * 2.5) * 0.006
        total += SIMD2<Float>(Float(breathX), Float(breathY))

        // Reduce motion near focus rect (text areas)
        if let focus = focusRect {
            let inFocus = focus.contains(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
            if inFocus {
                total *= 0.2 // 80% reduction near text
            }
        }

        return total
    }

    /// Calculate chroma bloom intensity at a point (for accent effects near touch)
    func chromaBloom(at point: SIMD2<Float>) -> Float {
        var bloom: Float = 0
        for impulse in impulses where impulse.kind == .tap || impulse.kind == .dwell {
            let dist = length(point - impulse.position)
            bloom += impulse.effectiveIntensity * exp(-dist * 6) * 0.5
        }
        return min(bloom, 1.0)
    }

    // MARK: - Private

    private func addImpulse(_ impulse: Impulse) {
        impulses.append(impulse)
        // Trim oldest if over limit
        if impulses.count > maxImpulses {
            impulses.removeFirst(impulses.count - maxImpulses)
        }
    }
}
