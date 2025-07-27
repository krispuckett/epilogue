import SwiftUI

// MARK: - Apple Music + Claude Voice Mode Style Gradient
struct BookCoverBackgroundView: View {
    let colorPalette: ColorPalette?
    let displayScheme: DisplayColorScheme?
    let book: Book?
    @State private var appleMusicPalette: AppleMusicColorPalette?
    
    // Convenience initializers
    init(colorPalette: ColorPalette) {
        self.colorPalette = colorPalette
        self.displayScheme = nil
        self.book = nil
    }
    
    init(displayScheme: DisplayColorScheme) {
        self.colorPalette = nil
        self.displayScheme = displayScheme
        self.book = nil
    }
    
    init(book: Book) {
        self.colorPalette = nil
        self.displayScheme = nil
        self.book = book
    }
    
    var body: some View {
        if let book = book {
            // Use new BookCoverGradientView for books
            BookCoverGradientView(book: book)
        } else {
            // Fallback to existing implementation
            ZStack {
                // Pure black base
                Color.black.ignoresSafeArea()
                
                // Claude-style smooth linear gradient
                if let palette = appleMusicPalette ?? convertToAppleMusicPalette() {
                    LinearGradient(
                        stops: [
                            // Vibrant colors at top
                            .init(color: palette.primary, location: 0.0),
                            .init(color: palette.primary.opacity(0.85), location: 0.08),
                            .init(color: palette.secondary.opacity(0.7), location: 0.15),
                            .init(color: palette.detail.opacity(0.5), location: 0.25),
                            .init(color: palette.background.opacity(0.3), location: 0.35),
                            .init(color: Color.black.opacity(0.5), location: 0.45),
                            .init(color: Color.black, location: 0.65)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .blur(radius: 45)
                    
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.03)
                        .ignoresSafeArea()
                        .blendMode(.plusLighter)
                }
            }
        }
    }
    
    // Convert existing palettes to AppleMusicColorPalette
    private func convertToAppleMusicPalette() -> AppleMusicColorPalette? {
        if let palette = colorPalette {
            return AppleMusicColorPalette(
                background: enhanceColor(palette.background),
                primary: enhanceColor(palette.primary),
                secondary: enhanceColor(palette.secondary),
                detail: enhanceColor(palette.accent)
            )
        } else if let scheme = displayScheme, scheme.gradientColors.count >= 3 {
            return AppleMusicColorPalette(
                background: enhanceColor(scheme.gradientColors[safe: 3] ?? .black),
                primary: enhanceColor(scheme.gradientColors[safe: 0] ?? .black),
                secondary: enhanceColor(scheme.gradientColors[safe: 1] ?? .gray),
                detail: enhanceColor(scheme.gradientColors[safe: 2] ?? .black)
            )
        }
        return nil
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