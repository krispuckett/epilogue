import SwiftUI

/// Adaptive legibility layers that ensure text and controls remain readable
/// over dynamic gradient backgrounds. Computed from backdrop complexity.
struct LegibilityProfile {
    /// Top scrim config (status bar / nav area)
    let topScrim: ScrimConfig
    /// Bottom scrim config (tab bar / controls area)
    let bottomScrim: ScrimConfig
    /// Blur radius at edges for depth
    let edgeBlur: Float
    /// Whether to render backing behind interactive controls
    let controlBacking: BackingStyle
    /// Area requiring guaranteed contrast
    let textSafetyZone: CGRect?

    struct ScrimConfig {
        let opacity: Double
        let height: Double  // As fraction of screen (0-1)
        let gradient: Bool  // Whether to use gradient or solid
    }

    enum BackingStyle {
        case none           // Background is dark/simple enough
        case subtle         // Light material backing
        case prominent      // Visible material backing
    }

    // MARK: - Factory

    /// Compute legibility profile from a DisplayPalette and usage context
    static func compute(
        palette: DisplayPalette,
        context: UsageContext = .detail
    ) -> LegibilityProfile {
        let _ = palette.dominantLightness
        let hasVariety = palette.hasGoodVariety
        let isLight = palette.isLightPalette

        switch context {
        case .detail:
            // Book detail — needs nav bar + bottom controls legibility
            return LegibilityProfile(
                topScrim: ScrimConfig(
                    opacity: isLight ? 0.3 : 0.15,
                    height: 0.15,
                    gradient: true
                ),
                bottomScrim: ScrimConfig(
                    opacity: isLight ? 0.25 : 0.12,
                    height: 0.20,
                    gradient: true
                ),
                edgeBlur: hasVariety ? 4 : 2,
                controlBacking: isLight ? .prominent : .subtle,
                textSafetyZone: nil
            )

        case .library:
            // Library view — lighter scrims, cards handle their own legibility
            return LegibilityProfile(
                topScrim: ScrimConfig(opacity: 0.1, height: 0.10, gradient: true),
                bottomScrim: ScrimConfig(opacity: 0.08, height: 0.12, gradient: true),
                edgeBlur: 2,
                controlBacking: .none,
                textSafetyZone: nil
            )

        case .ambient:
            // Ambient mode — maximize atmosphere, minimal scrims
            return LegibilityProfile(
                topScrim: ScrimConfig(opacity: 0.05, height: 0.08, gradient: true),
                bottomScrim: ScrimConfig(opacity: 0.08, height: 0.15, gradient: true),
                edgeBlur: 0,
                controlBacking: .subtle,
                textSafetyZone: nil
            )

        case .reading:
            // Reading mode — text legibility is paramount
            return LegibilityProfile(
                topScrim: ScrimConfig(
                    opacity: isLight ? 0.4 : 0.2,
                    height: 0.12,
                    gradient: true
                ),
                bottomScrim: ScrimConfig(
                    opacity: isLight ? 0.35 : 0.18,
                    height: 0.18,
                    gradient: true
                ),
                edgeBlur: 6,
                controlBacking: .prominent,
                textSafetyZone: CGRect(x: 0.05, y: 0.1, width: 0.9, height: 0.75)
            )
        }
    }

    enum UsageContext {
        case detail
        case library
        case ambient
        case reading
    }
}

// MARK: - Legibility Layer View

/// Renders adaptive legibility scrims over gradient backgrounds.
struct LegibilityLayerView: View {
    let profile: LegibilityProfile

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Top scrim
                VStack {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(profile.topScrim.opacity),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geometry.size.height * profile.topScrim.height)

                    Spacer()
                }

                // Bottom scrim
                VStack {
                    Spacer()

                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(profile.bottomScrim.opacity)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geometry.size.height * profile.bottomScrim.height)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - Transition Choreography

/// Coordinates role-by-role sequential palette transitions.
/// Instead of raw crossfading, morphs atmosphere roles in sequence:
/// 1. Shadow anchors move first
/// 2. Then field tones
/// 3. Then glows
/// 4. Then accent/interaction tint
struct AtmosphereTransition {

    /// Duration for the full transition
    static let totalDuration: Double = 0.8

    /// Per-role stagger offsets (as fraction of total duration)
    static let stagger: [Role: (delay: Double, duration: Double)] = [
        .shadow:  (delay: 0.0,  duration: 0.3),
        .field:   (delay: 0.1,  duration: 0.35),
        .neutral: (delay: 0.15, duration: 0.3),
        .glow:    (delay: 0.25, duration: 0.3),
        .accent:  (delay: 0.35, duration: 0.35),
    ]

    enum Role {
        case field, shadow, glow, accent, neutral
    }

    /// Interpolate between two palettes with role-aware staggered timing.
    /// `progress` is 0-1 representing overall transition progress.
    static func interpolate(
        from: DisplayPalette,
        to: DisplayPalette,
        progress: Double
    ) -> DisplayPalette {
        func roleProgress(_ role: Role) -> Double {
            guard let timing = stagger[role] else { return progress }
            let roleStart = timing.delay
            let roleEnd = timing.delay + timing.duration
            return max(0, min(1, (progress - roleStart) / (roleEnd - roleStart)))
        }

        let primary = OKLCHColorSpace.interpolate(
            from: from.primary,
            to: to.primary,
            t: roleProgress(.field)
        )
        let secondary = OKLCHColorSpace.interpolate(
            from: from.secondary,
            to: to.secondary,
            t: roleProgress(.shadow)
        )
        let accent = OKLCHColorSpace.interpolate(
            from: from.accent,
            to: to.accent,
            t: roleProgress(.accent)
        )
        let background = OKLCHColorSpace.interpolate(
            from: from.background,
            to: to.background,
            t: roleProgress(.neutral)
        )

        // Build interpolated palette (bypass enhancement since both palettes are already enhanced)
        return DisplayPalette(
            primary: primary,
            secondary: secondary,
            accent: accent,
            background: background,
            coverType: progress < 0.5 ? from.coverType : to.coverType,
            dominantLightness: from.dominantLightness + (to.dominantLightness - from.dominantLightness) * progress,
            extractionConfidence: from.extractionConfidence + (to.extractionConfidence - from.extractionConfidence) * progress
        )
    }
}
