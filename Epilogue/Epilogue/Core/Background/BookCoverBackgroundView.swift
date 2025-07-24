import SwiftUI

// MARK: - Apple Music + Claude Voice Mode Style Gradient
struct BookCoverBackgroundView: View {
    let colorPalette: ColorPalette?
    let displayScheme: DisplayColorScheme?
    
    // Convenience initializers
    init(colorPalette: ColorPalette) {
        self.colorPalette = colorPalette
        self.displayScheme = nil
    }
    
    init(displayScheme: DisplayColorScheme) {
        self.colorPalette = nil
        self.displayScheme = displayScheme
    }
    
    private var primaryColor: Color {
        if let scheme = displayScheme {
            return enhanceColor(scheme.gradientColors.first ?? .black)
        }
        return enhanceColor(colorPalette?.primary ?? .black)
    }
    
    private var secondaryColor: Color {
        if let scheme = displayScheme {
            return enhanceColor(scheme.gradientColors[safe: 1] ?? .gray)
        }
        return enhanceColor(colorPalette?.secondary ?? .gray)
    }
    
    private var accentColor: Color {
        if let scheme = displayScheme {
            return enhanceColor(scheme.gradientColors.last ?? .black)
        }
        return enhanceColor(colorPalette?.accent ?? .black)
    }
    
    private var backgroundColor: Color {
        if let scheme = displayScheme {
            return enhanceColor(scheme.gradientColors[safe: 2] ?? .black)
        }
        return enhanceColor(colorPalette?.background ?? .black)
    }
    
    var body: some View {
        ZStack {
            // Pure black base
            Color.black.ignoresSafeArea()
            
            // Claude-style smooth linear gradient with Apple Music vibrancy
            LinearGradient(
                stops: [
                    // Vibrant colors at top - exactly like Claude voice UI
                    .init(color: primaryColor, location: 0.0),
                    .init(color: primaryColor.opacity(0.85), location: 0.10),
                    .init(color: secondaryColor.opacity(0.7), location: 0.20),
                    .init(color: accentColor.opacity(0.5), location: 0.32),
                    .init(color: backgroundColor.opacity(0.3), location: 0.45),
                    .init(color: Color.black.opacity(0.5), location: 0.58),
                    // Complete fade to black
                    .init(color: Color.black, location: 0.70)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .blur(radius: 45) // More atmospheric blur for softer effect
            
            // Very subtle noise texture overlay for depth
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.05)
                .ignoresSafeArea()
                .blendMode(.plusLighter)
        }
    }
    
    // Make colors vibrant like Apple Music
    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Boost vibrancy significantly for Apple Music effect
        saturation = min(saturation * 1.6, 1.0)
        brightness = max(brightness, 0.5) // Ensure minimum brightness
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }
}

// Note: Array safe subscript is defined elsewhere in the project