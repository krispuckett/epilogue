import SwiftUI

struct BookCoverBackgroundView: View {
    let colorPalette: ColorPalette
    
    // Process colors for monochromatic safety
    private var processedPalette: ColorPalette {
        processColors(colorPalette)
    }
    
    private var enhancedPrimary: Color {
        enhanceColor(processedPalette.primary)
    }
    
    private var enhancedSecondary: Color {
        enhanceColor(processedPalette.secondary)
    }
    
    private var enhancedAccent: Color {
        enhanceColor(processedPalette.accent)
    }
    
    var body: some View {
        ZStack {
            // Pure black base layer
            Color.black
                .ignoresSafeArea()
            
            // More visible gradient with stronger colors
            LinearGradient(
                stops: [
                    .init(color: enhancedPrimary, location: 0.0),
                    .init(color: enhancedPrimary.opacity(0.9), location: 0.08),    // Was 0.85
                    .init(color: enhancedSecondary.opacity(0.8), location: 0.15),   // Was 0.7
                    .init(color: enhancedAccent.opacity(0.6), location: 0.25),      // Was 0.5
                    .init(color: processedPalette.background.opacity(0.4), location: 0.35), // Was 0.3
                    .init(color: Color.black.opacity(0.6), location: 0.45),         // Was 0.5
                    .init(color: Color.black, location: 0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .blur(radius: 40) // EXACTLY 40
            
            // Extra radial glow at top
            VStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                enhancedPrimary.opacity(0.3),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 60) // EXACTLY 60
                    .offset(y: -200)
                
                Spacer()
            }
            .ignoresSafeArea()
            
            // Subtle noise texture overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.03) // EXACTLY 0.03
                .ignoresSafeArea()
                .blendMode(.plusLighter)
        }
    }
    
    // MORE aggressive enhancement for vibrant colors
    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // MORE aggressive enhancement
        saturation = min(saturation * 2.0, 1.0)  // Was 1.6, now 2.0
        brightness = max(brightness, 0.7)         // Was 0.6, now 0.7
        
        // Extra boost for very dark colors
        if brightness < 0.3 {
            brightness = brightness + 0.4
        }
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }
    
    // Simple monochromatic safety check
    private func processColors(_ palette: ColorPalette) -> ColorPalette {
        // Get hues of primary, secondary, accent
        let primaryHue = getHue(palette.primary)
        let secondaryHue = getHue(palette.secondary)
        let accentHue = getHue(palette.accent)
        
        // Check if all within 0.1 range (monochromatic)
        let hues = [primaryHue, secondaryHue, accentHue]
        let minHue = hues.min() ?? 0
        let maxHue = hues.max() ?? 0
        
        // Handle hue wrap-around (red at 0/360)
        let isMonochromatic = (maxHue - minHue) < 0.1 || 
                             (minHue < 0.1 && maxHue > 0.9) // red wrap-around
        
        if isMonochromatic {
            // Create variations of primary color
            return ColorPalette(
                primary: palette.primary,
                secondary: lightenColor(palette.primary, by: 0.2),
                accent: darkenColor(palette.primary, by: 0.2),
                background: darkenColor(palette.primary, by: 0.4),
                textColor: .white,
                luminance: palette.luminance,
                isMonochromatic: true,
                extractionQuality: palette.extractionQuality
            )
        }
        
        // Check for outlier (e.g., red in The Odyssey)
        let hueDiffs = [
            abs(primaryHue - secondaryHue),
            abs(secondaryHue - accentHue),
            abs(primaryHue - accentHue)
        ]
        
        // If one color is very different from the others
        if let maxDiff = hueDiffs.max(), maxDiff > 0.3 {
            // Find the outlier
            if hueDiffs[0] > 0.3 && hueDiffs[2] > 0.3 {
                // Secondary is outlier, replace with variation of primary
                return ColorPalette(
                    primary: palette.primary,
                    secondary: lightenColor(palette.primary, by: 0.15),
                    accent: palette.accent,
                    background: palette.background,
                    textColor: .white,
                    luminance: palette.luminance,
                    isMonochromatic: false,
                    extractionQuality: palette.extractionQuality
                )
            } else if hueDiffs[1] > 0.3 && hueDiffs[2] > 0.3 {
                // Accent is outlier, replace with variation of primary
                return ColorPalette(
                    primary: palette.primary,
                    secondary: palette.secondary,
                    accent: darkenColor(palette.primary, by: 0.15),
                    background: palette.background,
                    textColor: .white,
                    luminance: palette.luminance,
                    isMonochromatic: false,
                    extractionQuality: palette.extractionQuality
                )
            }
        }
        
        // Otherwise return original palette
        return palette
    }
    
    private func getHue(_ color: Color) -> CGFloat {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return hue
    }
    
    private func lightenColor(_ color: Color, by amount: CGFloat) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return Color(hue: Double(hue), 
                    saturation: Double(max(0, saturation - amount)), 
                    brightness: Double(min(1, brightness + amount)))
    }
    
    private func darkenColor(_ color: Color, by amount: CGFloat) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return Color(hue: Double(hue), 
                    saturation: Double(min(1, saturation + amount * 0.5)), 
                    brightness: Double(max(0, brightness - amount)))
    }
}