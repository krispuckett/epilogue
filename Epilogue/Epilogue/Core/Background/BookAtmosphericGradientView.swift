import SwiftUI

/// Atmospheric gradient background for book views.
///
/// This is the single entry point for all atmospheric gradients.
/// When Atmosphere Engine v2 is enabled, delegates to `UnifiedAtmosphericGradient`.
/// When v2 is off, renders using the legacy HSB enhancement path.
struct BookAtmosphericGradientView: View {
    let colorPalette: ColorPalette
    var displayPalette: DisplayPalette?
    let intensity: Double
    let audioLevel: Float
    var coverImage: UIImage?

    init(
        colorPalette: ColorPalette,
        displayPalette: DisplayPalette? = nil,
        intensity: Double = 1.0,
        audioLevel: Float = 0,
        coverImage: UIImage? = nil
    ) {
        self.colorPalette = colorPalette
        self.displayPalette = displayPalette
        self.intensity = intensity
        self.audioLevel = audioLevel
        self.coverImage = coverImage
    }

    var body: some View {
        if let dp = displayPalette {
            // v2: Pre-extracted DisplayPalette — full OKLCH atmospheric rendering
            UnifiedAtmosphericGradient(
                palette: dp,
                preset: .atmospheric,
                intensity: intensity,
                audioLevel: audioLevel,
                coverImage: coverImage
            )
        } else if AtmosphereEngine.isEnabled {
            // v2 without DisplayPalette: convert from legacy ColorPalette
            UnifiedAtmosphericGradient(
                legacyPalette: colorPalette,
                preset: .atmospheric,
                intensity: intensity,
                audioLevel: audioLevel
            )
        } else {
            // v1: Legacy HSB enhancement rendering
            LegacyAtmosphericGradient(
                colorPalette: colorPalette,
                intensity: intensity,
                audioLevel: audioLevel
            )
        }
    }
}

// MARK: - Convenience Transition

/// Temporary typealias for easier migration
typealias BookGradientView = BookAtmosphericGradientView

// MARK: - Legacy Atmospheric Gradient (v1)

/// Legacy gradient renderer preserved for v1 fallback.
/// Uses HSB color enhancement with monochromatic safety.
private struct LegacyAtmosphericGradient: View {
    let colorPalette: ColorPalette
    let intensity: Double
    let audioLevel: Float

    @State private var displayedPalette: ColorPalette?
    @State private var pulseAnimation = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if let palette = displayedPalette {
                    let voiceBoost = 1.0 + Double(audioLevel) * 0.5
                    let voiceScale = 1.0 + Double(audioLevel) * 0.1

                    LinearGradient(
                        stops: [
                            .init(color: palette.primary.opacity(intensity * voiceBoost), location: 0.0),
                            .init(color: palette.secondary.opacity(intensity * 0.85 * voiceBoost), location: 0.18),
                            .init(color: palette.accent.opacity(intensity * 0.55 * voiceBoost), location: 0.35),
                            .init(color: palette.background.opacity(intensity * 0.3 * voiceBoost), location: 0.5),
                            .init(color: Color.clear, location: 0.65)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blur(radius: 38 - Double(audioLevel) * 10)
                    .scaleEffect(voiceScale)
                    .ignoresSafeArea()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)

                    RadialGradient(
                        colors: [
                            palette.accent.opacity(intensity * 0.15),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 80,
                        endRadius: 300
                    )
                    .blur(radius: 50)
                    .ignoresSafeArea()

                    if audioLevel > 0.3 {
                        RadialGradient(
                            colors: [
                                palette.primary.opacity(Double(audioLevel) * 0.3),
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
                }

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.05)
                    .ignoresSafeArea()
                    .blendMode(.plusLighter)
            }
        }
        .onAppear {
            displayedPalette = processColors(colorPalette)
        }
        .onChange(of: colorPalette) { _, newPalette in
            withAnimation(.easeInOut(duration: 0.3)) {
                displayedPalette = processColors(newPalette)
            }
        }
    }

    // MARK: - Legacy HSB Enhancement

    private func processColors(_ palette: ColorPalette) -> ColorPalette {
        ColorPalette(
            primary: enhanceColor(palette.primary),
            secondary: enhanceColor(palette.secondary),
            accent: enhanceColor(palette.accent),
            background: enhanceColor(palette.background),
            textColor: palette.textColor,
            luminance: palette.luminance,
            isMonochromatic: palette.isMonochromatic,
            extractionQuality: palette.extractionQuality
        )
    }

    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        saturation = min(saturation * 1.3, 1.0)
        brightness = max(brightness, 0.45)

        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }
}

// MARK: - Preview

#Preview {
    BookAtmosphericGradientView(
        colorPalette: ColorPalette(
            primary: .blue,
            secondary: .purple,
            accent: .pink,
            background: .indigo,
            textColor: .white,
            luminance: 0.5,
            isMonochromatic: false,
            extractionQuality: 1.0
        )
    )
}
