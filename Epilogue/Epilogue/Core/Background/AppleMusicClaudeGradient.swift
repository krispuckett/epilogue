import SwiftUI
// TODO: Add UIImageColors via SPM - see ADD_UIIMAGECOLORS.md

// MARK: - Main Gradient View
struct BookCoverGradientView: View {
    let book: Book
    @State private var colorPalette: AppleMusicColorPalette?
    
    var body: some View {
        ZStack {
            // Black base layer
            Color.black.ignoresSafeArea()
            
            // Claude-style smooth linear gradient
            if let palette = colorPalette {
                LinearGradient(
                    stops: [
                        // Vibrant colors at top
                        .init(color: palette.primary, location: 0.0),
                        .init(color: palette.primary.opacity(0.85), location: 0.08),
                        .init(color: palette.secondary.opacity(0.7), location: 0.15),
                        .init(color: palette.detail.opacity(0.5), location: 0.25),
                        .init(color: palette.background.opacity(0.3), location: 0.35),
                        .init(color: Color.black.opacity(0.5), location: 0.45),
                        // Complete fade to black - slightly lower for more color coverage
                        .init(color: Color.black, location: 0.65)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .blur(radius: 45) // More atmospheric blur
                
                // Optional: Very subtle noise texture overlay
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.03)
                    .ignoresSafeArea()
                    .blendMode(.plusLighter)
            }
        }
        .task {
            await extractColors()
        }
    }
    
    private func extractColors() async {
        guard let coverURL = book.coverImageURL else { return }
        
        // Force high quality image
        let highQualityURL = coverURL
            .replacingOccurrences(of: "zoom=1", with: "zoom=3")
            .replacingOccurrences(of: "zoom=2", with: "zoom=3")
        
        guard let url = URL(string: highQualityURL),
              let data = try? await URLSession.shared.data(from: url).0,
              let image = UIImage(data: data) else { return }
        
        // Extract colors using OKLAB for now (TODO: Replace with UIImageColors)
        let extractor = OKLABColorExtractor()
        
        do {
            let palette = try await extractor.extractPalette(from: image, imageSource: book.title)
            
            await MainActor.run {
                // Use OKLAB palette colors
                let primaryUI = UIColor(palette.primary)
                let secondaryUI = UIColor(palette.secondary)
                let detailUI = UIColor(palette.accent)
                let backgroundUI = UIColor(palette.background)
                
                // Create enhanced colors
                var finalPrimary = enhanceColor(palette.primary)
                var finalSecondary = enhanceColor(palette.secondary)
                var finalDetail = enhanceColor(palette.accent)
                let finalBackground = enhanceColor(palette.background)
                
                // Check color harmony and adjust if needed
                if !colorsAreHarmonious(primaryUI, detailUI) {
                    // If detail doesn't harmonize with primary, use secondary instead
                    finalDetail = finalSecondary
                }
                
                // Ensure we have vibrant colors (filter out grays)
                let vibrantColors = filterBoringColors([primaryUI, secondaryUI, detailUI])
                if vibrantColors.count >= 2 {
                    finalPrimary = enhanceColor(Color(vibrantColors[0]))
                    finalSecondary = enhanceColor(Color(vibrantColors[1]))
                    if vibrantColors.count >= 3 {
                        finalDetail = enhanceColor(Color(vibrantColors[2]))
                    }
                }
                
                withAnimation(.easeInOut(duration: 0.8)) {
                    colorPalette = AppleMusicColorPalette(
                        background: finalBackground,
                        primary: finalPrimary,
                        secondary: finalSecondary,
                        detail: finalDetail
                    )
                }
                
                #if DEBUG
                print("🎨 Extracted colors for \(book.title):")
                print("  Primary: \(primaryUI.hexString)")
                print("  Secondary: \(secondaryUI.hexString)")
                print("  Detail: \(detailUI.hexString)")
                print("  Background: \(backgroundUI.hexString)")
                #endif
            }
        } catch {
            print("❌ Failed to extract colors: \(error)")
        }
    }
    
    // Make colors vibrant like Claude's UI
    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Boost vibrancy significantly
        saturation = min(saturation * 1.6, 1.0)
        brightness = max(brightness, 0.5) // Ensure minimum brightness
        
        return Color(hue: Double(hue), saturation: Double(saturation), brightness: Double(brightness))
    }
    
    // Check if colors are harmonious (within 60 degrees on color wheel)
    private func colorsAreHarmonious(_ color1: UIColor, _ color2: UIColor) -> Bool {
        var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0
        var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0
        
        color1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: nil)
        color2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: nil)
        
        // Check if hues are within 60 degrees (adjacent colors on color wheel)
        let hueDiff = abs(h1 - h2)
        return hueDiff < 0.167 || hueDiff > 0.833 // 60/360 = 0.167
    }
    
    // Filter out boring gray colors
    private func filterBoringColors(_ colors: [UIColor]) -> [UIColor] {
        return colors.filter { color in
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            color.getHue(nil, saturation: &saturation, brightness: &brightness, alpha: nil)
            
            // Reject grays (low saturation) unless we have nothing else
            return saturation > 0.2 || colors.count < 4
        }.sorted { color1, color2 in
            // Sort by vibrancy (saturation * brightness)
            var s1: CGFloat = 0, b1: CGFloat = 0
            var s2: CGFloat = 0, b2: CGFloat = 0
            color1.getHue(nil, saturation: &s1, brightness: &b1, alpha: nil)
            color2.getHue(nil, saturation: &s2, brightness: &b2, alpha: nil)
            return (s1 * b1) > (s2 * b2)
        }
    }
}

// MARK: - Color Palette Model
struct AppleMusicColorPalette {
    let background: Color
    let primary: Color
    let secondary: Color
    let detail: Color
}

// MARK: - Extension for existing BookCoverBackgroundView
extension BookCoverBackgroundView {
    static func modernGradient(from palette: AppleMusicColorPalette?) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let palette = palette {
                LinearGradient(
                    stops: [
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

// MARK: - UIColor Extension for hex strings
extension UIColor {
    var hexString: String {
        guard let components = cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
}