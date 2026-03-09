import Foundation

/// Replaces the count-based extraction quality metric with a multi-dimensional
/// perceptual quality score. Drives confidence-aware fallback decisions.
struct PaletteQualityScore: Codable, Equatable {

    /// Average pairwise ΔE in OKLab between role colors (0-1 normalized)
    let spread: Float

    /// Average chroma of non-background colors (0-1 normalized)
    let chromaRichness: Float

    /// Difference between lightest and darkest role (0-1)
    let lightnessRange: Float

    /// Hue arc analysis — how well colors form a harmonic relationship (0-1)
    let harmonyFit: Float

    /// Text contamination detected during extraction (0-1, lower is better)
    let textContamination: Float

    /// Saliency-weighted support area — how much of the image supports the palette (0-1)
    let saliencySupport: Float

    /// Time taken for extraction in milliseconds
    let extractionTimeMs: Double

    /// Which extraction path was used
    let extractionPath: ExtractionPath

    /// Weighted composite score (0-1)
    var composite: Float {
        0.25 * spread +
        0.20 * chromaRichness +
        0.20 * lightnessRange +
        0.15 * harmonyFit +
        0.10 * (1.0 - textContamination) +
        0.10 * saliencySupport
    }

    /// Confidence tier based on composite score
    var confidenceTier: ConfidenceTier {
        switch composite {
        case 0.6...:       return .high
        case 0.4..<0.6:    return .medium
        case 0.25..<0.4:   return .low
        default:           return .veryLow
        }
    }

    enum ConfidenceTier: String, Codable {
        case high       // Stay close to extracted hues
        case medium     // Compress chroma range, increase tonal spacing
        case low        // Preserve 1-2 hues, synthesize rest from OKLCH harmonies
        case veryLow    // Editorial atmosphere family seeded by strongest hue
    }

    enum ExtractionPath: String, Codable {
        case legacy         // v1 OKLABColorExtractor
        case unified        // v2 AtmosphereExtractor
        case saliency       // v2 with Vision saliency
        case coverTexture   // Bypassed extraction — using cover-as-texture
    }

    // MARK: - Factory

    /// Build from a set of OKLCH role colors
    static func score(
        roles: [OKLCHColor],
        textContamination: Float = 0,
        saliencySupport: Float = 0.5,
        extractionTimeMs: Double = 0,
        extractionPath: ExtractionPath = .unified
    ) -> PaletteQualityScore {
        let spread = calculateSpread(roles)
        let chromaRichness = calculateChromaRichness(roles)
        let lightnessRange = calculateLightnessRange(roles)
        let harmonyFit = calculateHarmonyFit(roles)

        return PaletteQualityScore(
            spread: spread,
            chromaRichness: chromaRichness,
            lightnessRange: lightnessRange,
            harmonyFit: harmonyFit,
            textContamination: textContamination,
            saliencySupport: saliencySupport,
            extractionTimeMs: extractionTimeMs,
            extractionPath: extractionPath
        )
    }

    /// Build from a legacy confidence value (0-1 count-based)
    static func fromLegacy(_ confidence: Double) -> PaletteQualityScore {
        let f = Float(confidence)
        return PaletteQualityScore(
            spread: f,
            chromaRichness: f,
            lightnessRange: f,
            harmonyFit: f,
            textContamination: 0,
            saliencySupport: f,
            extractionTimeMs: 0,
            extractionPath: .legacy
        )
    }

    // MARK: - Scoring Internals

    private static func calculateSpread(_ colors: [OKLCHColor]) -> Float {
        guard colors.count >= 2 else { return 0 }
        var totalDistance: Double = 0
        var pairCount = 0
        for i in 0..<colors.count {
            for j in (i+1)..<colors.count {
                totalDistance += colors[i].distance(to: colors[j])
                pairCount += 1
            }
        }
        let avg = totalDistance / Double(max(pairCount, 1))
        // Normalize: ΔE > 0.3 is excellent spread
        return Float(min(avg / 0.3, 1.0))
    }

    private static func calculateChromaRichness(_ colors: [OKLCHColor]) -> Float {
        guard !colors.isEmpty else { return 0 }
        // Exclude the darkest color (likely background)
        let sorted = colors.sorted { $0.lightness > $1.lightness }
        let foreground = Array(sorted.prefix(max(colors.count - 1, 1)))
        let avgChroma = foreground.reduce(0.0) { $0 + $1.chroma } / Double(foreground.count)
        // Normalize: chroma > 0.15 is rich
        return Float(min(avgChroma / 0.15, 1.0))
    }

    private static func calculateLightnessRange(_ colors: [OKLCHColor]) -> Float {
        guard !colors.isEmpty else { return 0 }
        let lightnesses = colors.map(\.lightness)
        let range = (lightnesses.max() ?? 0) - (lightnesses.min() ?? 0)
        // Normalize: range > 0.4 is good tonal contrast
        return Float(min(range / 0.4, 1.0))
    }

    private static func calculateHarmonyFit(_ colors: [OKLCHColor]) -> Float {
        guard colors.count >= 2 else { return 0.5 }
        // Check if hues form recognizable harmonic patterns
        let chromatic = colors.filter { $0.chroma > 0.03 }
        guard chromatic.count >= 2 else { return 0.5 } // Achromatic gets middle score

        let hues = chromatic.map(\.hue)

        // Check for complementary (180° ± 30°)
        var bestHarmony: Float = 0.3
        for i in 0..<hues.count {
            for j in (i+1)..<hues.count {
                let diff = abs(hues[i] - hues[j]).truncatingRemainder(dividingBy: 360)
                let angle = min(diff, 360 - diff)

                if angle > 150 && angle < 210 {
                    bestHarmony = max(bestHarmony, 0.9) // Complementary
                } else if angle > 90 && angle < 150 {
                    bestHarmony = max(bestHarmony, 0.8) // Triadic/split-comp
                } else if angle < 45 {
                    bestHarmony = max(bestHarmony, 0.7) // Analogous
                }
            }
        }
        return bestHarmony
    }
}

// MARK: - Editorial Atmosphere Families

/// Pre-designed atmosphere families for very-low-confidence extractions.
/// Seeded by the strongest surviving hue from the cover.
enum EditorialAtmosphere: String, CaseIterable {
    case ink          // Deep indigo/navy — scholarly, contemplative
    case ember        // Warm amber/sienna — intimate, vintage
    case dawn         // Soft rose/peach — hopeful, gentle
    case seaGlass     // Teal/seafoam — calm, measured
    case orchidNight  // Purple/plum — mysterious, literary

    /// Base OKLCH palette for this atmosphere
    var palette: (field: OKLCHColor, shadow: OKLCHColor, glow: OKLCHColor, accent: OKLCHColor) {
        switch self {
        case .ink:
            return (
                field:  OKLCHColor(lightness: 0.35, chroma: 0.08, hue: 260),
                shadow: OKLCHColor(lightness: 0.18, chroma: 0.05, hue: 255),
                glow:   OKLCHColor(lightness: 0.55, chroma: 0.10, hue: 265),
                accent: OKLCHColor(lightness: 0.60, chroma: 0.14, hue: 230)
            )
        case .ember:
            return (
                field:  OKLCHColor(lightness: 0.40, chroma: 0.10, hue: 55),
                shadow: OKLCHColor(lightness: 0.22, chroma: 0.06, hue: 50),
                glow:   OKLCHColor(lightness: 0.58, chroma: 0.12, hue: 60),
                accent: OKLCHColor(lightness: 0.62, chroma: 0.16, hue: 40)
            )
        case .dawn:
            return (
                field:  OKLCHColor(lightness: 0.50, chroma: 0.08, hue: 15),
                shadow: OKLCHColor(lightness: 0.28, chroma: 0.05, hue: 10),
                glow:   OKLCHColor(lightness: 0.65, chroma: 0.10, hue: 20),
                accent: OKLCHColor(lightness: 0.68, chroma: 0.14, hue: 350)
            )
        case .seaGlass:
            return (
                field:  OKLCHColor(lightness: 0.42, chroma: 0.08, hue: 180),
                shadow: OKLCHColor(lightness: 0.20, chroma: 0.05, hue: 175),
                glow:   OKLCHColor(lightness: 0.58, chroma: 0.10, hue: 185),
                accent: OKLCHColor(lightness: 0.62, chroma: 0.14, hue: 165)
            )
        case .orchidNight:
            return (
                field:  OKLCHColor(lightness: 0.35, chroma: 0.10, hue: 310),
                shadow: OKLCHColor(lightness: 0.18, chroma: 0.06, hue: 305),
                glow:   OKLCHColor(lightness: 0.52, chroma: 0.12, hue: 315),
                accent: OKLCHColor(lightness: 0.58, chroma: 0.16, hue: 290)
            )
        }
    }

    /// Pick the best atmosphere family for a given hue
    static func bestMatch(for hue: Double) -> EditorialAtmosphere {
        // Map hue ranges to atmospheres
        switch hue {
        case 0..<30, 340..<360:   return .dawn
        case 30..<80:             return .ember
        case 80..<170:            return .seaGlass
        case 170..<260:           return .ink
        case 260..<340:           return .orchidNight
        default:                  return .ink
        }
    }
}
