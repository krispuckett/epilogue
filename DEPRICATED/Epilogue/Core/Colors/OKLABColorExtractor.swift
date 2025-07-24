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
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        // print("📐 Processing image: \(width)x\(height) pixels")
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
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
        
        // 3. BUILD COLOR HISTOGRAM (no averaging!)
        var colorHistogram: [UIColor: Int] = [:]
        var totalPixelsProcessed = 0
        var skippedWhite = 0
        var skippedBlack = 0
        var skippedTransparent = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = ((width * y) + x) * bytesPerPixel
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
                
                // Skip black pixels more aggressively
                // Black borders from low-quality images have RGB values all < 30
                let totalBrightness = Int(r) + Int(g) + Int(b)
                if totalBrightness < 30 {  // This is essentially black
                    skippedBlack += 1
                    continue
                }
                
                // Also skip very dark pixels that are nearly black
                if rf < 0.1 && gf < 0.1 && bf < 0.1 {
                    skippedBlack += 1
                    continue
                }
                
                // 5. COLOR QUANTIZATION (group similar colors more aggressively)
                // Round to nearest 0.2 for better color variety
                let quantizedR = round(rf * 5) / 5
                let quantizedG = round(gf * 5) / 5
                let quantizedB = round(bf * 5) / 5
                
                let color = UIColor(red: quantizedR, green: quantizedG, blue: quantizedB, alpha: 1.0)
                colorHistogram[color, default: 0] += 1
            }
        }
        
        // print("\n📊 Pixel Processing Summary:")
        // print("  Total pixels: \(totalPixelsProcessed)")
        // print("  Skipped white: \(skippedWhite)")
        // print("  Skipped black: \(skippedBlack)")
        // print("  Skipped transparent: \(skippedTransparent)")
        // print("  Colors found: \(colorHistogram.count)")
        
        // Quality detection
        let blackPercentage = Double(skippedBlack) * 100.0 / Double(totalPixelsProcessed)
        if blackPercentage > 70 {
        // print("  ⚠️ WARNING: \(String(format: "%.1f", blackPercentage))% of image is black!")
        // print("  This suggests a low-quality image with black borders.")
        // print("  Consider using a higher zoom parameter.")
        }
        
        // 6. INTELLIGENT COLOR SELECTION
        let sortedColors = colorHistogram.sorted { $0.value > $1.value }
        
        // Calculate minimum threshold (1% of non-black pixels)
        let validPixelCount = totalPixelsProcessed - skippedBlack - skippedWhite - skippedTransparent
        let minColorThreshold = max(1, Int(Double(validPixelCount) * 0.01))
        
        // Filter out colors that appear too infrequently
        let significantColors = sortedColors.filter { $0.value >= minColorThreshold }
        
        // print("\n🎨 Color Analysis:")
        // print("  Unique colors found: \(sortedColors.count)")
        // print("  Significant colors (>1% of pixels): \(significantColors.count)")
        // print("  Minimum pixel threshold: \(minColorThreshold)")
        
        // Debug: Print top colors
        if significantColors.isEmpty {
        // print("  ⚠️ NO SIGNIFICANT COLORS FOUND! All colors were below threshold.")
        // print("  This suggests the image is mostly black/white or very low quality.")
        } else {
        // print("\n  Top 5 significant colors by frequency:")
            for (index, (color, count)) in significantColors.prefix(5).enumerated() {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: nil)
                let percentage = Double(count) * 100.0 / Double(totalPixelsProcessed - skippedWhite - skippedBlack - skippedTransparent)
        // print("    \(index + 1). RGB(\(Int(r*255)), \(Int(g*255)), \(Int(b*255))) - \(count) pixels (\(String(format: "%.1f", percentage))%)")
            }
        }
        
        // 7. BUILD SMART PALETTE WITH COLOR VALIDATION
        let palette = buildIntelligentPalette(from: significantColors, totalPixels: totalPixelsProcessed)
        
        return palette
    }
    
    // MARK: - Intelligent Palette Building
    
    private func buildIntelligentPalette(from significantColors: [(key: UIColor, value: Int)], totalPixels: Int) -> ColorPalette {
        if significantColors.isEmpty {
        // print("\n❌ No significant colors extracted - using fallback palette")
            return createFallbackPalette()
        }
        
        // UNIVERSAL COLOR VARIETY ALGORITHM
        var selectedColors: [UIColor] = []
        let minColorDistance: CGFloat = 0.25 // Minimum 25% difference
        
        // Select colors with guaranteed variety
        for (candidateColor, count) in significantColors {
            // Check if sufficiently different from all selected colors
            let isDifferentEnough = selectedColors.allSatisfy { existingColor in
                colorDistance(candidateColor, existingColor) > minColorDistance
            }
            
            if isDifferentEnough {
                selectedColors.append(candidateColor)
        // print("  ✓ Selected: \(colorDescription(candidateColor)) - \(count) pixels")
            } else {
        // print("  ✗ Too similar: \(colorDescription(candidateColor))")
            }
            
            if selectedColors.count == 4 { break }
        }
        
        // If not enough variety, generate using color theory
        // print("\n🎨 Found \(selectedColors.count) distinct colors, need 4")
        
        while selectedColors.count < 4 && !selectedColors.isEmpty {
            if let lastColor = selectedColors.last {
                let generated = generateHarmonicColor(from: lastColor, avoiding: selectedColors)
                selectedColors.append(generated)
        // print("  + Generated: \(colorDescription(generated))")
            }
        }
        
        // Ensure we have exactly 4 colors
        while selectedColors.count < 4 {
            selectedColors.append(UIColor.systemGray)
        }
        
        // Assign roles based on characteristics
        let palette = assignRoles(to: selectedColors)
        
        // print("\n🎨 Universal Palette Created:")
        // print("  Primary: \(colorDescription(palette.primary))")
        // print("  Secondary: \(colorDescription(palette.secondary))")
        // print("  Accent: \(colorDescription(palette.accent))")
        // print("  Background: \(colorDescription(palette.background))")
        
        return ColorPalette(
            primary: Color(palette.primary),
            secondary: Color(palette.secondary),
            accent: Color(palette.accent),
            background: Color(palette.background),
            // Text color will be calculated by DisplayColorScheme based on actual gradient
            textColor: luminance(of: palette.primary) > 0.5 ? .black : .white,
            luminance: luminance(of: palette.primary),
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
        
        for (strategyName, hueShift, satMult) in strategies {
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
    
    private func assignRoles(to colors: [UIColor]) -> (primary: UIColor, secondary: UIColor, accent: UIColor, background: UIColor) {
        guard colors.count >= 4 else {
            return (colors[0], colors[0], colors[0], UIColor.systemGray6)
        }
        
        // Sort by characteristics
        let sortedBySaturation = colors.sorted { c1, c2 in
            saturation(of: c1) > saturation(of: c2)
        }
        
        let sortedByLuminance = colors.sorted { c1, c2 in
            luminance(of: c1) > luminance(of: c2)
        }
        
        // Assign roles intelligently
        let accent = sortedBySaturation[0]  // Most saturated = accent
        let background = sortedByLuminance[0]  // Lightest = background
        
        // Primary and secondary from remaining colors
        let remaining = colors.filter { color in
            colorDistance(color, accent) > 0.1 && colorDistance(color, background) > 0.1
        }
        
        let primary = remaining.first ?? colors[0]
        let secondary = remaining.count > 1 ? remaining[1] : colors[1]
        
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