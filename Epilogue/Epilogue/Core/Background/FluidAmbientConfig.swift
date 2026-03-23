import SwiftUI

// MARK: - Color Role Assignments

/// Which palette colors are assigned to each shader role.
/// Users can reassign any palette color to any role via the Fluid Lab.
struct FluidLabColorSet {
    var primary: Color
    var secondary: Color
    var accent: Color
    var background: Color
    var complementary: Color

    static let fallback = FluidLabColorSet(
        primary: .indigo, secondary: .purple, accent: .blue,
        background: .black, complementary: .orange
    )

    /// Build from a DisplayPalette using vibrant-enhanced colors
    /// Matches the rich color output of the static gradient system
    static func from(_ dp: DisplayPalette) -> FluidLabColorSet {
        FluidLabColorSet(
            primary: dp.vibrantPrimary.color,
            secondary: dp.vibrantSecondary.color,
            accent: dp.accent.color,
            background: dp.background.color,
            complementary: dp.complementary.color
        )
    }

    /// Build from a legacy ColorPalette
    static func from(_ cp: ColorPalette) -> FluidLabColorSet {
        FluidLabColorSet(
            primary: cp.primary,
            secondary: cp.secondary,
            accent: cp.accent,
            background: cp.background,
            complementary: cp.accent // no complement in legacy
        )
    }
}

/// A named color from the palette, for display in the picker
struct PaletteColorOption: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
}

/// All available colors from a DisplayPalette
extension DisplayPalette {
    var allPaletteColors: [PaletteColorOption] {
        [
            PaletteColorOption(name: "Primary", color: primary.color),
            PaletteColorOption(name: "Secondary", color: secondary.color),
            PaletteColorOption(name: "Accent", color: accent.color),
            PaletteColorOption(name: "Background", color: background.color),
            PaletteColorOption(name: "Vibrant 1", color: vibrantPrimary.color),
            PaletteColorOption(name: "Vibrant 2", color: vibrantSecondary.color),
            PaletteColorOption(name: "Complement", color: complementary.color),
            PaletteColorOption(name: "Analogous", color: analogous.color),
            PaletteColorOption(name: "Glow", color: glow.color),
            PaletteColorOption(name: "Neutral", color: neutral.color),
        ]
    }
}

// MARK: - Shader Config

/// Cover-type-aware shader parameters for the Fluid Ambient Gradient.
/// Each cover type maps to continuous float parameters — the shader is identical
/// for all types, only the input values change.
struct FluidAmbientConfig {
    var colorIntensity: Float    // 0.3-0.9: overall color vibrancy
    var noiseAmplitude: Float    // 0.04-0.15: organic variation strength
    var darkFadeStart: Float     // 0.2-0.4: where vertical fade begins
    var accentInfluence: Float   // 0.1-0.6: accent color presence
    var secondarySpread: Float   // 0.15-0.6: secondary color spread
    var noiseScale: Float        // 1.5-4.0: spatial frequency of noise
    var warpIntensity: Float     // 0.5-2.0: domain warp strength
    var animationSpeed: Float    // 0.0-2.0: time multiplier (0 = static)

    // Extended parameters
    var originX: Float           // 0.0-1.0: focal point X
    var originY: Float           // 0.0-1.0: focal point Y
    var backgroundBlend: Float   // 0.0-0.6: background color presence
    var complementaryMix: Float  // 0.0-0.5: complementary color threads
    var grainAmount: Float       // 0.0-0.08: film grain intensity
    var vignetteStrength: Float  // 0.0-1.0: edge darkening
    var contrast: Float          // 0.5-2.0: power curve on result
    var saturationBoost: Float   // 0.5-2.0: post-process saturation

    // Ripple parameters
    var rippleIntensity: Float   // 0.0-0.3: concentric wave strength
    var rippleFrequency: Float   // 8.0-30.0: wave tightness
    var rippleSpeed: Float       // 1.0-5.0: wave expansion speed

    // Warmth / color temperature
    var colorTemperature: Float  // -0.5-0.5: warm/cool color shift

    // Additional post-processing
    var bloomStrength: Float     // 0.0-0.4: soft glow from bright areas
    var brightnessBoost: Float   // 0.5-2.0: overall brightness multiplier

    // Additional noise
    var swirlAmount: Float       // 0.0-2.0: rotational distortion around origin

    // Additional fade
    var fadeExponent: Float      // 0.5-3.0: controls fade curve shape

    /// Dump current params as a copyable string for sharing back
    var exportString: String {
        """
        colorIntensity: \(String(format: "%.3f", colorIntensity)), \
        noiseAmplitude: \(String(format: "%.3f", noiseAmplitude)), \
        darkFadeStart: \(String(format: "%.3f", darkFadeStart)), \
        accentInfluence: \(String(format: "%.3f", accentInfluence)), \
        secondarySpread: \(String(format: "%.3f", secondarySpread)), \
        noiseScale: \(String(format: "%.3f", noiseScale)), \
        warpIntensity: \(String(format: "%.3f", warpIntensity)), \
        animationSpeed: \(String(format: "%.3f", animationSpeed)), \
        originX: \(String(format: "%.3f", originX)), \
        originY: \(String(format: "%.3f", originY)), \
        backgroundBlend: \(String(format: "%.3f", backgroundBlend)), \
        complementaryMix: \(String(format: "%.3f", complementaryMix)), \
        grainAmount: \(String(format: "%.3f", grainAmount)), \
        vignetteStrength: \(String(format: "%.3f", vignetteStrength)), \
        contrast: \(String(format: "%.3f", contrast)), \
        saturationBoost: \(String(format: "%.3f", saturationBoost)), \
        rippleIntensity: \(String(format: "%.3f", rippleIntensity)), \
        rippleFrequency: \(String(format: "%.3f", rippleFrequency)), \
        rippleSpeed: \(String(format: "%.3f", rippleSpeed)), \
        colorTemperature: \(String(format: "%.3f", colorTemperature)), \
        bloomStrength: \(String(format: "%.3f", bloomStrength)), \
        brightnessBoost: \(String(format: "%.3f", brightnessBoost)), \
        swirlAmount: \(String(format: "%.3f", swirlAmount)), \
        fadeExponent: \(String(format: "%.3f", fadeExponent))
        """
    }

    init(for coverType: CoverType) {
        // Start from golden baseline — user-tuned to look great across covers.
        // Per-type adjustments are small nudges, not wholesale rewrites.
        var cfg = Self.golden

        switch coverType {
        case .dark:
            // Dark covers — push brightness and saturation to lift colors from the void
            cfg.brightnessBoost = 1.15
            cfg.saturationBoost = 1.3
            cfg.complementaryMix = 0.12  // more color variety against dark bg
            cfg.vignetteStrength = 0.15  // less vignette, already dark enough
        case .light:
            // Light covers — pull back intensity slightly, avoid blowout
            cfg.colorIntensity = 0.90
            cfg.contrast = 1.4
            cfg.saturationBoost = 1.25
            cfg.brightnessBoost = 0.90   // tame the brightness
            cfg.backgroundBlend = 0.12
        case .vibrant:
            // Already saturated — restrain to avoid neon
            cfg.saturationBoost = 1.0
            cfg.colorIntensity = 0.95
            cfg.accentInfluence = 0.15   // more accent variety
            cfg.complementaryMix = 0.15
        case .muted:
            // Muted covers need real lift
            cfg.saturationBoost = 1.4
            cfg.colorIntensity = 1.0
            cfg.brightnessBoost = 1.1
            cfg.complementaryMix = 0.20  // inject complementary for life
            cfg.accentInfluence = 0.15
        case .monochromatic:
            // Single-hue — push complementary and accent for variety
            cfg.complementaryMix = 0.22
            cfg.accentInfluence = 0.18
            cfg.saturationBoost = 1.25
            cfg.secondarySpread = 0.50
        case .balanced:
            // Golden is already tuned for balanced — use as-is
            break
        }

        self = cfg
    }

    init(
        colorIntensity: Float, noiseAmplitude: Float,
        darkFadeStart: Float, accentInfluence: Float,
        secondarySpread: Float, noiseScale: Float,
        warpIntensity: Float, animationSpeed: Float,
        originX: Float = 0.5, originY: Float = 0.15,
        backgroundBlend: Float = 0.15, complementaryMix: Float = 0.08,
        grainAmount: Float = 0.025, vignetteStrength: Float = 0.2,
        contrast: Float = 1.0, saturationBoost: Float = 1.0,
        rippleIntensity: Float = 0.0, rippleFrequency: Float = 15.0,
        rippleSpeed: Float = 2.0,
        colorTemperature: Float = 0.0, bloomStrength: Float = 0.0,
        brightnessBoost: Float = 1.0, swirlAmount: Float = 0.0,
        fadeExponent: Float = 1.0
    ) {
        self.colorIntensity = colorIntensity
        self.noiseAmplitude = noiseAmplitude
        self.darkFadeStart = darkFadeStart
        self.accentInfluence = accentInfluence
        self.secondarySpread = secondarySpread
        self.noiseScale = noiseScale
        self.warpIntensity = warpIntensity
        self.animationSpeed = animationSpeed
        self.originX = originX
        self.originY = originY
        self.backgroundBlend = backgroundBlend
        self.complementaryMix = complementaryMix
        self.grainAmount = grainAmount
        self.vignetteStrength = vignetteStrength
        self.contrast = contrast
        self.saturationBoost = saturationBoost
        self.rippleIntensity = rippleIntensity
        self.rippleFrequency = rippleFrequency
        self.rippleSpeed = rippleSpeed
        self.colorTemperature = colorTemperature
        self.bloomStrength = bloomStrength
        self.brightnessBoost = brightnessBoost
        self.swirlAmount = swirlAmount
        self.fadeExponent = fadeExponent
    }

    /// User-tuned "golden" baseline — designed to generalize across covers.
    /// Tuned via Fluid Lab. Test on multiple covers to validate.
    static let golden = FluidAmbientConfig(
        colorIntensity: 0.991, noiseAmplitude: 0.223,
        darkFadeStart: 0.600, accentInfluence: 0.457,
        secondarySpread: 0.337, noiseScale: 3.096,
        warpIntensity: 0.450, animationSpeed: 0.494,
        originX: 0.340, originY: 0.451,
        backgroundBlend: 0.085, complementaryMix: 0.449,
        grainAmount: 0.002, vignetteStrength: 0.598,
        contrast: 1.562, saturationBoost: 1.163,
        rippleIntensity: 0.300, rippleFrequency: 10.704,
        rippleSpeed: 2.240,
        colorTemperature: 0.031, bloomStrength: 0.097,
        brightnessBoost: 1.180, swirlAmount: 0.860,
        fadeExponent: 0.537
    )
}
