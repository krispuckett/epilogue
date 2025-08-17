import SwiftUI
import UIKit

/// Intelligent accent color system that adapts book colors for optimal UI presentation
/// Designed to maintain the book's character while ensuring beautiful, usable interfaces
struct SmartAccentColor {
    
    // MARK: - Color Analysis
    
    /// Analyzes a color's suitability for UI use
    static func analyzeColorSuitability(_ color: Color) -> ColorAnalysis {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Convert hue to degrees
        let hueDegrees = hue * 360
        
        // Determine color zone
        let zone = determineColorZone(hue: hueDegrees, saturation: saturation, brightness: brightness)
        
        // Calculate suitability score (0-1)
        let score = calculateSuitabilityScore(zone: zone, saturation: saturation, brightness: brightness)
        
        return ColorAnalysis(
            color: color,
            hue: hueDegrees,
            saturation: saturation,
            brightness: brightness,
            zone: zone,
            suitabilityScore: score,
            isSuitable: score > 0.6
        )
    }
    
    /// Determines which color zone a hue falls into
    private static func determineColorZone(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> ColorZone {
        // Handle achromatic colors first
        if saturation < 0.1 {
            if brightness > 0.8 {
                return .white
            } else if brightness < 0.3 {
                return .black
            } else {
                return .gray
            }
        }
        
        // Chromatic colors
        switch hue {
        case 0..<15, 345..<360:
            return .red
        case 15..<45:
            return .orange
        case 45..<65:
            return .yellow
        case 65..<150:
            return .green
        case 150..<200:
            return .cyan
        case 200..<260:
            return .blue
        case 260..<290:
            return .purple
        case 290..<345:
            return .magenta
        default:
            return .neutral
        }
    }
    
    /// Calculates how suitable a color is for UI use (0-1)
    private static func calculateSuitabilityScore(zone: ColorZone, saturation: CGFloat, brightness: CGFloat) -> CGFloat {
        var score: CGFloat = 1.0
        
        // Zone-based scoring
        switch zone {
        case .blue, .cyan, .purple:
            // These are naturally harmonious
            score = 1.0
        case .green:
            // Green is good if not too saturated
            score = saturation < 0.7 ? 0.9 : 0.6
        case .orange:
            // Orange can work if muted
            score = saturation < 0.6 ? 0.8 : 0.5
        case .red, .magenta:
            // Red is problematic - looks like errors
            score = 0.3
        case .yellow:
            // Yellow is hard to use on dark backgrounds
            score = 0.4
        case .gray, .neutral:
            // Neutral colors are fine
            score = 0.7
        case .black, .white:
            // Pure black/white need our fallback
            score = 0.2
        }
        
        // Penalize extreme saturation
        if saturation > 0.85 {
            score *= 0.6
        } else if saturation < 0.2 && zone != .gray {
            score *= 0.8
        }
        
        // Penalize darkness (won't show on dark UI)
        if brightness < 0.4 {
            score *= 0.5
        } else if brightness > 0.95 {
            score *= 0.7
        }
        
        return score
    }
    
    // MARK: - Color Transformation
    
    /// Gets the smart accent color for a book
    static func getSmartAccent(from palette: ColorPalette?) -> Color {
        guard let palette = palette else {
            return defaultAccent
        }
        
        // Try colors in order of preference
        let candidates = [
            palette.accent,
            palette.secondary,
            palette.primary
        ].compactMap { $0 }
        
        for candidate in candidates {
            let analysis = analyzeColorSuitability(candidate)
            
            if analysis.isSuitable {
                // Use the color but ensure minimum brightness
                return ensureMinimumBrightness(candidate, minimum: 0.5)
            } else if analysis.suitabilityScore > 0.4 {
                // Try to transform it into something usable
                if let transformed = transformToSuitable(candidate, analysis: analysis) {
                    return transformed
                }
            }
        }
        
        // If all else fails, use default but try to match temperature
        return getTemperatureMatchedDefault(palette: palette)
    }
    
    /// Transforms a problematic color into a suitable one
    private static func transformToSuitable(_ color: Color, analysis: ColorAnalysis) -> Color? {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        switch analysis.zone {
        case .red:
            // Shift red to warm coral/orange
            hue = 0.08 // About 30 degrees (orange territory)
            saturation = min(saturation, 0.65)
            brightness = max(brightness, 0.6)
            
        case .magenta:
            // Shift magenta to purple
            hue = 0.75 // Purple
            saturation = min(saturation, 0.6)
            
        case .yellow:
            // Shift yellow to amber
            hue = 0.11 // Amber
            saturation = min(saturation, 0.7)
            brightness = min(brightness, 0.7)
            
        case .green:
            // Desaturate green
            saturation = min(saturation, 0.5)
            brightness = max(brightness, 0.5)
            
        default:
            // For other colors, just adjust saturation and brightness
            saturation = min(saturation, 0.7)
            brightness = max(brightness, 0.5)
        }
        
        return Color(hue: hue, saturation: saturation, brightness: brightness, opacity: alpha)
    }
    
    /// Ensures a color has minimum brightness for visibility
    private static func ensureMinimumBrightness(_ color: Color, minimum: CGFloat) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        if brightness < minimum {
            brightness = minimum
        }
        
        return Color(hue: hue, saturation: saturation, brightness: brightness, opacity: alpha)
    }
    
    /// Gets a default accent that matches the book's color temperature
    private static func getTemperatureMatchedDefault(palette: ColorPalette) -> Color {
        // Analyze if the book is warm or cool toned
        let primary = palette.primary
        let analysis = analyzeColorSuitability(primary)
        
        // Cool tones - use a muted blue
        if [.blue, .cyan, .green, .purple].contains(analysis.zone) {
            return Color(hue: 0.58, saturation: 0.4, brightness: 0.7) // Muted blue
        }
        
        // Default to warm orange
        return defaultAccent
    }
    
    // MARK: - Constants
    
    /// Default accent color (warm orange)
    static let defaultAccent = Color(red: 1.0, green: 0.55, blue: 0.26)
    
    // MARK: - Debug
    
    /// Debug description of color analysis
    static func debugAnalysis(_ analysis: ColorAnalysis) -> String {
        """
        🎨 Color Analysis:
        Zone: \(analysis.zone)
        Hue: \(Int(analysis.hue))°
        Saturation: \(String(format: "%.2f", analysis.saturation))
        Brightness: \(String(format: "%.2f", analysis.brightness))
        Score: \(String(format: "%.2f", analysis.suitabilityScore))
        Suitable: \(analysis.isSuitable ? "✅" : "❌")
        """
    }
}

// MARK: - Supporting Types

struct ColorAnalysis {
    let color: Color
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat
    let zone: ColorZone
    let suitabilityScore: CGFloat
    let isSuitable: Bool
}

enum ColorZone {
    case red
    case orange
    case yellow
    case green
    case cyan
    case blue
    case purple
    case magenta
    case gray
    case black
    case white
    case neutral
    
    var description: String {
        switch self {
        case .red: return "Red (Problematic)"
        case .orange: return "Orange (Warm)"
        case .yellow: return "Yellow (Bright)"
        case .green: return "Green (Natural)"
        case .cyan: return "Cyan (Cool)"
        case .blue: return "Blue (Harmonious)"
        case .purple: return "Purple (Elegant)"
        case .magenta: return "Magenta (Vibrant)"
        case .gray: return "Gray (Neutral)"
        case .black: return "Black (Dark)"
        case .white: return "White (Light)"
        case .neutral: return "Neutral"
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies smart accent color with optional debug info
    func smartAccent(from palette: ColorPalette?, debug: Bool = false) -> some View {
        let accent = SmartAccentColor.getSmartAccent(from: palette)
        
        if debug {
            print("🎨 Smart Accent: \(accent)")
            if let palette = palette {
                let original = palette.accent ?? palette.primary
                let analysis = SmartAccentColor.analyzeColorSuitability(original)
                print(SmartAccentColor.debugAnalysis(analysis))
            }
        }
        
        return self.foregroundStyle(accent)
    }
}