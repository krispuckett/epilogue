import SwiftUI

// MARK: - Cover Classification

/// Cover type classification for adaptive extraction strategies
enum CoverType: String, Codable, CaseIterable {
    /// >60% pixels with L<0.2 - boost bright accents aggressively
    case dark
    /// >50% pixels with L>0.8 and C<0.1 - find saturated focal points
    case light
    /// Average chroma >0.15 - reduce enhancement to avoid oversaturation
    case vibrant
    /// Average chroma <0.05 - boost significantly to bring out subtle colors
    case muted
    /// All hues within 30° range - create subtle variations
    case monochromatic
    /// Good color distribution - standard processing
    case balanced

    /// Description for debugging
    var debugDescription: String {
        switch self {
        case .dark: return "Dark (>60% dark pixels)"
        case .light: return "Light (>50% light/desaturated)"
        case .vibrant: return "Vibrant (high chroma)"
        case .muted: return "Muted (low chroma)"
        case .monochromatic: return "Monochromatic (narrow hue range)"
        case .balanced: return "Balanced (normal distribution)"
        }
    }

    /// Recommended enhancement config for this cover type
    var enhancementConfig: OKLCHColor.EnhancementConfig {
        switch self {
        case .dark:
            // Dark covers - moderate boost, visible but not neon
            return OKLCHColor.EnhancementConfig(
                chromaMultiplier: 1.2,
                minLightness: 0.45,
                maxLightness: 0.80,
                maxChroma: 0.32
            )
        case .light:
            // Light covers - boost to make colors pop
            return OKLCHColor.EnhancementConfig(
                chromaMultiplier: 1.25,
                minLightness: 0.40,
                maxLightness: 0.75,
                maxChroma: 0.30
            )
        case .vibrant:
            // Already vibrant - slight reduction
            return OKLCHColor.EnhancementConfig(
                chromaMultiplier: 1.0,
                minLightness: 0.42,
                maxLightness: 0.78,
                maxChroma: 0.30
            )
        case .muted:
            // Muted covers need real boost
            return OKLCHColor.EnhancementConfig(
                chromaMultiplier: 1.4,
                minLightness: 0.45,
                maxLightness: 0.80,
                maxChroma: 0.32
            )
        case .monochromatic:
            // Single-hue - moderate enhancement
            return OKLCHColor.EnhancementConfig(
                chromaMultiplier: 1.2,
                minLightness: 0.42,
                maxLightness: 0.82,
                maxChroma: 0.28
            )
        case .balanced:
            // Standard enhancement
            return OKLCHColor.EnhancementConfig(
                chromaMultiplier: 1.2,
                minLightness: 0.42,
                maxLightness: 0.78,
                maxChroma: 0.30
            )
        }
    }
}

// MARK: - Display Palette

/// Display-ready color palette - processed once, cached, used everywhere
/// All colors are pre-enhanced and ready for immediate use in gradients.
public struct DisplayPalette: Codable, Equatable {

    // MARK: - Standard Enhancement (1.3x chroma) - Atmospheric Gradients

    /// Primary color - most visually important color from cover
    let primary: OKLCHColor
    /// Secondary color - second most important, provides contrast
    let secondary: OKLCHColor
    /// Accent color - adds visual interest and depth
    let accent: OKLCHColor
    /// Background color - for deeper fade areas
    let background: OKLCHColor

    // MARK: - Vibrant Enhancement (2.0x chroma) - Hero Backgrounds

    /// Vibrant primary for hero/spotlight backgrounds
    let vibrantPrimary: OKLCHColor
    /// Vibrant secondary for hero backgrounds
    let vibrantSecondary: OKLCHColor

    // MARK: - Harmony Colors (Auto-computed)

    /// Complementary color (180° hue shift from primary)
    let complementary: OKLCHColor
    /// Analogous color (+30° hue shift from primary)
    let analogous: OKLCHColor

    // MARK: - Metadata

    /// Classification of the source cover
    let coverType: CoverType
    /// Dominant lightness (0-1) - useful for text color decisions
    let dominantLightness: Double
    /// Extraction confidence (0-1) - based on color diversity
    let extractionConfidence: Double
    /// Cache version for invalidation on algorithm updates
    let version: Int

    /// Current cache version - increment when algorithm changes
    static let currentVersion = 1

    // MARK: - Initialization

    init(
        primary: OKLCHColor,
        secondary: OKLCHColor,
        accent: OKLCHColor,
        background: OKLCHColor,
        coverType: CoverType,
        dominantLightness: Double,
        extractionConfidence: Double
    ) {
        let config = coverType.enhancementConfig

        // Apply standard enhancement
        self.primary = primary.enhanced(config: config)
        self.secondary = secondary.enhanced(config: config)
        self.accent = accent.enhanced(config: config)
        self.background = background.enhanced(config: config)

        // Apply vibrant enhancement
        self.vibrantPrimary = primary.enhanced(config: .vibrant)
        self.vibrantSecondary = secondary.enhanced(config: .vibrant)

        // Compute harmony colors from enhanced primary
        self.complementary = self.primary.complementary
        self.analogous = self.primary.analogous

        // Store metadata
        self.coverType = coverType
        self.dominantLightness = dominantLightness
        self.extractionConfidence = extractionConfidence
        self.version = Self.currentVersion
    }

    // MARK: - Gradient Convenience

    /// Colors for standard atmospheric gradient (top to bottom)
    var atmosphericColors: [Color] {
        [primary.color, secondary.color, accent.color, background.color]
    }

    /// Colors for hero/vibrant gradient
    var heroColors: [Color] {
        [vibrantPrimary.color, vibrantSecondary.color]
    }

    /// Generate gradient stops for atmospheric gradient
    func atmosphericStops(intensity: Double = 1.0) -> [Gradient.Stop] {
        [
            .init(color: primary.color.opacity(intensity * 0.9), location: 0.0),
            .init(color: secondary.color.opacity(intensity * 0.75), location: 0.18),
            .init(color: accent.color.opacity(intensity * 0.5), location: 0.38),
            .init(color: background.color.opacity(intensity * 0.25), location: 0.55),
            .init(color: Color.clear, location: 0.72)
        ]
    }

    /// Generate gradient stops for hero background
    func heroStops(intensity: Double = 1.0) -> [Gradient.Stop] {
        [
            .init(color: vibrantPrimary.color.opacity(intensity * 0.85), location: 0.0),
            .init(color: vibrantSecondary.color.opacity(intensity * 0.6), location: 0.4),
            .init(color: Color.clear, location: 1.0)
        ]
    }

    // MARK: - Text Color Decision

    /// Recommended text color based on dominant lightness
    var recommendedTextColor: Color {
        dominantLightness > 0.6 ? .black : .white
    }

    /// Whether the palette is considered "light" overall
    var isLightPalette: Bool {
        dominantLightness > 0.6
    }

    // MARK: - Quality Indicators

    /// Whether the extraction produced high-quality results
    var isHighQuality: Bool {
        extractionConfidence > 0.7
    }

    /// Whether the palette has good color variety
    var hasGoodVariety: Bool {
        let colors = [primary, secondary, accent, background]
        let distances = colors.enumerated().flatMap { i, c1 in
            colors.dropFirst(i + 1).map { c2 in c1.distance(to: c2) }
        }
        let avgDistance = distances.reduce(0, +) / Double(max(distances.count, 1))
        return avgDistance > 0.08
    }
}

// MARK: - Legacy Conversion

extension DisplayPalette {
    /// Convert legacy ColorPalette to DisplayPalette
    /// Used for migration from old cache format
    static func fromLegacy(_ legacy: ColorPalette, coverType: CoverType = .balanced) -> DisplayPalette {
        DisplayPalette(
            primary: legacy.primary.oklch,
            secondary: legacy.secondary.oklch,
            accent: legacy.accent.oklch,
            background: legacy.background.oklch,
            coverType: coverType,
            dominantLightness: legacy.luminance,
            extractionConfidence: legacy.extractionQuality
        )
    }

    /// Convert to legacy ColorPalette for backwards compatibility
    func toLegacy() -> ColorPalette {
        ColorPalette(
            primary: primary.color,
            secondary: secondary.color,
            accent: accent.color,
            background: background.color,
            textColor: recommendedTextColor,
            luminance: dominantLightness,
            isMonochromatic: coverType == .monochromatic,
            extractionQuality: extractionConfidence
        )
    }
}

// MARK: - Debug Description

extension DisplayPalette: CustomStringConvertible {
    public var description: String {
        """
        DisplayPalette v\(version) [\(coverType.rawValue)]
          Primary: \(primary)
          Secondary: \(secondary)
          Accent: \(accent)
          Background: \(background)
          Confidence: \(String(format: "%.1f%%", extractionConfidence * 100))
        """
    }
}

// MARK: - Default Palette

extension DisplayPalette {
    /// Default fallback palette (warm amber theme)
    static let `default` = DisplayPalette(
        primary: OKLCHColor(lightness: 0.65, chroma: 0.15, hue: 60),    // Warm amber
        secondary: OKLCHColor(lightness: 0.55, chroma: 0.12, hue: 45),  // Deeper amber
        accent: OKLCHColor(lightness: 0.5, chroma: 0.1, hue: 30),       // Brown accent
        background: OKLCHColor(lightness: 0.3, chroma: 0.05, hue: 40),  // Dark warm
        coverType: .balanced,
        dominantLightness: 0.5,
        extractionConfidence: 0.5
    )

    /// Create a monochromatic palette from a single color
    static func monochromatic(from baseColor: OKLCHColor) -> DisplayPalette {
        DisplayPalette(
            primary: baseColor,
            secondary: OKLCHColor(
                lightness: baseColor.lightness * 0.9,
                chroma: baseColor.chroma * 0.8,
                hue: baseColor.hue + 5
            ),
            accent: OKLCHColor(
                lightness: baseColor.lightness * 0.8,
                chroma: baseColor.chroma * 0.9,
                hue: baseColor.hue - 5
            ),
            background: OKLCHColor(
                lightness: baseColor.lightness * 0.6,
                chroma: baseColor.chroma * 0.6,
                hue: baseColor.hue
            ),
            coverType: .monochromatic,
            dominantLightness: baseColor.lightness,
            extractionConfidence: 0.7
        )
    }
}
