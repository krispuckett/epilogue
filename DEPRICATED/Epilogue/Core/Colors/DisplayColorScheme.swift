import SwiftUI
import Observation

// MARK: - Single Source of Truth for Display Colors
@Observable
class DisplayColorScheme {
    // Input palette from color extraction
    private let extractedPalette: ColorPalette
    
    // ACTUAL colors being displayed in gradient
    var gradientColors: [Color] = []
    var averageGradientLuminance: Double = 0
    var averageGradientColor: Color = .gray
    
    // Text colors calculated from ACTUAL gradient
    var primaryTextColor: Color {
        // Use proper contrast calculation
        averageGradientLuminance > 0.6 ? .black : .white
    }
    
    var secondaryTextColor: Color {
        primaryTextColor.opacity(0.8)
    }
    
    var accentTextColor: Color {
        // For accent elements, ensure they pop
        if averageGradientLuminance > 0.6 {
            // Light background: use darker version of accent
            return extractedPalette.accent.darkened(by: 0.3)
        } else {
            // Dark background: use lighter version of accent
            return extractedPalette.accent.lightened(by: 0.3)
        }
    }
    
    // Shadow color based on text color
    var textShadowColor: Color {
        primaryTextColor == .black ? .white.opacity(0.5) : .black.opacity(0.5)
    }
    
    init(from palette: ColorPalette) {
        self.extractedPalette = palette
        self.updateGradientColors()
        self.ensureReadability()
    }
    
    // MARK: - Gradient Generation
    
    private func updateGradientColors() {
        // Generate gradient colors that preserve extracted colors but ensure visibility
        gradientColors = generateGradientColors(from: extractedPalette)
        
        // Calculate ACTUAL luminance of gradient
        averageGradientLuminance = calculateAverageLuminance(of: gradientColors)
        averageGradientColor = calculateAverageColor(of: gradientColors)
        
        // Debug logging
        #if DEBUG
        print("🎨 DisplayColorScheme updated:")
        #if DEBUG
        print("  Average luminance: \(String(format: "%.2f", averageGradientLuminance))")
        #endif
        #if DEBUG
        print("  Text color: \(primaryTextColor == .black ? "black" : "white")")
        #endif
        #endif
    }
    
    private func generateGradientColors(from palette: ColorPalette) -> [Color] {
        let baseColors = [palette.primary, palette.secondary, palette.accent, palette.background]
        
        return baseColors.map { color in
            let luminance = luminance(of: color)
            
            // Intelligent color adjustment based on luminance
            if luminance > 0.7 {
                // Already bright - keep mostly as is
                return color.mixed(with: .white, by: 0.1)
            } else if luminance > 0.5 {
                // Medium bright - lighten a bit
                return color.mixed(with: .white, by: 0.3)
            } else if luminance > 0.3 {
                // Medium dark - significantly lighten
                return color.mixed(with: .white, by: 0.5)
            } else {
                // Very dark - heavily lighten
                return color.mixed(with: .white, by: 0.7)
            }
        }
    }
    
    // MARK: - Luminance Calculations
    
    private func luminance(of color: Color) -> Double {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        
        // Use proper luminance formula (ITU-R BT.709)
        return 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    }
    
    private func calculateAverageLuminance(of colors: [Color]) -> Double {
        guard !colors.isEmpty else { return 0.5 }
        
        let totalLuminance = colors.reduce(0.0) { sum, color in
            sum + luminance(of: color)
        }
        
        return totalLuminance / Double(colors.count)
    }
    
    private func calculateAverageColor(of colors: [Color]) -> Color {
        guard !colors.isEmpty else { return .gray }
        
        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        
        for color in colors {
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            totalR += r
            totalG += g
            totalB += b
        }
        
        let count = CGFloat(colors.count)
        return Color(
            red: totalR / count,
            green: totalG / count,
            blue: totalB / count
        )
    }
    
    // MARK: - Contrast Validation
    
    private func validateContrast() -> Bool {
        let contrast = calculateContrast(
            text: primaryTextColor,
            background: averageGradientColor
        )
        
        let meetsWCAG = contrast >= 4.5 // WCAG AA standard
        
        #if DEBUG
        if !meetsWCAG {
            #if DEBUG
            print("⚠️ CONTRAST WARNING: \(String(format: "%.2f", contrast)) (needs 4.5+)")
            #endif
            #if DEBUG
            print("  Text luminance: \(String(format: "%.2f", luminance(of: primaryTextColor)))")
            #endif
            #if DEBUG
            print("  Bg luminance: \(String(format: "%.2f", luminance(of: averageGradientColor)))")
            #endif
        }
        #endif
        
        return meetsWCAG
    }
    
    private func calculateContrast(text: Color, background: Color) -> Double {
        let textLuminance = luminance(of: text)
        let bgLuminance = luminance(of: background)
        
        let lighter = max(textLuminance, bgLuminance)
        let darker = min(textLuminance, bgLuminance)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    // MARK: - Self-Healing System
    
    func ensureReadability() {
        guard !validateContrast() else { return }
        
        #if DEBUG
        print("🔧 Fixing contrast issue...")
        #endif
        
        // First attempt: adjust gradient brightness
        if averageGradientLuminance > 0.5 {
            // Light gradient but poor contrast - make it lighter
            gradientColors = gradientColors.map { $0.lightened(by: 0.2) }
        } else {
            // Dark gradient but poor contrast - make it darker
            gradientColors = gradientColors.map { $0.darkened(by: 0.2) }
        }
        
        // Recalculate
        averageGradientLuminance = calculateAverageLuminance(of: gradientColors)
        averageGradientColor = calculateAverageColor(of: gradientColors)
        
        // If still failing, force high contrast
        if !validateContrast() {
            #if DEBUG
            print("🚨 Forcing high contrast fallback")
            #endif
            if averageGradientLuminance > 0.5 {
                // Force very light gradient
                gradientColors = [
                    Color.white,
                    extractedPalette.accent.mixed(with: .white, by: 0.9),
                    Color(white: 0.95)
                ]
            } else {
                // Force very dark gradient
                gradientColors = [
                    Color.black,
                    extractedPalette.accent.mixed(with: .black, by: 0.9),
                    Color(white: 0.05)
                ]
            }
            
            // Final recalculation
            averageGradientLuminance = calculateAverageLuminance(of: gradientColors)
            averageGradientColor = calculateAverageColor(of: gradientColors)
        }
        
        #if DEBUG
        let finalContrast = calculateContrast(text: primaryTextColor, background: averageGradientColor)
        #if DEBUG
        print("✅ Final contrast: \(String(format: "%.2f", finalContrast))")
        #endif
        #endif
    }
    
    // MARK: - Mesh Gradient Points
    
    func meshGradientColors() -> [Color] {
        // Create a 3x3 grid of colors for MeshGradient
        guard gradientColors.count >= 4 else {
            return Array(repeating: Color.gray, count: 9)
        }
        
        let primary = gradientColors[0]
        let secondary = gradientColors[1]
        let accent = gradientColors[2]
        let background = gradientColors[3]
        
        return [
            // Top row
            primary.lightened(by: 0.1),
            Color.white.opacity(0.9),
            secondary.lightened(by: 0.1),
            
            // Middle row
            secondary,
            accent,
            primary,
            
            // Bottom row
            background,
            accent.darkened(by: 0.1),
            Color.white.opacity(0.8)
        ]
    }
}

// MARK: - Color Extensions

extension Color {
    func lightened(by amount: Double) -> Color {
        self.mixed(with: .white, by: amount)
    }
    
    func darkened(by amount: Double) -> Color {
        self.mixed(with: .black, by: amount)
    }
}

// MARK: - Debug Helpers

#if DEBUG
struct ContrastValidator: ViewModifier {
    let textColor: Color
    let backgroundColor: Color
    @State private var contrast: Double = 0
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                contrast = DisplayColorScheme.calculateContrastStatic(
                    text: textColor,
                    background: backgroundColor
                )
                
                if contrast < 4.5 {
                    #if DEBUG
                    print("⚠️ CONTRAST FAILURE: \(String(format: "%.2f", contrast)) (needs 4.5+)")
                    #endif
                    #if DEBUG
                    print("  Text: \(textColor.description)")
                    #endif
                    #if DEBUG
                    print("  Background: \(backgroundColor.description)")
                    #endif
                }
            }
            .overlay(alignment: .topTrailing) {
                if contrast < 4.5 {
                    Text("⚠️ \(String(format: "%.1f", contrast))")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.red)
                        .cornerRadius(4)
                        .padding(8)
                }
            }
    }
}

extension DisplayColorScheme {
    static func calculateContrastStatic(text: Color, background: Color) -> Double {
        let scheme = DisplayColorScheme(from: ColorPalette(
            primary: .gray,
            secondary: .gray,
            accent: .gray,
            background: .gray,
            textColor: .white,
            luminance: 0.5,
            isMonochromatic: true,
            extractionQuality: 1.0
        ))
        return scheme.calculateContrast(text: text, background: background)
    }
}
#endif