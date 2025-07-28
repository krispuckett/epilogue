import SwiftUI

/// Apple Music-style atmospheric gradient background for book views
struct BookAtmosphericGradientView: View {
    let colorPalette: ColorPalette
    
    @State private var gradientOffset: CGFloat = 0
    @State private var displayedPalette: ColorPalette?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black base layer
                Color.black
                    .ignoresSafeArea()
                
                // Multi-color gradient layer - blend all extracted colors
                if let palette = displayedPalette {
                    LinearGradient(
                        stops: [
                            .init(color: palette.primary, location: 0.0),
                            .init(color: palette.secondary, location: 0.2),  // Add secondary!
                            .init(color: palette.accent.opacity(0.7), location: 0.35),
                            .init(color: palette.background.opacity(0.3), location: 0.5),
                            .init(color: Color.clear, location: 0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blur(radius: 40) // Same blur as ambient
                    .ignoresSafeArea()
                }
                
                // Subtle noise texture overlay
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.05) // Very subtle texture
                    .ignoresSafeArea()
                    .blendMode(.plusLighter)
            }
        }
        .onAppear {
            displayedPalette = processColors(colorPalette)
            startSubtleAnimation()
        }
        .onChange(of: colorPalette) { _, newPalette in
            displayedPalette = processColors(newPalette)
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
    
    /// Process colors - enhance them like ambient chat
    private func processColors(_ palette: ColorPalette) -> ColorPalette {
        return ColorPalette(
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
    
    /// Enhance color - EXACT same as ambient chat
    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // EXACT same enhancement as ambient chat
        saturation = min(saturation * 1.4, 1.0)  // Boost vibrancy
        brightness = max(brightness, 0.4)         // Minimum brightness
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }
    
    /// Start subtle 30-second animation
    private func startSubtleAnimation() {
        withAnimation(.easeInOut(duration: 30).repeatForever(autoreverses: true)) {
            gradientOffset = 0.1 // Subtle movement
        }
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