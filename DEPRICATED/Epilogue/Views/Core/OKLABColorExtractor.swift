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
        print("🎨 Starting OKLAB color extraction...")
        print("📊 Original image size: \(image.size)")
        print("📍 Image source: \(imageSource)")
        
        // Calculate checksum
        let checksum = calculateChecksum(for: image)
        print("🔐 EXTRACTED Image checksum: \(checksum)")
        
        // Save for debugging
        saveImageForDebug(image, suffix: "EXTRACTED_\(imageSource)")
        
        // 1. SAMPLE EVERY PIXEL (with smart downsampling)
        let targetSize = CGSize(width: 100, height: 100)  // Small enough to process every pixel
        guard let resized = await image.resized(to: targetSize) else {
            print("❌ Failed to resize image")
            return createFallbackPalette()
        }
        
        guard let cgImage = resized.cgImage else {
            print("❌ No CGImage available")
            return createFallbackPalette()
        }
        
        // 2. Properly extract pixel data
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        print("📐 Processing image: \(width)x\(height) pixels")
        
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
            print("❌ Failed to create bitmap context")
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
                    print("  Pixel \(totalPixelsProcessed): R=\(r) G=\(g) B=\(b) A=\(a)")
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
                
                // 5. COLOR QUANTIZATION (group similar colors)
                // Round to nearest 0.1 to group similar shades
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
        
        // Quality detection
        let blackPercentage = Double(skippedBlack) * 100.0 / Double(totalPixelsProcessed)
        if blackPercentage > 70 {
            print("  ⚠️ WARNING: \(String(format: "%.1f", blackPercentage))% of image is black!")
            print("  This suggests a low-quality image with black borders.")
            print("  Consider using a higher zoom parameter.")
        }
        
        // 6. INTELLIGENT COLOR SELECTION
        let sortedColors = colorHistogram.sorted { $0.value > $1.value }
        
        // Calculate minimum threshold (1% of non-black pixels)
        let validPixelCount = totalPixelsProcessed - skippedBlack - skippedWhite - skippedTransparent
        let minColorThreshold = max(1, Int(Double(validPixelCount) * 0.01))
        
        // Filter out colors that appear too infrequently
        let significantColors = sortedColors.filter { $0.value >= minColorThreshold }
        
        print("\n🎨 Color Analysis:")
        print("  Unique colors found: \(sortedColors.count)")
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
                print("    \(index + 1). RGB(\(Int(r*255)), \(Int(g*255)), \(Int(b*255))) - \(count) pixels (\(String(format: "%.1f", percentage))%)")
            }
        }
        
        // Find the most saturated color from significant colors (likely the accent)
        let accentColor = significantColors
            .map { $0.key }
            .max { color1, color2 in
                saturation(of: color1) < saturation(of: color2)
            } ?? UIColor.orange
        
        // Find the most common non-gray color from significant colors
        let primaryColor = significantColors
            .filter { !isGray($0.key) }
            .first?.key ?? accentColor
        
        // 7. BUILD SMART PALETTE
        if significantColors.isEmpty {
            print("\n❌ No significant colors extracted - using fallback palette")
            // Low quality image or pure black/white
            return ColorPalette(
                primary: .black,
                secondary: .gray,
                accent: .orange,  // Default accent
                background: .black,
                textColor: .white,
                luminance: 0.9,
                isMonochromatic: true,
                extractionQuality: 0.3
            )
        } else if significantColors.count == 1 {
            // Monochromatic - use the one color we found
            let mainColor = significantColors[0].key
            return ColorPalette(
                primary: Color(mainColor),
                secondary: Color(mainColor.withAlphaComponent(0.7)),
                accent: Color(complementaryColor(of: mainColor)),
                background: .black,
                textColor: .white,
                luminance: luminance(of: mainColor),
                isMonochromatic: true,
                extractionQuality: 0.8
            )
        } else {
            // Normal case - we found multiple colors
            let secondaryColor = significantColors.count > 1 ? significantColors[1].key : primaryColor.withAlphaComponent(0.7)
            // Use a mid-frequency color for background, not the least frequent
            let backgroundIndex = min(3, significantColors.count - 1)
            let backgroundColor = significantColors.count > 2 ? significantColors[backgroundIndex].key : UIColor.black
            
            return ColorPalette(
                primary: Color(primaryColor),
                secondary: Color(secondaryColor),
                accent: Color(accentColor),
                background: Color(backgroundColor),
                textColor: luminance(of: primaryColor) > 0.5 ? .black : .white,
                luminance: luminance(of: primaryColor),
                isMonochromatic: false,
                extractionQuality: 1.0
            )
        }
    }
    
    // MARK: - Helper Functions
    
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
                print("💾 Saved extracted image to: \(tempURL.path)")
                
                // Save to Photos for easy inspection
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            } catch {
                print("❌ Failed to save extracted image: \(error)")
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
            print("🧪 Testing OKLAB Color Extraction...")
            let palette = try await extractPalette(from: image)
            
            print("\n📊 Extraction Results:")
            print("Primary: \(palette.primary.description)")
            print("Secondary: \(palette.secondary.description)")
            print("Accent: \(palette.accent.description)")
            print("Background: \(palette.background.description)")
            print("Text Color: \(palette.textColor.description)")
            print("Luminance: \(String(format: "%.2f", palette.luminance))")
            print("Monochromatic: \(palette.isMonochromatic)")
            print("Quality: \(String(format: "%.2f", palette.extractionQuality))")
            
        } catch {
            print("❌ Extraction failed: \(error.localizedDescription)")
        }
    }
}