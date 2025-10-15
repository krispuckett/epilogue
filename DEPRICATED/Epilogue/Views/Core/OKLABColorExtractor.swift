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
        #if DEBUG
        print("🎨 Starting OKLAB color extraction...")
        #endif
        #if DEBUG
        print("📊 Original image size: \(image.size)")
        #endif
        #if DEBUG
        print("📍 Image source: \(imageSource)")
        #endif
        
        // Calculate checksum
        let checksum = calculateChecksum(for: image)
        #if DEBUG
        print("🔐 EXTRACTED Image checksum: \(checksum)")
        #endif
        
        // Save for debugging
        saveImageForDebug(image, suffix: "EXTRACTED_\(imageSource)")
        
        // 1. SAMPLE EVERY PIXEL (with smart downsampling)
        let targetSize = CGSize(width: 100, height: 100)  // Small enough to process every pixel
        guard let resized = await image.resized(to: targetSize) else {
            #if DEBUG
            print("❌ Failed to resize image")
            #endif
            return createFallbackPalette()
        }
        
        guard let cgImage = resized.cgImage else {
            #if DEBUG
            print("❌ No CGImage available")
            #endif
            return createFallbackPalette()
        }
        
        // 2. Properly extract pixel data
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        #if DEBUG
        print("📐 Processing image: \(width)x\(height) pixels")
        #endif
        
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
            #if DEBUG
            print("❌ Failed to create bitmap context")
            #endif
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
                    #if DEBUG
                    print("  Pixel \(totalPixelsProcessed): R=\(r) G=\(g) B=\(b) A=\(a)")
                    #endif
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
        
        #if DEBUG
        print("\n📊 Pixel Processing Summary:")
        #endif
        #if DEBUG
        print("  Total pixels: \(totalPixelsProcessed)")
        #endif
        #if DEBUG
        print("  Skipped white: \(skippedWhite)")
        #endif
        #if DEBUG
        print("  Skipped black: \(skippedBlack)")
        #endif
        #if DEBUG
        print("  Skipped transparent: \(skippedTransparent)")
        #endif
        #if DEBUG
        print("  Colors found: \(colorHistogram.count)")
        #endif
        
        // Quality detection
        let blackPercentage = Double(skippedBlack) * 100.0 / Double(totalPixelsProcessed)
        if blackPercentage > 70 {
            #if DEBUG
            print("  ⚠️ WARNING: \(String(format: "%.1f", blackPercentage))% of image is black!")
            #endif
            #if DEBUG
            print("  This suggests a low-quality image with black borders.")
            #endif
            #if DEBUG
            print("  Consider using a higher zoom parameter.")
            #endif
        }
        
        // 6. INTELLIGENT COLOR SELECTION
        let sortedColors = colorHistogram.sorted { $0.value > $1.value }
        
        // Calculate minimum threshold (1% of non-black pixels)
        let validPixelCount = totalPixelsProcessed - skippedBlack - skippedWhite - skippedTransparent
        let minColorThreshold = max(1, Int(Double(validPixelCount) * 0.01))
        
        // Filter out colors that appear too infrequently
        let significantColors = sortedColors.filter { $0.value >= minColorThreshold }
        
        #if DEBUG
        print("\n🎨 Color Analysis:")
        #endif
        #if DEBUG
        print("  Unique colors found: \(sortedColors.count)")
        #endif
        #if DEBUG
        print("  Significant colors (>1% of pixels): \(significantColors.count)")
        #endif
        #if DEBUG
        print("  Minimum pixel threshold: \(minColorThreshold)")
        #endif
        
        // Debug: Print top colors
        if significantColors.isEmpty {
            #if DEBUG
            print("  ⚠️ NO SIGNIFICANT COLORS FOUND! All colors were below threshold.")
            #endif
            #if DEBUG
            print("  This suggests the image is mostly black/white or very low quality.")
            #endif
        } else {
            #if DEBUG
            print("\n  Top 5 significant colors by frequency:")
            #endif
            for (index, (color, count)) in significantColors.prefix(5).enumerated() {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: nil)
                let percentage = Double(count) * 100.0 / Double(totalPixelsProcessed - skippedWhite - skippedBlack - skippedTransparent)
                #if DEBUG
                print("    \(index + 1). RGB(\(Int(r*255)), \(Int(g*255)), \(Int(b*255))) - \(count) pixels (\(String(format: "%.1f", percentage))%)")
                #endif
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
            #if DEBUG
            print("\n❌ No significant colors extracted - using fallback palette")
            #endif
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
                #if DEBUG
                print("💾 Saved extracted image to: \(tempURL.path)")
                #endif
                
                // Save to Photos for easy inspection
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            } catch {
                #if DEBUG
                print("❌ Failed to save extracted image: \(error)")
                #endif
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
            #if DEBUG
            print("🧪 Testing OKLAB Color Extraction...")
            #endif
            let palette = try await extractPalette(from: image)
            
            #if DEBUG
            print("\n📊 Extraction Results:")
            #endif
            #if DEBUG
            print("Primary: \(palette.primary.description)")
            #endif
            #if DEBUG
            print("Secondary: \(palette.secondary.description)")
            #endif
            #if DEBUG
            print("Accent: \(palette.accent.description)")
            #endif
            #if DEBUG
            print("Background: \(palette.background.description)")
            #endif
            #if DEBUG
            print("Text Color: \(palette.textColor.description)")
            #endif
            #if DEBUG
            print("Luminance: \(String(format: "%.2f", palette.luminance))")
            #endif
            #if DEBUG
            print("Monochromatic: \(palette.isMonochromatic)")
            #endif
            #if DEBUG
            print("Quality: \(String(format: "%.2f", palette.extractionQuality))")
            #endif
            
        } catch {
            #if DEBUG
            print("❌ Extraction failed: \(error.localizedDescription)")
            #endif
        }
    }
}