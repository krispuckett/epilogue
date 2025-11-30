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

    @State private var pulseAnimation = false

    init(
        palette: DisplayPalette,
        preset: GradientPreset = .atmospheric,
        intensity: Double = 1.0,
        audioLevel: Float = 0
    ) {
        self.palette = palette
        self.preset = preset
        self.intensity = intensity
        self.audioLevel = audioLevel
    }

    var body: some View {
        let config = preset.config

        GeometryReader { geometry in
            ZStack {
                // Base: Pure black
                Color.black
                    .ignoresSafeArea()

                // Main gradient layer
                mainGradientLayer(config: config, geometry: geometry)

                // Accent radial layer (depth)
                if config.accentOpacity > 0 {
                    accentLayer(config: config)
                }

                // Voice pulse overlay
                if audioLevel > 0.3 {
                    voicePulseOverlay
                }

                // Subtle noise texture
                if config.noiseOpacity > 0 {
                    noiseTexture(opacity: config.noiseOpacity)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Gradient Layers

    @ViewBuilder
    private func mainGradientLayer(config: GradientConfig, geometry: GeometryProxy) -> some View {
        let colors = config.useVibrantColors
            ? [palette.vibrantPrimary, palette.vibrantSecondary]
            : [palette.primary, palette.secondary, palette.accent, palette.background]

        let voiceBoost = 1.0 + Double(audioLevel) * 0.5
        let voiceScale = 1.0 + Double(audioLevel) * 0.1

        LinearGradient(
            stops: generateStops(
                colors: colors,
                distribution: config.stopDistribution,
                opacities: config.opacities,
                intensity: intensity * voiceBoost
            ),
            startPoint: .top,
            endPoint: .bottom
        )
        .blur(radius: config.blurRadius - Double(audioLevel) * 10)
        .scaleEffect(voiceScale)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.1), value: audioLevel)
    }

    private func generateStops(
        colors: [OKLCHColor],
        distribution: [Double],
        opacities: [Double],
        intensity: Double
    ) -> [Gradient.Stop] {
        distribution.enumerated().map { index, location in
            let colorIndex = min(index, colors.count - 1)
            let opacity = index < opacities.count ? opacities[index] : 0.0
            return Gradient.Stop(
                color: colors[colorIndex].color.opacity(opacity * intensity),
                location: location
            )
        }
    }

    @ViewBuilder
    private func accentLayer(config: GradientConfig) -> some View {
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
    @ObservedObject private var themeManager = ThemeManager.shared

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
