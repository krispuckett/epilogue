import SwiftUI
import UIKit
import CryptoKit

// MARK: - Debug Color Extractor
@MainActor
public class OKLABColorExtractorDebug {
    
    public init() {}
    
    /// Extract color palette with full debugging
    public func extractPalette(from image: UIImage, imageSource: String = "Unknown") async throws -> ColorPalette {
        print("\n🔍 DEBUG COLOR EXTRACTION START")
        print("📍 Image source: \(imageSource)")
        print("📊 Original image size: \(image.size)")
        
        // 1. Resize image
        let targetSize = CGSize(width: 100, height: 100)
        guard let resized = await image.resized(to: targetSize) else {
            print("❌ Failed to resize image")
            return createFallbackPalette()
        }
        
        guard let cgImage = resized.cgImage else {
            print("❌ No CGImage available")
            return createFallbackPalette()
        }
        
        // 2. Extract pixel data properly
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
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
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 3. Count raw colors - NO CONVERSION, NO FILTERING
        var rawColorCounts: [(r: UInt8, g: UInt8, b: UInt8, count: Int)] = []
        var colorMap: [String: Int] = [:]
        
        print("\n📊 RAW PIXEL SAMPLING:")
        var sampleCount = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = ((width * y) + x) * bytesPerPixel
                let r = pixelData[offset]
                let g = pixelData[offset + 1]
                let b = pixelData[offset + 2]
                let a = pixelData[offset + 3]
                
                // Skip only fully transparent
                if a < 10 { continue }
                
                let key = "\(r),\(g),\(b)"
                colorMap[key, default: 0] += 1
                
                // Log some samples
                if sampleCount < 20 && (r > 200 || g < 100) {
                    print("  Sample \(sampleCount): RGB(\(r),\(g),\(b)) at (\(x),\(y))")
                    sampleCount += 1
                }
            }
        }
        
        // Convert map to sorted array
        for (key, count) in colorMap {
            let components = key.split(separator: ",").compactMap { Int($0) }
            if components.count == 3 {
                rawColorCounts.append((
                    r: UInt8(components[0]),
                    g: UInt8(components[1]),
                    b: UInt8(components[2]),
                    count: count
                ))
            }
        }
        
        // Sort by frequency
        rawColorCounts.sort { $0.count > $1.count }
        
        print("\n🎨 TOP 10 RAW COLORS (no processing):")
        for (index, color) in rawColorCounts.prefix(10).enumerated() {
            print("  \(index + 1). RGB(\(color.r),\(color.g),\(color.b)) - \(color.count) pixels")
            
            // Check if this is red-ish
            if color.r > 200 && color.g < 100 && color.b < 100 {
                print("     ⚠️ This is RED! Should be in final palette!")
            }
            // Check if this is gold-ish
            if color.r > 200 && color.g > 150 && color.b < 100 {
                print("     ⚠️ This is GOLD! Should be in final palette!")
            }
        }
        
        // 4. FILTER OUT BLACK COLORS
        print("\n🔴 FILTERING BLACK COLORS:")
        let nonBlackColors = rawColorCounts.filter { color in
            let totalBrightness = Int(color.r) + Int(color.g) + Int(color.b)
            let isBlack = totalBrightness < 30
            if isBlack && color.count > 100 {
                print("  Skipping black color: RGB(\(color.r),\(color.g),\(color.b)) - \(color.count) pixels")
            }
            return !isBlack
        }
        
        print("  Found \(nonBlackColors.count) non-black colors")
        
        // 5. FIND VIBRANT COLORS
        print("\n🌈 FINDING VIBRANT COLORS:")
        
        // Look for colors with high saturation (like red)
        let vibrantColors = nonBlackColors.filter { color in
            let maxChannel = max(color.r, color.g, color.b)
            let minChannel = min(color.r, color.g, color.b)
            let saturation = Float(maxChannel - minChannel) / Float(max(1, maxChannel))
            return saturation > 0.5 && maxChannel > 100
        }
        
        print("  Found \(vibrantColors.count) vibrant colors")
        if !vibrantColors.isEmpty {
            print("  Most vibrant colors:")
            for (index, color) in vibrantColors.prefix(3).enumerated() {
                print("    \(index + 1). RGB(\(color.r),\(color.g),\(color.b)) - \(color.count) pixels")
            }
        }
        
        // 6. CREATE PALETTE FROM NON-BLACK COLORS
        print("\n📊 CREATING PALETTE FROM NON-BLACK COLORS:")
        
        // Prefer vibrant colors for primary/accent
        let primaryCandidate = vibrantColors.first ?? nonBlackColors.first
        let accentCandidate = vibrantColors.count > 1 ? vibrantColors[1] : (vibrantColors.first ?? nonBlackColors.first)
        
        // Use regular non-black colors for secondary/background
        let secondaryCandidate = nonBlackColors.count > 1 ? nonBlackColors[1] : nonBlackColors.first
        let backgroundCandidate = nonBlackColors.count > 3 ? nonBlackColors[3] : nonBlackColors.last
        
        if let primary = primaryCandidate,
           let secondary = secondaryCandidate,
           let accent = accentCandidate,
           let background = backgroundCandidate {
            
            let primaryColor = UIColor(
                red: CGFloat(primary.r) / 255.0,
                green: CGFloat(primary.g) / 255.0,
                blue: CGFloat(primary.b) / 255.0,
                alpha: 1.0
            )
            let secondaryColor = UIColor(
                red: CGFloat(secondary.r) / 255.0,
                green: CGFloat(secondary.g) / 255.0,
                blue: CGFloat(secondary.b) / 255.0,
                alpha: 1.0
            )
            let accentColor = UIColor(
                red: CGFloat(accent.r) / 255.0,
                green: CGFloat(accent.g) / 255.0,
                blue: CGFloat(accent.b) / 255.0,
                alpha: 1.0
            )
            let backgroundColor = UIColor(
                red: CGFloat(background.r) / 255.0,
                green: CGFloat(background.g) / 255.0,
                blue: CGFloat(background.b) / 255.0,
                alpha: 1.0
            )
            
            print("  Primary: RGB(\(primary.r),\(primary.g),\(primary.b)) - \(primary.count) pixels")
            print("  Secondary: RGB(\(secondary.r),\(secondary.g),\(secondary.b)) - \(secondary.count) pixels")
            print("  Accent: RGB(\(accent.r),\(accent.g),\(accent.b)) - \(accent.count) pixels")
            print("  Background: RGB(\(background.r),\(background.g),\(background.b)) - \(background.count) pixels")
            
            return ColorPalette(
                primary: Color(primaryColor),
                secondary: Color(secondaryColor),
                accent: Color(accentColor),
                background: Color(backgroundColor),
                textColor: .white,
                luminance: 0.5,
                isMonochromatic: false,
                extractionQuality: 1.0
            )
        } else {
            print("  ⚠️ Not enough non-black colors found!")
        }
        
        // Fallback
        return createFallbackPalette()
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
}

// Use existing UIImage extension from main file