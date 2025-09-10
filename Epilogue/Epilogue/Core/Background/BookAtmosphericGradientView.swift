import SwiftUI

/// Apple Music-style atmospheric gradient background for book views
struct BookAtmosphericGradientView: View {
    let colorPalette: ColorPalette
    let intensity: Double
    let audioLevel: Float
    
    @State private var gradientOffset: CGFloat = 0
    @State private var displayedPalette: ColorPalette?
    
    init(colorPalette: ColorPalette, intensity: Double = 1.0, audioLevel: Float = 0) {
        self.colorPalette = colorPalette
        self.intensity = intensity
        self.audioLevel = audioLevel
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black base layer
                Color.black
                    .ignoresSafeArea()
                
                // Single direction gradient - no mirroring, with intensity control
                if let palette = displayedPalette {
                    // More vibrant gradient like ambient chat
                    LinearGradient(
                        stops: [
                            // Place warm accent at the top for correct look (amber/gold first)
                            .init(color: palette.accent.opacity(0.8 * intensity), location: 0.0),
                            .init(color: palette.primary.opacity(0.6 * intensity), location: 0.15),
                            .init(color: palette.secondary.opacity(0.4 * intensity), location: 0.3),
                            .init(color: palette.background.opacity(0.2 * intensity), location: 0.45),
                            .init(color: Color.clear, location: 0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blur(radius: 30) // Slightly less blur for more definition
                    .ignoresSafeArea()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.3), value: palette.primary)
                }
                
                // Overlay removed to avoid muting the gradient
            }
        }
        .onAppear {
            #if DEBUG
            let LOG_GRADIENT = false
            if LOG_GRADIENT {
                print("🌈 BookAtmosphericGradientView.onAppear")
                print("   Initial palette: \(colorDescription(colorPalette))")
            }
            #endif
            // Re-enable enhancement pipeline for vibrancy
            displayedPalette = processColors(colorPalette)
            #if DEBUG
            if LOG_GRADIENT {
                print("   Processed palette: \(colorDescription(displayedPalette ?? colorPalette))")
            }
            #endif
            startSubtleAnimation()
        }
        .onChange(of: colorPalette) { oldPalette, newPalette in
            #if DEBUG
            let LOG_GRADIENT = false
            if LOG_GRADIENT {
                print("🌈 BookAtmosphericGradientView palette changed")
                print("   Old: \(colorDescription(oldPalette))")
                print("   New: \(colorDescription(newPalette))")
            }
            #endif
            withAnimation(.easeInOut(duration: 0.3)) {
                displayedPalette = processColors(newPalette)
                #if DEBUG
                if LOG_GRADIENT {
                    print("   Processed: \(colorDescription(displayedPalette ?? newPalette))")
                }
                #endif
            }
        }
    }
    
    /// Create gradient stops with non-linear distribution
    private func createGradientStops(from palette: ColorPalette) -> [Gradient.Stop] {
        let colors = getProcessedColors(from: palette)
        
        // Extremely light and simple gradient
        return [
            .init(color: colors.primary.opacity(0.3), location: 0.0),
            .init(color: colors.primary.opacity(0.15), location: 0.2),
            .init(color: Color.clear, location: 0.5)
        ]
    }
    
    /// Get processed colors with proper contrast
    private func getProcessedColors(from palette: ColorPalette) -> (primary: Color, secondary: Color, accent: Color, background: Color) {
        // For monochromatic palettes, ensure we have variation
        if palette.isMonochromatic {
            return createMonochromaticVariations(from: palette.primary)
        }
        
        // Ensure minimum brightness differences
        var colors = [palette.primary, palette.secondary, palette.accent, palette.background]
        colors = ensureContrast(colors)
        
        return (colors[0], colors[1], colors[2], colors[3])
    }
    
    /// Create subtle variations for monochromatic covers
    private func createMonochromaticVariations(from baseColor: Color) -> (primary: Color, secondary: Color, accent: Color, background: Color) {
        let uiColor = UIColor(baseColor)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Create variations with subtle hue shifts
        let primary = baseColor
        let secondary = Color(hue: Double(hue + 0.02), saturation: Double(saturation * 0.8), brightness: Double(brightness * 0.9))
        let accent = Color(hue: Double(hue - 0.02), saturation: Double(saturation * 0.9), brightness: Double(brightness * 0.8))
        let background = Color(hue: Double(hue), saturation: Double(saturation * 0.6), brightness: Double(brightness * 0.6))
        
        return (primary, secondary, accent, background)
    }
    
    /// Ensure minimum 30% brightness difference between colors
    private func ensureContrast(_ colors: [Color]) -> [Color] {
        var processedColors = colors
        let minDifference: CGFloat = 0.3
        
        for i in 1..<processedColors.count {
            let prevBrightness = getBrightness(processedColors[i-1])
            var currBrightness = getBrightness(processedColors[i])
            
            // If too similar, adjust brightness
            if abs(prevBrightness - currBrightness) < minDifference {
                if prevBrightness > 0.5 {
                    // Make current darker
                    currBrightness = max(0, prevBrightness - minDifference)
                } else {
                    // Make current lighter
                    currBrightness = min(1, prevBrightness + minDifference)
                }
                
                processedColors[i] = adjustBrightness(processedColors[i], to: currBrightness)
            }
        }
        
        return processedColors
    }
    
    /// Get brightness value from color
    private func getBrightness(_ color: Color) -> CGFloat {
        let uiColor = UIColor(color)
        var brightness: CGFloat = 0
        uiColor.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
        return brightness
    }
    
    /// Adjust color brightness to target value
    private func adjustBrightness(_ color: Color, to targetBrightness: CGFloat) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(targetBrightness), opacity: Double(alpha))
    }
    
    /// Process colors - enhance them like ambient chat, but keep dark backgrounds dark
    private func processColors(_ palette: ColorPalette) -> ColorPalette {
        return ColorPalette(
            primary: enhanceColor(palette.primary),
            secondary: enhanceColor(palette.secondary),
            accent: enhanceColor(palette.accent),
            background: enhanceBackground(palette.background),
            textColor: palette.textColor,
            luminance: palette.luminance,
            isMonochromatic: palette.isMonochromatic,
            extractionQuality: palette.extractionQuality
        )
    }
    
    /// Enhance color - EXACT same as ambient chat
    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Boost vibrancy with a sensible floor (matches prior correct behavior)
        saturation = min(saturation * 1.4, 1.0)
        if !(saturation < 0.18 && brightness < 0.35) {
            brightness = max(brightness, 0.4)
        }
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }

    /// Background enhancer that preserves dark mood
    private func enhanceBackground(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        // Slight saturation lift, keep depth by bounding brightness
        let outS = min(s * 1.2, 1.0)
        let outB = min(max(b, 0.18), 0.33)
        return Color(hue: Double(h), saturation: Double(outS), brightness: Double(outB))
    }
    
    /// Start subtle 30-second animation
    private func startSubtleAnimation() {
        withAnimation(.easeInOut(duration: 30).repeatForever(autoreverses: true)) {
            gradientOffset = 0.1 // Subtle movement
        }
    }
    
    /// Debug helper
    private func colorDescription(_ palette: ColorPalette) -> String {
        func rgbString(_ color: Color) -> String {
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            return "RGB(\(Int(r*255)),\(Int(g*255)),\(Int(b*255)))"
        }
        return "P:\(rgbString(palette.primary)) S:\(rgbString(palette.secondary)) A:\(rgbString(palette.accent)) B:\(rgbString(palette.background)) mono:\(palette.isMonochromatic)"
    }
}

// MARK: - Convenience Transition

/// Temporary typealias for easier migration
typealias BookGradientView = BookAtmosphericGradientView

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
