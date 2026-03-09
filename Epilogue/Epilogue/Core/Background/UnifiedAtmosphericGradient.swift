import SwiftUI

// MARK: - Gradient Preset

/// Unified gradient presets that replace all duplicate implementations
enum GradientPreset {
    /// Standard atmospheric gradient (BookAtmosphericGradientView replacement)
    case atmospheric
    /// Hero/spotlight gradient (BookCoverBackgroundView replacement)
    case hero
    /// Ambient chat gradient (AmbientChatGradientView replacement)
    case ambient
    /// Voice-reactive gradient (VoiceResponsiveBottomGradient replacement)
    case voiceReactive
    /// Minimal gradient for subtle backgrounds
    case minimal

    /// Configuration for this preset
    var config: GradientConfig {
        switch self {
        case .atmospheric:
            return GradientConfig(
                blurRadius: 38,
                stopDistribution: [0.0, 0.18, 0.35, 0.5, 0.65],
                opacities: [1.0, 0.85, 0.55, 0.3, 0.0],
                accentOpacity: 0.15,
                noiseOpacity: 0.05,
                useVibrantColors: false
            )
        case .hero:
            return GradientConfig(
                blurRadius: 50,
                stopDistribution: [0.0, 0.4, 1.0],
                opacities: [1.0, 0.8, 0.0],
                accentOpacity: 0.2,
                noiseOpacity: 0.03,
                useVibrantColors: true
            )
        case .ambient:
            return GradientConfig(
                blurRadius: 30,
                stopDistribution: [0.0, 0.15, 0.3, 0.5],
                opacities: [0.6, 0.45, 0.3, 0.0],
                accentOpacity: 0.1,
                noiseOpacity: 0.03,
                useVibrantColors: false
            )
        case .voiceReactive:
            return GradientConfig(
                blurRadius: 20,
                stopDistribution: [0.0, 0.3, 0.6, 1.0],
                opacities: [0.85, 0.65, 0.4, 0.0],
                accentOpacity: 0.2,
                noiseOpacity: 0.0,
                useVibrantColors: false
            )
        case .minimal:
            return GradientConfig(
                blurRadius: 40,
                stopDistribution: [0.0, 0.3, 0.6],
                opacities: [0.4, 0.2, 0.0],
                accentOpacity: 0.0,
                noiseOpacity: 0.0,
                useVibrantColors: false
            )
        }
    }
}

/// Configuration for gradient rendering
struct GradientConfig {
    let blurRadius: Double
    let stopDistribution: [Double]
    let opacities: [Double]
    let accentOpacity: Double
    let noiseOpacity: Double
    let useVibrantColors: Bool
}

// MARK: - Unified Atmospheric Gradient View

/// Single unified gradient view that replaces all duplicate implementations
/// Uses DisplayPalette with pre-enhanced OKLCH colors
struct UnifiedAtmosphericGradient: View {
    let palette: DisplayPalette
    let preset: GradientPreset
    let intensity: Double
    let audioLevel: Float
    var coverImage: UIImage? = nil
    var qualityScore: PaletteQualityScore? = nil

    @State private var pulseAnimation = false
    @State private var breathePhase: Double = 0

    private var useMeshRenderer: Bool {
        UserDefaults.standard.bool(forKey: "feature.gradient.mesh_renderer")
    }

    private var useCoverTexture: Bool {
        UserDefaults.standard.bool(forKey: "feature.gradient.cover_texture_fallback")
    }

    private var useAmbientBreathing: Bool {
        UserDefaults.standard.bool(forKey: "feature.gradient.ambient_breathing")
    }

    private var useLegibility: Bool {
        UserDefaults.standard.bool(forKey: "feature.gradient.legibility_layers")
    }

    private var useDebugOverlay: Bool {
        UserDefaults.standard.bool(forKey: "feature.gradient.debug_overlay")
    }

    init(
        palette: DisplayPalette,
        preset: GradientPreset = .atmospheric,
        intensity: Double = 1.0,
        audioLevel: Float = 0,
        coverImage: UIImage? = nil,
        qualityScore: PaletteQualityScore? = nil
    ) {
        self.palette = palette
        self.preset = preset
        self.intensity = intensity
        self.audioLevel = audioLevel
        self.coverImage = coverImage
        self.qualityScore = qualityScore
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if preset == .atmospheric {
                    // Check for cover-as-texture fallback first
                    if useCoverTexture, let score = qualityScore, let image = coverImage,
                       score.confidenceTier == .veryLow || score.confidenceTier == .low {
                        if score.confidenceTier == .veryLow {
                            // Full texture — bypass extraction entirely
                            CoverTextureRenderer(coverImage: image, intensity: intensity)
                        } else {
                            // Blended — texture + atmosphere
                            BlendedAtmosphereRenderer(
                                coverImage: image,
                                palette: palette,
                                confidence: score.composite,
                                intensity: intensity,
                                audioLevel: audioLevel
                            )
                        }
                    } else if useMeshRenderer {
                        // MeshGradient renderer
                        meshGradientLayer(geometry: geometry)
                    } else {
                        // Standard multi-layer atmospheric rendering
                        atmosphericLayers(geometry: geometry)
                    }

                    // Ambient breathing overlay
                    if useAmbientBreathing && audioLevel < 0.1 {
                        ambientBreathingOverlay
                    }
                } else {
                    // Other presets: simple gradient rendering
                    simpleGradientLayer(config: preset.config, geometry: geometry)
                    if preset.config.accentOpacity > 0 {
                        simpleAccentLayer(config: preset.config)
                    }
                }

                // Voice pulse overlay (all presets)
                if audioLevel > 0.3 {
                    voicePulseOverlay
                }

                // Legibility layers
                if useLegibility && preset == .atmospheric {
                    LegibilityLayerView(
                        profile: LegibilityProfile.compute(palette: palette, context: .detail)
                    )
                }

                // Subtle noise texture
                noiseTexture(opacity: 0.04)

                // Debug overlay (Gandalf mode)
                if useDebugOverlay {
                    GradientDebugOverlay(palette: palette, qualityScore: qualityScore)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Atmospheric Layers (v2 — cover-type-aware)

    @ViewBuilder
    private func atmosphericLayers(geometry: GeometryProxy) -> some View {
        let voiceBoost = 1.0 + Double(audioLevel) * 0.5
        let voiceScale = 1.0 + Double(audioLevel) * 0.08

        // Layer 1: Primary cascade — cover-type-aware stop distribution
        primaryCascade(voiceBoost: voiceBoost)
            .blur(radius: 35 - Double(audioLevel) * 8)
            .scaleEffect(voiceScale)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.1), value: audioLevel)

        // Layer 2: Accent bloom — radiates from cover area, not a corner
        if UserDefaults.standard.object(forKey: "feature.gradient.accent_bloom") == nil || UserDefaults.standard.bool(forKey: "feature.gradient.accent_bloom") {
            accentBloom
        }

        // Layer 3: Harmony depth — complementary wash adds tonal depth
        // Layer 4: Analogous edge tint — subtle warmth at margins
        if UserDefaults.standard.object(forKey: "feature.gradient.harmony_layers") == nil || UserDefaults.standard.bool(forKey: "feature.gradient.harmony_layers") {
            harmonyDepthLayer
            analogousEdgeTint
        }
    }

    // MARK: - Layer 1: Primary Cascade

    @ViewBuilder
    private func primaryCascade(voiceBoost: Double) -> some View {
        let i = intensity * voiceBoost

        LinearGradient(
            stops: coverTypeStops(intensity: i),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Cover-type-aware gradient stops — each type has different
    /// reach, opacity curve, and color role separation.
    private func coverTypeStops(intensity i: Double) -> [Gradient.Stop] {
        switch palette.coverType {
        case .dark:
            // Dark covers: Strong primary, long reach, accent punches through mid-section
            return [
                .init(color: palette.primary.color.opacity(i * 0.95), location: 0.0),
                .init(color: palette.secondary.color.opacity(i * 0.78), location: 0.14),
                .init(color: palette.accent.color.opacity(i * 0.58), location: 0.30),
                .init(color: palette.background.color.opacity(i * 0.32), location: 0.50),
                .init(color: Color.clear, location: 0.72)
            ]
        case .vibrant:
            // Vibrant: Restrained elegance — shorter reach, gentle opacity curve
            return [
                .init(color: palette.primary.color.opacity(i * 0.82), location: 0.0),
                .init(color: palette.secondary.color.opacity(i * 0.58), location: 0.18),
                .init(color: palette.accent.color.opacity(i * 0.32), location: 0.35),
                .init(color: Color.clear, location: 0.52)
            ]
        case .muted:
            // Muted: Push harder — wider reach, higher opacity to compensate
            return [
                .init(color: palette.primary.color.opacity(i * 0.92), location: 0.0),
                .init(color: palette.secondary.color.opacity(i * 0.75), location: 0.16),
                .init(color: palette.accent.color.opacity(i * 0.55), location: 0.34),
                .init(color: palette.background.color.opacity(i * 0.30), location: 0.55),
                .init(color: Color.clear, location: 0.75)
            ]
        case .light:
            // Light: Deeper tones to avoid washout, moderate reach
            return [
                .init(color: palette.primary.color.opacity(i * 0.88), location: 0.0),
                .init(color: palette.secondary.color.opacity(i * 0.68), location: 0.16),
                .init(color: palette.accent.color.opacity(i * 0.42), location: 0.32),
                .init(color: Color.clear, location: 0.55)
            ]
        case .monochromatic:
            // Monochromatic: Standard reach, harmony layers do the heavy lifting
            return [
                .init(color: palette.primary.color.opacity(i * 0.88), location: 0.0),
                .init(color: palette.secondary.color.opacity(i * 0.70), location: 0.16),
                .init(color: palette.accent.color.opacity(i * 0.45), location: 0.34),
                .init(color: palette.background.color.opacity(i * 0.22), location: 0.52),
                .init(color: Color.clear, location: 0.68)
            ]
        case .balanced:
            // Balanced: Confident standard
            return [
                .init(color: palette.primary.color.opacity(i * 0.90), location: 0.0),
                .init(color: palette.secondary.color.opacity(i * 0.72), location: 0.16),
                .init(color: palette.accent.color.opacity(i * 0.48), location: 0.33),
                .init(color: palette.background.color.opacity(i * 0.25), location: 0.52),
                .init(color: Color.clear, location: 0.70)
            ]
        }
    }

    // MARK: - Layer 2: Accent Bloom

    /// Accent color radiates from the cover area (top-center),
    /// not from a fixed corner. Intensity varies by cover type.
    @ViewBuilder
    private var accentBloom: some View {
        let bloomConfig = accentBloomConfig

        // Inner concentrated bloom
        RadialGradient(
            colors: [
                palette.accent.color.opacity(bloomConfig.innerOpacity * intensity),
                palette.accent.color.opacity(bloomConfig.outerOpacity * intensity),
                Color.clear
            ],
            center: UnitPoint(x: 0.5, y: 0.22),
            startRadius: 20,
            endRadius: bloomConfig.radius
        )
        .blur(radius: 30)
        .ignoresSafeArea()

        // Wider secondary bloom using vibrant primary for depth
        RadialGradient(
            colors: [
                palette.vibrantPrimary.color.opacity(bloomConfig.outerOpacity * 0.8 * intensity),
                Color.clear
            ],
            center: UnitPoint(x: 0.4, y: 0.18),
            startRadius: 60,
            endRadius: bloomConfig.radius * 1.2
        )
        .blur(radius: 40)
        .ignoresSafeArea()
    }

    private var accentBloomConfig: (innerOpacity: Double, outerOpacity: Double, radius: CGFloat) {
        switch palette.coverType {
        case .dark:          return (0.45, 0.18, 300)  // Strong glow — the signature v2 look
        case .muted:         return (0.38, 0.14, 280)  // Noticeable life
        case .monochromatic: return (0.35, 0.12, 270)  // Compensate for limited hue variety
        case .balanced:      return (0.30, 0.10, 260)
        case .light:         return (0.25, 0.08, 240)
        case .vibrant:       return (0.18, 0.06, 220)  // Restrained — already colorful
        }
    }

    // MARK: - Layer 3: Harmony Depth

    /// Complementary color wash in the mid-section creates tonal depth
    /// that v1's single-palette gradient structurally cannot achieve.
    @ViewBuilder
    private var harmonyDepthLayer: some View {
        let complementaryOpacity: Double = {
            switch palette.coverType {
            case .dark:          return 0.25
            case .muted:         return 0.28
            case .monochromatic: return 0.30  // Most benefit — adds hue variety
            case .balanced:      return 0.20
            case .light:         return 0.15
            case .vibrant:       return 0.10  // Just a hint
            }
        }()

        // Primary complementary wash — offset right of center
        RadialGradient(
            colors: [
                palette.complementary.color.opacity(complementaryOpacity * intensity),
                palette.complementary.color.opacity(complementaryOpacity * 0.3 * intensity),
                Color.clear
            ],
            center: UnitPoint(x: 0.78, y: 0.35),
            startRadius: 30,
            endRadius: 280
        )
        .blur(radius: 45)
        .ignoresSafeArea()
    }

    // MARK: - Layer 4: Analogous Edge Tint

    /// Analogous color at the left edge adds warmth and dimensionality.
    /// For monochromatic covers this is especially important — it's the only
    /// source of hue variety in the gradient.
    @ViewBuilder
    private var analogousEdgeTint: some View {
        let tintOpacity: Double = {
            switch palette.coverType {
            case .monochromatic: return 0.25  // Critical for single-hue covers
            case .muted:         return 0.22
            case .dark:          return 0.18
            case .balanced:      return 0.15
            case .light:         return 0.12
            case .vibrant:       return 0.08
            }
        }()

        // Left edge: analogous warmth
        LinearGradient(
            colors: [
                palette.analogous.color.opacity(tintOpacity * intensity),
                Color.clear
            ],
            startPoint: .leading,
            endPoint: UnitPoint(x: 0.45, y: 0.5)
        )
        .blur(radius: 40)
        .ignoresSafeArea()
    }

    // MARK: - MeshGradient Renderer (Phase 3)

    @ViewBuilder
    private func meshGradientLayer(geometry: GeometryProxy) -> some View {
        let voiceBoost = 1.0 + Double(audioLevel) * 0.5
        let breathX = sin(breathePhase) * 0.02
        let breathY = cos(breathePhase * 0.7) * 0.015

        // 3×3 mesh with colors derived from palette roles in OKLCH
        // Pre-calculate intermediates to guarantee perceptually even transitions
        let mid1 = OKLCHColorSpace.interpolate(from: palette.primary, to: palette.secondary, t: 0.5)
        let mid2 = OKLCHColorSpace.interpolate(from: palette.accent, to: palette.background, t: 0.5)
        let center = OKLCHColorSpace.interpolate(from: mid1, to: palette.complementary, t: 0.3)

        MeshGradient(
            width: 3,
            height: 3,
            points: [
                // Top row
                SIMD2<Float>(0.0, 0.0),
                SIMD2<Float>(0.5 + Float(breathX), 0.0),
                SIMD2<Float>(1.0, 0.0),
                // Middle row
                SIMD2<Float>(0.0, 0.5 + Float(breathY)),
                SIMD2<Float>(0.5 + Float(breathX * 0.5), 0.5 + Float(breathY * 0.7)),
                SIMD2<Float>(1.0, 0.5 - Float(breathY)),
                // Bottom row
                SIMD2<Float>(0.0, 1.0),
                SIMD2<Float>(0.5 - Float(breathX), 1.0),
                SIMD2<Float>(1.0, 1.0)
            ],
            colors: [
                // Top row: primary → accent → secondary
                palette.primary.color.opacity(intensity * 0.9 * voiceBoost),
                palette.accent.color.opacity(intensity * 0.7 * voiceBoost),
                palette.secondary.color.opacity(intensity * 0.85 * voiceBoost),
                // Middle row: analogous → center blend → complementary
                palette.analogous.color.opacity(intensity * 0.6 * voiceBoost),
                center.color.opacity(intensity * 0.5 * voiceBoost),
                palette.complementary.color.opacity(intensity * 0.4 * voiceBoost),
                // Bottom row: fade to dark
                palette.background.color.opacity(intensity * 0.3 * voiceBoost),
                mid2.color.opacity(intensity * 0.15 * voiceBoost),
                Color.clear
            ]
        )
        .ignoresSafeArea()
        .onAppear { startBreathing() }
        .onDisappear { breathePhase = 0 }
    }

    // MARK: - Ambient Breathing

    @ViewBuilder
    private var ambientBreathingOverlay: some View {
        // Subtle luminance/chroma drift when idle
        let breathIntensity = sin(breathePhase * 0.5) * 0.03 + 0.02

        RadialGradient(
            colors: [
                palette.glow.color.opacity(breathIntensity * intensity),
                Color.clear
            ],
            center: UnitPoint(
                x: 0.5 + sin(breathePhase * 0.3) * 0.1,
                y: 0.3 + cos(breathePhase * 0.2) * 0.08
            ),
            startRadius: 50,
            endRadius: 350
        )
        .blur(radius: 60)
        .ignoresSafeArea()
        .blendMode(.plusLighter)
        .onAppear { startBreathing() }
    }

    private func startBreathing() {
        // Continuous slow animation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            breathePhase = .pi * 2
        }
    }

    // MARK: - Simple Gradient (non-atmospheric presets)

    @ViewBuilder
    private func simpleGradientLayer(config: GradientConfig, geometry: GeometryProxy) -> some View {
        let colors = config.useVibrantColors
            ? [palette.vibrantPrimary, palette.vibrantSecondary]
            : [palette.primary, palette.secondary, palette.accent, palette.background]

        let voiceBoost = 1.0 + Double(audioLevel) * 0.5
        let voiceScale = 1.0 + Double(audioLevel) * 0.1

        LinearGradient(
            stops: config.stopDistribution.enumerated().map { index, location in
                let colorIndex = min(index, colors.count - 1)
                let opacity = index < config.opacities.count ? config.opacities[index] : 0.0
                return Gradient.Stop(
                    color: colors[colorIndex].color.opacity(opacity * intensity * voiceBoost),
                    location: location
                )
            },
            startPoint: .top,
            endPoint: .bottom
        )
        .blur(radius: config.blurRadius - Double(audioLevel) * 10)
        .scaleEffect(voiceScale)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.1), value: audioLevel)
    }

    @ViewBuilder
    private func simpleAccentLayer(config: GradientConfig) -> some View {
        RadialGradient(
            colors: [
                palette.accent.color.opacity(config.accentOpacity * intensity),
                Color.clear
            ],
            center: UnitPoint(x: 0.3, y: 0.3),
            startRadius: 80,
            endRadius: 300
        )
        .blur(radius: 50)
        .ignoresSafeArea()
    }

    // MARK: - Shared Layers

    @ViewBuilder
    private var voicePulseOverlay: some View {
        RadialGradient(
            colors: [
                palette.primary.color.opacity(Double(audioLevel) * 0.3),
                Color.clear
            ],
            center: .center,
            startRadius: 100,
            endRadius: 400
        )
        .ignoresSafeArea()
        .blendMode(.plusLighter)
        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseAnimation)
        .onAppear { pulseAnimation = true }
        .onDisappear { pulseAnimation = false }
    }

    @ViewBuilder
    private func noiseTexture(opacity: Double) -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .opacity(opacity)
            .ignoresSafeArea()
            .blendMode(.plusLighter)
    }
}

// MARK: - Legacy ColorPalette Support

extension UnifiedAtmosphericGradient {
    /// Initialize with legacy ColorPalette for backward compatibility
    init(
        legacyPalette: ColorPalette,
        preset: GradientPreset = .atmospheric,
        intensity: Double = 1.0,
        audioLevel: Float = 0
    ) {
        self.init(
            palette: DisplayPalette.fromLegacy(legacyPalette),
            preset: preset,
            intensity: intensity,
            audioLevel: audioLevel
        )
    }
}

// MARK: - Voice Reactive Bottom Gradient (Replacement)

/// Unified voice-reactive bottom gradient
/// Replaces VoiceResponsiveBottomGradient from ChatSharedTypes
struct UnifiedVoiceBottomGradient: View {
    let palette: DisplayPalette?
    let audioLevel: Float
    let isRecording: Bool

    @State private var waveOffset: Double = 0

    private var displayPalette: DisplayPalette {
        palette ?? DisplayPalette.default
    }

    private func gradientHeight(for screenHeight: CGFloat) -> CGFloat {
        let baseHeight: CGFloat = 240

        // Logarithmic curve for better low-volume sensitivity
        let normalizedAudio = min(audioLevel, 1.0)
        let amplifiedLevel = log10(1 + normalizedAudio * 9)

        let audioBoost = CGFloat(amplifiedLevel) * 200
        let maxHeight: CGFloat = screenHeight * 0.35
        return min(baseHeight + audioBoost, maxHeight)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()

                LinearGradient(
                    stops: [
                        .init(color: displayPalette.primary.color.opacity(0.85), location: 0.0),
                        .init(color: displayPalette.secondary.color.opacity(0.65), location: 0.3),
                        .init(color: displayPalette.accent.color.opacity(0.4), location: 0.6),
                        .init(color: Color.clear, location: 1.0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: gradientHeight(for: geometry.size.height))
                .blur(radius: 20)
                .opacity(isRecording ? 1.0 : 0.001)
                .scaleEffect(y: 1.0 + Double(min(log10(1 + audioLevel * 9), 1.0)) * 0.6, anchor: .bottom)
                .animation(.easeInOut(duration: 0.1), value: audioLevel)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isRecording)
                .overlay(alignment: .bottom) {
                    if isRecording {
                        waveOverlay
                    }
                }
            }
        }
        .onAppear {
            withAnimation {
                waveOffset = .pi
            }
        }
    }

    @ViewBuilder
    private var waveOverlay: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        displayPalette.primary.color.opacity(0.3),
                        displayPalette.secondary.color.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(height: 60)
            .blur(radius: 15)
            .offset(y: sin(waveOffset) * 10)
            .animation(
                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                value: waveOffset
            )
    }
}

// MARK: - Ambient Chat Gradient (Replacement)

/// Unified ambient chat gradient
/// Replaces AmbientChatGradientView from ChatSharedTypes
struct UnifiedAmbientChatGradient: View {
    let palette: DisplayPalette?
    private var themeManager = ThemeManager.shared

    private var colors: [Color] {
        if let palette = palette {
            return [
                palette.primary.color,
                palette.secondary.color,
                palette.accent.color,
                palette.background.color
            ]
        }
        // Fallback to theme colors
        return themeManager.currentTheme.gradientColors
    }

    private var isDaybreak: Bool {
        themeManager.currentTheme == .daybreak
    }

    var body: some View {
        ZStack {
            Color.black

            // Top gradient
            LinearGradient(
                stops: [
                    .init(color: colors[0].opacity(isDaybreak ? 0.95 : 0.6), location: 0.0),
                    .init(color: colors[1].opacity(isDaybreak ? 0.85 : 0.45), location: 0.15),
                    .init(color: colors[2].opacity(isDaybreak ? 0.75 : 0.3), location: 0.3),
                    .init(color: Color.clear, location: 0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Bottom gradient
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0.5),
                    .init(color: colors[2].opacity(isDaybreak ? 0.65 : 0.3), location: 0.7),
                    .init(color: colors[1].opacity(isDaybreak ? 0.75 : 0.45), location: 0.85),
                    .init(color: colors[3].opacity(isDaybreak ? 0.85 : 0.6), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview("Atmospheric") {
    UnifiedAtmosphericGradient(
        palette: DisplayPalette.default,
        preset: .atmospheric
    )
}

#Preview("Hero") {
    UnifiedAtmosphericGradient(
        palette: DisplayPalette.default,
        preset: .hero
    )
}

#Preview("Voice Reactive") {
    UnifiedVoiceBottomGradient(
        palette: DisplayPalette.default,
        audioLevel: 0.5,
        isRecording: true
    )
}
