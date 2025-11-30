import SwiftUI
import simd

// MARK: - OKLCH Color Type

/// OKLCH: Perceptually uniform cylindrical color space
/// Unlike HSB where 50% saturation at red looks different than at blue,
/// OKLCH chroma is perceptually uniform across all hues.
struct OKLCHColor: Codable, Equatable, Hashable {
    /// Perceptual lightness (0-1)
    let lightness: Double
    /// Perceptual colorfulness (0-0.4 typical, can exceed for very saturated)
    let chroma: Double
    /// Hue angle in degrees (0-360)
    let hue: Double

    init(lightness: Double, chroma: Double, hue: Double) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = hue.truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Perceptual Enhancement

    /// Enhance color perceptually - works uniformly across ALL hues
    /// Unlike HSB enhancement which affects colors differently based on hue,
    /// OKLCH chroma boost is perceptually consistent.
    func enhanced(chromaMultiplier: Double = 1.3, minLightness: Double = 0.45) -> OKLCHColor {
        OKLCHColor(
            lightness: max(lightness, minLightness),
            chroma: min(chroma * chromaMultiplier, 0.4), // Cap prevents oversaturation
            hue: hue
        )
    }

    /// Apply enhancement with custom configuration
    func enhanced(config: EnhancementConfig) -> OKLCHColor {
        OKLCHColor(
            lightness: clamp(lightness, min: config.minLightness, max: config.maxLightness),
            chroma: min(chroma * config.chromaMultiplier, config.maxChroma),
            hue: hue
        )
    }

    // MARK: - Harmony Generation

    /// Complementary color (+180° hue shift)
    var complementary: OKLCHColor {
        OKLCHColor(lightness: lightness, chroma: chroma, hue: hue + 180)
    }

    /// Analogous color (+30° hue shift)
    var analogous: OKLCHColor {
        OKLCHColor(lightness: lightness, chroma: chroma, hue: hue + 30)
    }

    /// Analogous color (-30° hue shift)
    var analogousReverse: OKLCHColor {
        OKLCHColor(lightness: lightness, chroma: chroma, hue: hue - 30)
    }

    /// Triadic colors (+120° and +240° hue shifts)
    var triadic: (OKLCHColor, OKLCHColor) {
        (
            OKLCHColor(lightness: lightness, chroma: chroma, hue: hue + 120),
            OKLCHColor(lightness: lightness, chroma: chroma, hue: hue + 240)
        )
    }

    // MARK: - Color Properties

    /// Whether this color is essentially achromatic (gray/white/black)
    var isAchromatic: Bool {
        chroma < 0.02
    }

    /// Whether this color is very dark
    var isDark: Bool {
        lightness < 0.2
    }

    /// Whether this color is very light
    var isLight: Bool {
        lightness > 0.8
    }

    /// Visual "weight" of the color - how much it stands out
    var visualWeight: Double {
        // High chroma + mid-lightness = highest visual weight
        let lightnessWeight = 1.0 - abs(lightness - 0.55) * 1.5
        return chroma * 2.5 * max(0, lightnessWeight)
    }

    // MARK: - Conversion to SwiftUI Color

    /// Convert to SwiftUI Color
    var color: Color {
        OKLCHColorSpace.toSRGB(self)
    }

    // MARK: - Helper

    private func clamp(_ value: Double, min minVal: Double, max maxVal: Double) -> Double {
        Swift.min(Swift.max(value, minVal), maxVal)
    }
}

// MARK: - Enhancement Configuration

extension OKLCHColor {
    /// Configuration for perceptual color enhancement
    struct EnhancementConfig {
        let chromaMultiplier: Double
        let minLightness: Double
        let maxLightness: Double
        let maxChroma: Double

        /// Standard enhancement for atmospheric gradients
        static let atmospheric = EnhancementConfig(
            chromaMultiplier: 1.2,
            minLightness: 0.42,
            maxLightness: 0.78,
            maxChroma: 0.30
        )

        /// Vibrant enhancement for hero backgrounds
        static let vibrant = EnhancementConfig(
            chromaMultiplier: 1.3,
            minLightness: 0.45,
            maxLightness: 0.75,
            maxChroma: 0.35
        )

        /// Subtle enhancement for muted covers
        static let subtle = EnhancementConfig(
            chromaMultiplier: 1.35,
            minLightness: 0.40,
            maxLightness: 0.82,
            maxChroma: 0.28
        )

        /// No enhancement - preserve original
        static let none = EnhancementConfig(
            chromaMultiplier: 1.0,
            minLightness: 0.0,
            maxLightness: 1.0,
            maxChroma: 1.0
        )
    }
}

// MARK: - OKLCH Color Space Conversions

/// Color space conversion utilities for OKLCH
/// Based on the Oklab color space by Björn Ottosson
/// https://bottosson.github.io/posts/oklab/
enum OKLCHColorSpace {

    // MARK: - sRGB to OKLCH

    /// Convert SwiftUI Color to OKLCH
    static func fromSRGB(_ color: Color) -> OKLCHColor {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        return fromSRGB(r: Double(r), g: Double(g), b: Double(b))
    }

    /// Convert sRGB components (0-1) to OKLCH
    static func fromSRGB(r: Double, g: Double, b: Double) -> OKLCHColor {
        // Step 1: sRGB to Linear RGB (remove gamma)
        let linearR = srgbToLinear(r)
        let linearG = srgbToLinear(g)
        let linearB = srgbToLinear(b)

        // Step 2: Linear RGB to OKLab
        let lab = linearRGBToOKLab(r: linearR, g: linearG, b: linearB)

        // Step 3: OKLab to OKLCH (polar coordinates)
        return oklabToOKLCH(L: lab.L, a: lab.a, b: lab.b)
    }

    // MARK: - OKLCH to sRGB

    /// Convert OKLCH to SwiftUI Color
    static func toSRGB(_ oklch: OKLCHColor) -> Color {
        let rgb = toSRGBComponents(oklch)
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    /// Convert OKLCH to sRGB components (0-1, gamut-mapped)
    static func toSRGBComponents(_ oklch: OKLCHColor) -> (r: Double, g: Double, b: Double) {
        // Step 1: OKLCH to OKLab
        let lab = oklchToOKLab(L: oklch.lightness, C: oklch.chroma, H: oklch.hue)

        // Step 2: OKLab to Linear RGB
        var rgb = oklabToLinearRGB(L: lab.L, a: lab.a, b: lab.b)

        // Step 3: Gamut mapping (clamp out-of-gamut colors)
        rgb = gamutMap(r: rgb.r, g: rgb.g, b: rgb.b, oklch: oklch)

        // Step 4: Linear RGB to sRGB (apply gamma)
        let sR = linearToSrgb(rgb.r)
        let sG = linearToSrgb(rgb.g)
        let sB = linearToSrgb(rgb.b)

        return (sR, sG, sB)
    }

    // MARK: - Interpolation

    /// Interpolate between two OKLCH colors (perceptually smooth)
    static func interpolate(from: OKLCHColor, to: OKLCHColor, t: Double) -> OKLCHColor {
        let t = max(0, min(1, t))

        // Interpolate lightness and chroma linearly
        let L = from.lightness + (to.lightness - from.lightness) * t
        let C = from.chroma + (to.chroma - from.chroma) * t

        // Interpolate hue through shortest path
        var hueFrom = from.hue
        var hueTo = to.hue

        let hueDiff = hueTo - hueFrom
        if hueDiff > 180 {
            hueFrom += 360
        } else if hueDiff < -180 {
            hueTo += 360
        }

        let H = (hueFrom + (hueTo - hueFrom) * t).truncatingRemainder(dividingBy: 360)

        return OKLCHColor(lightness: L, chroma: C, hue: H < 0 ? H + 360 : H)
    }

    /// Create gradient stops from OKLCH colors
    static func gradientStops(_ colors: [(OKLCHColor, Double)]) -> [Gradient.Stop] {
        colors.map { oklch, location in
            Gradient.Stop(color: toSRGB(oklch), location: location)
        }
    }

    // MARK: - Private Implementation

    /// sRGB component to linear (remove gamma)
    private static func srgbToLinear(_ c: Double) -> Double {
        if c <= 0.04045 {
            return c / 12.92
        } else {
            return pow((c + 0.055) / 1.055, 2.4)
        }
    }

    /// Linear to sRGB component (apply gamma)
    private static func linearToSrgb(_ c: Double) -> Double {
        let clamped = max(0, min(1, c))
        if clamped <= 0.0031308 {
            return clamped * 12.92
        } else {
            return 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
        }
    }

    /// Linear RGB to OKLab
    private static func linearRGBToOKLab(r: Double, g: Double, b: Double) -> (L: Double, a: Double, b: Double) {
        // Matrix multiplication: Linear RGB → LMS
        let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
        let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
        let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

        // Cube root
        let l_ = cbrt(l)
        let m_ = cbrt(m)
        let s_ = cbrt(s)

        // LMS → OKLab
        let L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
        let a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
        let b_val = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

        return (L, a, b_val)
    }

    /// OKLab to Linear RGB
    private static func oklabToLinearRGB(L: Double, a: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        // OKLab → LMS
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b

        // Cube
        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        // LMS → Linear RGB
        let r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let b_val = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return (r, g, b_val)
    }

    /// OKLab to OKLCH (polar coordinates)
    private static func oklabToOKLCH(L: Double, a: Double, b: Double) -> OKLCHColor {
        let C = sqrt(a * a + b * b)
        var H = atan2(b, a) * 180.0 / .pi
        if H < 0 { H += 360 }

        return OKLCHColor(lightness: L, chroma: C, hue: H)
    }

    /// OKLCH to OKLab
    private static func oklchToOKLab(L: Double, C: Double, H: Double) -> (L: Double, a: Double, b: Double) {
        let hRad = H * .pi / 180.0
        let a = C * cos(hRad)
        let b = C * sin(hRad)
        return (L, a, b)
    }

    /// Gamut mapping - handle out-of-sRGB colors by reducing chroma
    private static func gamutMap(r: Double, g: Double, b: Double, oklch: OKLCHColor) -> (r: Double, g: Double, b: Double) {
        // If in gamut, return as-is
        if r >= 0 && r <= 1 && g >= 0 && g <= 1 && b >= 0 && b <= 1 {
            return (r, g, b)
        }

        // Binary search to find maximum chroma that stays in gamut
        var lo: Double = 0
        var hi = oklch.chroma

        for _ in 0..<16 { // 16 iterations for precision
            let mid = (lo + hi) / 2
            let testLab = oklchToOKLab(L: oklch.lightness, C: mid, H: oklch.hue)
            let testRGB = oklabToLinearRGB(L: testLab.L, a: testLab.a, b: testLab.b)

            if testRGB.r >= -0.001 && testRGB.r <= 1.001 &&
               testRGB.g >= -0.001 && testRGB.g <= 1.001 &&
               testRGB.b >= -0.001 && testRGB.b <= 1.001 {
                lo = mid
            } else {
                hi = mid
            }
        }

        // Use the reduced chroma
        let mappedLab = oklchToOKLab(L: oklch.lightness, C: lo, H: oklch.hue)
        let mappedRGB = oklabToLinearRGB(L: mappedLab.L, a: mappedLab.a, b: mappedLab.b)

        return (
            max(0, min(1, mappedRGB.r)),
            max(0, min(1, mappedRGB.g)),
            max(0, min(1, mappedRGB.b))
        )
    }

    /// Cube root that handles negative numbers
    private static func cbrt(_ x: Double) -> Double {
        x >= 0 ? pow(x, 1.0/3.0) : -pow(-x, 1.0/3.0)
    }
}

// MARK: - Color Extension

extension Color {
    /// Convert to OKLCH representation
    var oklch: OKLCHColor {
        OKLCHColorSpace.fromSRGB(self)
    }

    /// Create Color from OKLCH values
    init(oklch: OKLCHColor) {
        self = OKLCHColorSpace.toSRGB(oklch)
    }

    /// Create Color from OKLCH components
    init(lightness: Double, chroma: Double, hue: Double) {
        self.init(oklch: OKLCHColor(lightness: lightness, chroma: chroma, hue: hue))
    }

    /// Enhance color in perceptual OKLCH space
    func enhancedInOKLCH(chromaMultiplier: Double = 1.3, minLightness: Double = 0.45) -> Color {
        self.oklch.enhanced(chromaMultiplier: chromaMultiplier, minLightness: minLightness).color
    }
}

// MARK: - Perceptual Distance

extension OKLCHColor {
    /// Calculate perceptual distance to another color (Delta E in OKLab)
    func distance(to other: OKLCHColor) -> Double {
        // Convert both to OKLab for distance calculation
        let hRad1 = hue * .pi / 180.0
        let a1 = chroma * cos(hRad1)
        let b1 = chroma * sin(hRad1)

        let hRad2 = other.hue * .pi / 180.0
        let a2 = other.chroma * cos(hRad2)
        let b2 = other.chroma * sin(hRad2)

        // Euclidean distance in OKLab space
        let dL = lightness - other.lightness
        let da = a1 - a2
        let db = b1 - b2

        return sqrt(dL * dL + da * da + db * db)
    }

    /// Check if two colors are perceptually similar
    func isSimilar(to other: OKLCHColor, threshold: Double = 0.05) -> Bool {
        distance(to: other) < threshold
    }
}

// MARK: - Debug Description

extension OKLCHColor: CustomStringConvertible {
    var description: String {
        String(format: "OKLCH(L:%.2f C:%.3f H:%.0f°)", lightness, chroma, hue)
    }
}
