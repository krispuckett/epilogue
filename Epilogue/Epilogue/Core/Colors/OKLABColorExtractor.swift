import SwiftUI
import UIKit
import Vision
import CoreImage
import Accelerate
import CryptoKit

// MARK: - ColorPalette Output Structure
public struct ColorPalette: Equatable {
    let primary: Color           // Most dominant color
    let secondary: Color         // Second most dominant
    let accent: Color           // Most vibrant/saturated
    let background: Color       // For gradients
    let textColor: Color        // Calculated for contrast
    let luminance: Double       // Overall brightness (0-1)
    let isMonochromatic: Bool   // True if image lacks color variety
    let extractionQuality: Double // Confidence score (0-1)
    
    // Helper to get UIColors
    var uiColors: (primary: UIColor, secondary: UIColor, accent: UIColor, background: UIColor) {
        return (
            UIColor(primary),
            UIColor(secondary),
            UIColor(accent),
            UIColor(background)
        )
    }
}

// MARK: - Main Color Extractor
@MainActor
public class OKLABColorExtractor {
    
    public init() {}
    
    /// Extract color palette from UIImage
    public func extractPalette(from image: UIImage, imageSource: String = "Unknown") async throws -> ColorPalette {
        
        // Calculate checksum
        let checksum = calculateChecksum(for: image)
        // print("🔐 EXTRACTED Image checksum: \(checksum)")
        
        // Save for debugging
        saveImageForDebug(image, suffix: "EXTRACTED_\(imageSource)")
        
        // Check image size to detect cropped covers
        if image.size.width < 100 || image.size.height < 100 {
            print("⚠️ WARNING: Image too small (\(image.size.width)x\(image.size.height)), likely cropped!")
            print("   This may be caused by zoom parameter in the URL")
            print("   Consider using zoom=1 or removing zoom parameter entirely")
        }
        
        // 1. SAMPLE EVERY PIXEL (with smart downsampling)
        let targetSize = CGSize(width: 100, height: 100)  // Small enough to process every pixel
        guard let resized = await image.resized(to: targetSize) else {
        // print("❌ Failed to resize image")
            return createFallbackPalette()
        }
        
        guard let cgImage = resized.cgImage else {
        // print("❌ No CGImage available")
            return createFallbackPalette()
        }
        
        // 2. Properly extract pixel data
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        // CRITICAL: Use bytesPerRow from the image, not calculated!
        let bytesPerRow = cgImage.bytesPerRow
        let bitsPerComponent = 8
        
        // print("📐 Processing image: \(width)x\(height) pixels")
        
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
        // print("❌ Failed to create bitmap context")
            return createFallbackPalette()
        }
        
        // Draw the image into our context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // DEBUG: Check what we actually drew
        print("\n🔍 PIXEL DEBUG for \(imageSource):")
        print("  Image size: \(width)x\(height)")
        print("  BytesPerRow: \(bytesPerRow) (calculated: \(width * bytesPerPixel))")
        
        // Check center pixel and corners
        let testPoints = [
            (x: width/2, y: height/2, label: "CENTER"),
            (x: 10, y: 10, label: "TOP-LEFT"),
            (x: width-10, y: 10, label: "TOP-RIGHT"),
            (x: 10, y: height-10, label: "BOTTOM-LEFT"),
            (x: width-10, y: height-10, label: "BOTTOM-RIGHT"),
            (x: width/4, y: height/2, label: "LEFT-CENTER"),
            (x: width*3/4, y: height/2, label: "RIGHT-CENTER")
        ]
        
        for point in testPoints {
            let offset = (point.y * bytesPerRow) + (point.x * bytesPerPixel)
            if offset + 3 < pixelData.count {
                let r = pixelData[offset]
                let g = pixelData[offset + 1]
                let b = pixelData[offset + 2]
                let a = pixelData[offset + 3]
                
                // Convert to hex for easier reading
                let hex = String(format: "#%02X%02X%02X", r, g, b)
                
                // Calculate hue
                let rf = CGFloat(r) / 255.0
                let gf = CGFloat(g) / 255.0
                let bf = CGFloat(b) / 255.0
                var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0
                UIColor(red: rf, green: gf, blue: bf, alpha: 1).getHue(&hue, saturation: &sat, brightness: &bri, alpha: nil)
                
                print("  \(point.label) (\(point.x),\(point.y)): RGB(\(r),\(g),\(b)) \(hex) H:\(Int(hue*360))° S:\(String(format: "%.2f", sat)) B:\(String(format: "%.2f", bri))")
            }
        }
        
        // 3. BUILD COLOR HISTOGRAM (no averaging!)
        var colorHistogram: [UIColor: Int] = [:]
        var totalPixelsProcessed = 0
        var skippedWhite = 0
        var skippedBlack = 0
        var skippedTransparent = 0
        
        for y in 0..<height {
            for x in 0..<width {
                // CRITICAL FIX: Use bytesPerRow, not width * bytesPerPixel
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                
                // Check bounds
                guard offset + 3 < pixelData.count else { continue }
                let r = pixelData[offset]
                let g = pixelData[offset + 1]
                let b = pixelData[offset + 2]
                let a = pixelData[offset + 3]
                
                // Debug first 10 pixels
                if totalPixelsProcessed < 10 {
        // print("  Pixel \(totalPixelsProcessed): R=\(r) G=\(g) B=\(b) A=\(a)")
                }
                
                totalPixelsProcessed += 1
                
                // Skip transparent pixels
                if a < 128 {
                    skippedTransparent += 1
                    continue
                }
                
                // Convert to normalized values
                let rf = CGFloat(r) / 255.0
                let gf = CGFloat(g) / 255.0
                let bf = CGFloat(b) / 255.0
                
                // 4. SMART FILTERING
                // Skip pure white/near-white
                if rf > 0.95 && gf > 0.95 && bf > 0.95 {
                    skippedWhite += 1
                    continue
                }
                
                // Skip pure black pixels
                // But be careful not to skip very dark colors (dark reds, browns)
                let totalBrightness = Int(r) + Int(g) + Int(b)
                if totalBrightness < 15 {  // Only skip if VERY close to black
                    skippedBlack += 1
                    continue
                }
                
                // Also skip very dark pixels that are nearly black
                if rf < 0.1 && gf < 0.1 && bf < 0.1 {
                    skippedBlack += 1
                    continue
                }
                
                // 5. COLOR QUANTIZATION (group similar colors)
                // Round to nearest 0.1 (10 levels per channel) for finer distinction
                let quantizedR = round(rf * 10) / 10
                let quantizedG = round(gf * 10) / 10
                let quantizedB = round(bf * 10) / 10
                
                let color = UIColor(red: quantizedR, green: quantizedG, blue: quantizedB, alpha: 1.0)
                colorHistogram[color, default: 0] += 1
            }
        }
        
        print("\n📊 Pixel Processing Summary:")
        print("  Total pixels: \(totalPixelsProcessed)")
        print("  Skipped white: \(skippedWhite)")
        print("  Skipped black: \(skippedBlack)")
        print("  Skipped transparent: \(skippedTransparent)")
        print("  Colors found: \(colorHistogram.count)")
        
        // DEBUG: Show top 10 colors found
        print("\n🎨 Top 10 colors by frequency:")
        let sortedColors = colorHistogram.sorted { $0.value > $1.value }.prefix(10)
        for (index, (color, count)) in sortedColors.enumerated() {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            
            let hex = String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
            
            var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0
            color.getHue(&hue, saturation: &sat, brightness: &bri, alpha: nil)
            
            print("  \(index+1). \(hex) (H:\(Int(hue*360))° S:\(String(format: "%.2f", sat)) B:\(String(format: "%.2f", bri))) - \(count) pixels")
        }
        
        // Quality detection
        let blackPercentage = Double(skippedBlack) * 100.0 / Double(totalPixelsProcessed)
        if blackPercentage > 70 {
            print("  ⚠️ WARNING: \(String(format: "%.1f", blackPercentage))% of image is black!")
            print("  This suggests a low-quality image with black borders.")
            print("  Consider using a higher zoom parameter.")
        }
        
        // 6. INTELLIGENT COLOR SELECTION - Special handling for dark covers
        
        // Calculate average brightness to detect dark covers
        let totalBrightness = colorHistogram.reduce(0) { sum, entry in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            entry.key.getRed(&r, green: &g, blue: &b, alpha: nil)
            return sum + (Int(r * 255) + Int(g * 255) + Int(b * 255)) * entry.value
        }
        let averageBrightness = totalBrightness / (totalPixelsProcessed * 3)
        
        print("\n🌓 Cover Analysis:")
        print("  Average brightness: \(averageBrightness)/255")
        print("  Black pixels: \(blackPercentage)%")
        
        // For dark covers (like Lord of the Rings), find vibrant accent colors
        var significantColors: [(key: UIColor, value: Int)] = []
        var minColorThreshold = 1
        
        if averageBrightness < 80 || blackPercentage > 50 {  // More lenient threshold
            print("  📚 Dark cover detected - searching for accent colors...")
            
            // Find ALL colors with any vibrancy - BE VERY AGGRESSIVE
            let allColorVibrancy = colorHistogram.compactMap { (color, count) -> (UIColor, Int, CGFloat, CGFloat)? in
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: nil)
                
                let maxC = max(r, g, b)
                let minC = min(r, g, b)
                let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC
                let brightness = maxC
                let vibrancy = saturation * brightness  // Combined metric
                
                // BE VERY AGGRESSIVE - keep ANY color that isn't pure gray
                if saturation > 0.05 || brightness > 0.15 || (r != g || g != b) {
                    return (color, count, vibrancy, saturation)
                }
                return nil
            }
            
            // Sort by VIBRANCY (saturation * brightness), not frequency
            let sortedByVibrancy = allColorVibrancy.sorted { $0.2 > $1.2 }
            
            print("  Found \(sortedByVibrancy.count) vibrant colors")
            
            // Debug: Print top vibrant colors
            for (index, (color, count, vibrancy, sat)) in sortedByVibrancy.prefix(10).enumerated() {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: nil)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                let hueAngle = Int(h * 360)
                print("    \(index + 1). RGB(\(Int(r*255)), \(Int(g*255)), \(Int(b*255))) - Hue: \(hueAngle)° - Vibrancy: \(String(format: "%.2f", vibrancy)) - \(count) pixels")
            }
            
            // Take the most vibrant colors
            var vibrantSelection = sortedByVibrancy.prefix(20).map { ($0.0, $0.1) }
            
            // SPECIAL HANDLING for specific color types
            // Look for gold/yellow (Lord of the Rings ring)
            let goldColors = vibrantSelection.filter { color, _ in
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
                let hueAngle = h * 360
                return hueAngle >= 30 && hueAngle <= 70 && s > 0.2  // Lower threshold for dark golds
            }
            
            // Look for red colors (Lord of the Rings text)
            let redColors = vibrantSelection.filter { color, _ in
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
                let hueAngle = h * 360
                return (hueAngle >= 340 || hueAngle <= 20) && s > 0.2  // Lower threshold for dark reds
            }
            
            // Prioritize special colors
            var prioritizedColors: [(UIColor, Int)] = []
            if !goldColors.isEmpty {
                print("  ✨ Found \(goldColors.count) gold/yellow colors!")
                prioritizedColors.append(contentsOf: goldColors)
            }
            if !redColors.isEmpty {
                print("  🔴 Found \(redColors.count) red colors!")
                prioritizedColors.append(contentsOf: redColors)
            }
            
            // Add remaining vibrant colors
            let remainingVibrant = vibrantSelection.filter { color, _ in
                !prioritizedColors.contains { $0.0 == color }
            }
            prioritizedColors.append(contentsOf: remainingVibrant)
            
            significantColors = prioritizedColors
            
        } else {
            // Normal processing for non-dark covers
            let sortedColors = colorHistogram.sorted { $0.value > $1.value }
            
            // Calculate minimum threshold (0.5% of non-black pixels) to catch more accent colors
            let validPixelCount = totalPixelsProcessed - skippedBlack - skippedWhite - skippedTransparent
            minColorThreshold = max(1, Int(Double(validPixelCount) * 0.005))
            
            // Filter out colors that appear too infrequently
            significantColors = sortedColors.filter { $0.value >= minColorThreshold }
        }
        
        print("\n🎨 Color Analysis:")
        print("  Unique colors found: \(colorHistogram.count)")
        print("  Significant colors (>1% of pixels): \(significantColors.count)")
        print("  Minimum pixel threshold: \(minColorThreshold)")
        
        // Debug: Print top colors
        if significantColors.isEmpty {
            print("  ⚠️ NO SIGNIFICANT COLORS FOUND! All colors were below threshold.")
            print("  This suggests the image is mostly black/white or very low quality.")
        } else {
            print("\n  Top 5 significant colors by frequency:")
            for (index, (color, count)) in significantColors.prefix(5).enumerated() {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: nil)
                let percentage = Double(count) * 100.0 / Double(totalPixelsProcessed - skippedWhite - skippedBlack - skippedTransparent)
                
                // Also show hex and hue
                let hex = String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
                var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0
                color.getHue(&hue, saturation: &sat, brightness: &bri, alpha: nil)
                
                print("    \(index + 1). \(hex) RGB(\(Int(r*255)), \(Int(g*255)), \(Int(b*255))) H:\(Int(hue*360))° - \(count) pixels (\(String(format: "%.1f", percentage))%)")
            }
        }
        
        // 7. BUILD SMART PALETTE WITH COLOR VALIDATION
        let palette = buildIntelligentPalette(from: significantColors, totalPixels: totalPixelsProcessed)
        
        return palette
    }
    
    // MARK: - Intelligent Palette Building
    
    private func buildIntelligentPalette(from significantColors: [(key: UIColor, value: Int)], totalPixels: Int) -> ColorPalette {
        if significantColors.isEmpty {
            print("\n❌ No significant colors extracted - using fallback palette")
            return createFallbackPalette()
        }
        
        // UNIVERSAL COLOR VARIETY ALGORITHM
        var selectedColors: [UIColor] = []
        var colorPixelCounts: [UIColor: Int] = [:]  // Track pixel counts for role assignment
        let minColorDistance: CGFloat = 0.25 // Minimum 25% difference
        
        // Select colors with guaranteed variety
        for (candidateColor, count) in significantColors {
            // Skip very low saturation colors (grays) unless they're significant
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            candidateColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            // Skip grays unless they represent > 10% of the image
            if s < 0.15 && Double(count) / Double(totalPixels) < 0.1 {
                print("  ✗ Too gray: \(colorDescription(candidateColor)) - S:\(String(format: "%.2f", s))")
                continue
            }
            
            // Check if sufficiently different from all selected colors
            let isDifferentEnough = selectedColors.allSatisfy { existingColor in
                colorDistance(candidateColor, existingColor) > minColorDistance
            }
            
            if isDifferentEnough {
                selectedColors.append(candidateColor)
                colorPixelCounts[candidateColor] = count  // Store pixel count
                print("  ✓ Selected: \(colorDescription(candidateColor)) - \(count) pixels")
            } else {
                print("  ✗ Too similar: \(colorDescription(candidateColor))")
            }
            
            if selectedColors.count == 4 { break }
        }
        
        // If not enough variety, generate using color theory
        print("\n🎨 Found \(selectedColors.count) distinct colors, need 4")
        
        // For monochromatic images, generate variations rather than complements
        let isMonochromatic = selectedColors.count <= 2 || areColorsMonochromatic(selectedColors)
        
        while selectedColors.count < 4 && !selectedColors.isEmpty {
            if let baseColor = selectedColors.first {
                let generated = isMonochromatic 
                    ? generateMonochromaticVariation(from: baseColor, index: selectedColors.count)
                    : generateHarmonicColor(from: baseColor, avoiding: selectedColors)
                selectedColors.append(generated)
                colorPixelCounts[generated] = 1  // Minimal count for generated colors
                print("  + Generated: \(colorDescription(generated))")
            }
        }
        
        // Ensure we have exactly 4 colors
        while selectedColors.count < 4 {
            let gray = UIColor.systemGray
            selectedColors.append(gray)
            colorPixelCounts[gray] = 1
        }
        
        // Assign roles based on characteristics AND pixel count
        let roles = assignRoles(to: selectedColors, colorPixelCounts: colorPixelCounts)
        
        print("\n🎨 Universal Palette Created:")
        print("  Primary: \(colorDescription(roles.primary))")
        print("  Secondary: \(colorDescription(roles.secondary))")
        print("  Accent: \(colorDescription(roles.accent))")
        print("  Background: \(colorDescription(roles.background))")
        
        return ColorPalette(
            primary: Color(roles.primary),
            secondary: Color(roles.secondary),
            accent: Color(roles.accent),
            background: Color(roles.background),
            // Text color will be calculated by DisplayColorScheme based on actual gradient
            textColor: luminance(of: roles.primary) > 0.5 ? .black : .white,
            luminance: luminance(of: roles.primary),
            isMonochromatic: selectedColors.count <= 2,
            extractionQuality: Double(selectedColors.count) / 4.0
        )
    }
    
    
    // MARK: - Color Helper Functions
    
    private func isGray(_ color: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        let maxDiff = max(abs(r-g), abs(g-b), abs(r-b))
        return maxDiff < 0.05
    }
    
    private func saturation(of color: UIColor) -> CGFloat {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        return s
    }
    
    private func luminance(of color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        return 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    }
    
    private func colorDistance(_ color1: UIColor, _ color2: UIColor) -> CGFloat {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0
        
        color1.getRed(&r1, green: &g1, blue: &b1, alpha: nil)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: nil)
        
        // Euclidean distance in RGB space
        let dr = r1 - r2
        let dg = g1 - g2
        let db = b1 - b2
        
        return sqrt(dr*dr + dg*dg + db*db)
    }
    
    private func isWarmColor(_ color: UIColor) -> Bool {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        let hueAngle = h * 360
        return (hueAngle >= 0 && hueAngle <= 60) || (hueAngle >= 300 && hueAngle <= 360)
    }
    
    private func isCyanish(_ color: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        
        // Cyan colors have high green and blue, low red
        // RGB(229, 255, 255) would match this pattern
        return r < 0.7 && g > 0.8 && b > 0.8 && abs(g - b) < 0.1
    }
    
    private func isBlueOrTeal(_ color: UIColor) -> Bool {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        let hueAngle = h * 360
        // Blue to teal range (180-210 degrees)
        return hueAngle >= 170 && hueAngle <= 210 && s > 0.3
    }
    
    private func generateWarmComplement(for coolColor: UIColor) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        coolColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        // For ocean blues, generate coral/orange/sand colors
        let warmHue = CGFloat.random(in: 0.05...0.11) // Orange to coral range
        let warmSaturation = s * 0.6 // Slightly less saturated
        let warmBrightness = min(1.0, b * 1.1) // Slightly brighter
        
        return UIColor(hue: warmHue, saturation: warmSaturation, brightness: warmBrightness, alpha: 1.0)
    }
    
    
    private func generateWarmAccent(from primary: UIColor) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        primary.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        // Shift hue towards orange/gold
        let targetHue: CGFloat = 0.11 // Orange
        let newHue = h * 0.7 + targetHue * 0.3
        
        return UIColor(hue: newHue, saturation: min(1.0, s * 1.2), brightness: b * 0.9, alpha: 1.0)
    }
    
    // MARK: - Universal Color Harmony
    
    private func areColorsMonochromatic(_ colors: [UIColor]) -> Bool {
        guard colors.count >= 2 else { return true }
        
        var hues: [CGFloat] = []
        for color in colors {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            // Only consider colors with some saturation
            if s > 0.1 {
                hues.append(h)
            }
        }
        
        // If we have less than 2 saturated colors, it's monochromatic
        if hues.count < 2 { return true }
        
        // Check if all hues are within 0.1 range (36 degrees)
        let minHue = hues.min() ?? 0
        let maxHue = hues.max() ?? 0
        
        // Handle hue wrap-around (red at 0/1)
        if maxHue - minHue > 0.5 {
            // Check if colors are clustered around red (0/1)
            let wrappedHues = hues.map { $0 > 0.5 ? $0 - 1.0 : $0 }
            let wrappedMin = wrappedHues.min() ?? 0
            let wrappedMax = wrappedHues.max() ?? 0
            return wrappedMax - wrappedMin < 0.1
        }
        
        return maxHue - minHue < 0.1
    }
    
    private func generateMonochromaticVariation(from baseColor: UIColor, index: Int) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        baseColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        switch index {
        case 1:
            // Lighter version
            return UIColor(hue: h, saturation: max(0, s * 0.5), brightness: min(1.0, b * 1.3), alpha: 1.0)
        case 2:
            // Darker version
            return UIColor(hue: h, saturation: min(1.0, s * 1.2), brightness: b * 0.6, alpha: 1.0)
        case 3:
            // Much darker for background
            return UIColor(hue: h, saturation: min(1.0, s * 1.5), brightness: b * 0.3, alpha: 1.0)
        default:
            // Fallback: gray
            return UIColor(white: b * 0.5, alpha: 1.0)
        }
    }
    
    private func generateHarmonicColor(from baseColor: UIColor, avoiding existingColors: [UIColor]) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        baseColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        // Try different harmony strategies
        let strategies: [(name: String, hueShift: CGFloat, saturationMultiplier: CGFloat)] = [
            ("Complementary", 0.5, 1.0),      // 180° opposite
            ("Triadic 1", 0.333, 0.9),        // 120° clockwise
            ("Triadic 2", 0.667, 0.9),        // 120° counter-clockwise
            ("Analogous 1", 0.083, 0.8),      // 30° clockwise
            ("Analogous 2", 0.917, 0.8),      // 30° counter-clockwise
            ("Split Comp 1", 0.417, 0.95),    // 150° clockwise
            ("Split Comp 2", 0.583, 0.95)     // 150° counter-clockwise
        ]
        
        for (_, hueShift, satMult) in strategies {
            let newHue = (h + hueShift).truncatingRemainder(dividingBy: 1.0)
            let newSat = min(1.0, s * satMult)
            let newBright = b // Keep similar brightness
            
            let candidate = UIColor(hue: newHue, saturation: newSat, brightness: newBright, alpha: 1.0)
            
            // Check if this color is different enough from existing colors
            let isDifferentEnough = existingColors.allSatisfy { existing in
                colorDistance(candidate, existing) > 0.25
            }
            
            if isDifferentEnough {
        // print("    Using \(strategyName) harmony")
                return candidate
            }
        }
        
        // Fallback: create a neutral color
        return UIColor(hue: h, saturation: s * 0.3, brightness: min(1.0, b * 1.2), alpha: 1.0)
    }
    
    private func assignRoles(to colors: [UIColor], colorPixelCounts: [UIColor: Int]) -> (primary: UIColor, secondary: UIColor, accent: UIColor, background: UIColor) {
        guard colors.count >= 4 else {
            return (colors[0], colors[0], colors[0], UIColor.systemGray6)
        }
        
        // PRIORITIZE COLOR RICHNESS weighted by pixel count
        // Deep golds and reds are better than bright yellows
        
        // Calculate weighted score for all colors
        let colorsWithScores = colors.map { color -> (color: UIColor, richness: CGFloat, score: Double, hue: CGFloat, saturation: CGFloat, brightness: CGFloat) in
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            let hueAngle = h * 360
            
            // Calculate richness score
            var richness = s * b  // Base vibrancy
            
            // BOOST deep golds (30-45°) and pure reds (0-20°, 340-360°)
            if (hueAngle >= 30 && hueAngle <= 45) {
                richness *= 1.5  // Deep gold bonus
            } else if (hueAngle >= 0 && hueAngle <= 20) || (hueAngle >= 340 && hueAngle <= 360) {
                richness *= 1.8  // Red bonus (higher priority)
            } else if (hueAngle >= 45 && hueAngle <= 60) {
                richness *= 0.7  // Penalize bright yellows
            } else if (hueAngle >= 90 && hueAngle <= 150) {
                richness *= 0.3  // Heavily penalize pure greens
            } else if (hueAngle >= 180 && hueAngle <= 210) {
                richness *= 1.1  // Slight boost for cyan (Odyssey)
            } else if (hueAngle >= 220 && hueAngle <= 260) {
                richness *= 1.2  // Boost for blues
            }
            
            // Weight by pixel count (logarithmic to prevent overwhelming dominance)
            let pixelCount = Double(colorPixelCounts[color] ?? 1)
            let score = Double(richness) * log(pixelCount + 1)
            
            return (color, richness, score, h, s, b)
        }
        
        // Sort by weighted score
        let sortedByScore = colorsWithScores.sorted { $0.score > $1.score }
        
        print("  🎨 Role Assignment (by weighted score):")
        for (index, (color, richness, score, hue, sat, bright)) in sortedByScore.enumerated() {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            let hueAngle = Int(hue * 360)
            let pixelCount = colorPixelCounts[color] ?? 1
            print("    \(index + 1). RGB(\(Int(r*255)), \(Int(g*255)), \(Int(b*255))) H:\(hueAngle)°")
            print("       Richness: \(String(format: "%.2f", richness)), Pixels: \(pixelCount), Score: \(String(format: "%.2f", score))")
        }
        
        // PRIMARY = Top ranked by weighted score (considers both richness and frequency)
        let primary = sortedByScore[0].color
        
        // SECONDARY = Find a complementary color, preferring different hue ranges
        let secondary = sortedByScore.first { item in
            let hueDiff = abs(item.hue - sortedByScore[0].hue)
            let normalizedDiff = min(hueDiff, 1.0 - hueDiff)  // Handle hue wrap-around
            return normalizedDiff > 0.1 && colorDistance(item.color, primary) > 0.2
        }?.color ?? sortedByScore[1].color
        
        // ACCENT = Look for a red if primary is gold, or vice versa
        let primaryHue = sortedByScore[0].hue * 360
        let accent: UIColor
        
        if primaryHue >= 30 && primaryHue <= 60 {
            // Primary is gold/yellow, look for red accent
            accent = sortedByScore.first { item in
                let hueAngle = item.hue * 360
                return (hueAngle >= 0 && hueAngle <= 20) || (hueAngle >= 340 && hueAngle <= 360)
            }?.color ?? sortedByScore.first { item in
                colorDistance(item.color, primary) > 0.2 && 
                colorDistance(item.color, secondary) > 0.2
            }?.color ?? sortedByScore[2].color
        } else if (primaryHue >= 0 && primaryHue <= 20) || (primaryHue >= 340 && primaryHue <= 360) {
            // Primary is red, look for gold accent
            accent = sortedByScore.first { item in
                let hueAngle = item.hue * 360
                return hueAngle >= 30 && hueAngle <= 45
            }?.color ?? sortedByScore.first { item in
                colorDistance(item.color, primary) > 0.2 && 
                colorDistance(item.color, secondary) > 0.2
            }?.color ?? sortedByScore[2].color
        } else {
            // Default: pick a different color
            accent = sortedByScore.first { item in
                colorDistance(item.color, primary) > 0.2 && 
                colorDistance(item.color, secondary) > 0.2
            }?.color ?? sortedByScore[2].color
        }
        
        // BACKGROUND = Darkest color (for depth)
        let background = colors.min { c1, c2 in
            luminance(of: c1) < luminance(of: c2)
        } ?? UIColor.black
        
        print("  ✅ Final role assignment:")
        print("    Primary (TOP): \(colorDescription(primary))")
        print("    Secondary: \(colorDescription(secondary))")
        print("    Accent (BOTTOM): \(colorDescription(accent))")
        print("    Background: \(colorDescription(background))")
        
        return (primary, secondary, accent, background)
    }
    
    private func colorDescription(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        return "RGB(\(Int(r*255)), \(Int(g*255)), \(Int(b*255)))"
    }
    
    private func complementaryColor(of color: UIColor) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        // Rotate hue by 180 degrees
        let newHue = (h + 0.5).truncatingRemainder(dividingBy: 1.0)
        return UIColor(hue: newHue, saturation: s, brightness: b, alpha: a)
    }
    
    private func createFallbackPalette() -> ColorPalette {
        return ColorPalette(
            primary: Color.orange,
            secondary: Color.purple,
            accent: Color.pink,
            background: Color.blue,
            textColor: Color.white,
            luminance: 0.5,
            isMonochromatic: false,
            extractionQuality: 0.0
        )
    }
    
    private func calculateChecksum(for image: UIImage) -> String {
        guard let data = image.pngData() else { return "no-data" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).uppercased()
    }
    
    private func saveImageForDebug(_ image: UIImage, suffix: String) {
        Task {
            guard let data = image.pngData() else { return }
            let fileName = "\(suffix)_\(Date().timeIntervalSince1970).png"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                try data.write(to: tempURL)
        // print("💾 Saved extracted image to: \(tempURL.path)")
                
                // Save to Photos for easy inspection
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            } catch {
        // print("❌ Failed to save extracted image: \(error)")
            }
        }
    }
}

// MARK: - UIImage Extension
extension UIImage {
    @MainActor
    func resized(to targetSize: CGSize) async -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - Debug Extension
extension OKLABColorExtractor {
    /// Test extraction with a book cover
    public func testExtraction(with image: UIImage) async {
        do {
        // print("🧪 Testing OKLAB Color Extraction...")
            let palette = try await extractPalette(from: image)
            
        // print("\n📊 Extraction Results:")
        // print("Primary: \(palette.primary.description)")
        // print("Secondary: \(palette.secondary.description)")
        // print("Accent: \(palette.accent.description)")
        // print("Background: \(palette.background.description)")
        // print("Text Color: \(palette.textColor.description)")
        // print("Luminance: \(String(format: "%.2f", palette.luminance))")
        // print("Monochromatic: \(palette.isMonochromatic)")
        // print("Quality: \(String(format: "%.2f", palette.extractionQuality))")
            
        } catch {
        // print("❌ Extraction failed: \(error.localizedDescription)")
        }
    }
}