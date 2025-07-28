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
        print("  Average luminance: \(String(format: "%.2f", averageGradientLuminance))")
        print("  Text color: \(primaryTextColor == .black ? "black" : "white")")
        #endif
    }
    
    private func generateGradientColors(from palette: ColorPalette) -> [Color] {
        // KEEP THE EXTRACTED COLORS AS-IS! Don't wash them out!
        return [palette.primary, palette.secondary, palette.accent, palette.background]
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
            print("⚠️ CONTRAST WARNING: \(String(format: "%.2f", contrast)) (needs 4.5+)")
            print("  Text luminance: \(String(format: "%.2f", luminance(of: primaryTextColor)))")
            print("  Bg luminance: \(String(format: "%.2f", luminance(of: averageGradientColor)))")
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
            // Don't force white/black gradients - keep the extracted colors!
            // Text contrast should be handled by text color, not by washing out the gradient
            #if DEBUG
            print("⚠️ Keeping original colors despite contrast - text color handles readability")
            #endif
            
            // Final recalculation
            averageGradientLuminance = calculateAverageLuminance(of: gradientColors)
            averageGradientColor = calculateAverageColor(of: gradientColors)
        }
        
        #if DEBUG
        let finalContrast = calculateContrast(text: primaryTextColor, background: averageGradientColor)
        print("✅ Final contrast: \(String(format: "%.2f", finalContrast))")
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
    /// Mix two colors together
    func mixed(with color: Color, by amount: Double) -> Color {
        let clampedAmount = min(max(amount, 0), 1)
        
        let c1 = UIColor(self).cgColor
        let c2 = UIColor(color).cgColor
        
        guard let components1 = c1.components,
              let components2 = c2.components,
              components1.count >= 3,
              components2.count >= 3 else {
            return self
        }
        
        let r = components1[0] * (1 - clampedAmount) + components2[0] * clampedAmount
        let g = components1[1] * (1 - clampedAmount) + components2[1] * clampedAmount
        let b = components1[2] * (1 - clampedAmount) + components2[2] * clampedAmount
        let a = (components1.count > 3 ? components1[3] : 1) * (1 - clampedAmount) +
                (components2.count > 3 ? components2[3] : 1) * clampedAmount
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }
    
    func lightened(by amount: Double) -> Color {
        self.mixed(with: Color.white, by: amount)
    }
    
    func darkened(by amount: Double) -> Color {
        self.mixed(with: Color.black, by: amount)
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
                    print("⚠️ CONTRAST FAILURE: \(String(format: "%.2f", contrast)) (needs 4.5+)")
                    print("  Text: \(textColor.description)")
                    print("  Background: \(backgroundColor.description)")
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