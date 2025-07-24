import SwiftUI
import UIKit

struct SimpleColorExtractor {
    
    // Extract dominant colors from an image
    static func extractColors(from image: UIImage, maxColors: Int = 5) -> (colors: [Color], brightness: Double) {
        print("🎨 Starting color extraction for image size: \(image.size)")
        
        // Resize image for performance
        guard let resizedImage = resizeImage(image, targetSize: CGSize(width: 100, height: 150)),
              let cgImage = resizedImage.cgImage else {
            print("❌ Failed to resize image")
            return ([], 0.5)
        }
        
        print("📐 Resized to: \(resizedImage.size)")
        
        // Extract pixel data
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return ([], 0.5)
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Sample pixels with smart strategy
        var colorFrequency: [String: (color: Color, count: Int, weight: Int)] = [:]
        var totalBrightness: Double = 0
        var pixelCount = 0
        
        // Define center region for 2x weighting
        let centerX = width / 2
        let centerY = height / 2
        let centerRadius = min(width, height) / 3
        
        for y in stride(from: 0, to: height, by: 3) { // Sample more pixels
            for x in stride(from: 0, to: width, by: 3) {
                let index = (y * width + x) * bytesPerPixel
                
                let r = Double(pixelData[index]) / 255.0
                let g = Double(pixelData[index + 1]) / 255.0
                let b = Double(pixelData[index + 2]) / 255.0
                
                // Calculate brightness
                let brightness = (0.299 * r + 0.587 * g + 0.114 * b)
                
                // Skip very dark or very light pixels
                if brightness < 0.1 || brightness > 0.95 {
                    continue
                }
                
                totalBrightness += brightness
                pixelCount += 1
                
                // Check if pixel is in center region
                let distFromCenter = sqrt(pow(Double(x - centerX), 2) + pow(Double(y - centerY), 2))
                let isCenter = distFromCenter <= Double(centerRadius)
                let weight = isCenter ? 2 : 1
                
                // Quantize color to group similar ones (tolerance 0.1)
                let quantizedR = round(r * 10) / 10
                let quantizedG = round(g * 10) / 10
                let quantizedB = round(b * 10) / 10
                
                let key = "\(quantizedR)-\(quantizedG)-\(quantizedB)"
                
                if let existing = colorFrequency[key] {
                    colorFrequency[key] = (existing.color, existing.count + 1, existing.weight + weight)
                } else {
                    colorFrequency[key] = (Color(red: r, green: g, blue: b), 1, weight)
                }
            }
        }
        
        // Sort by weighted count to prioritize center colors
        let sortedColors = colorFrequency.values
            .sorted { $0.weight > $1.weight }
            .prefix(maxColors)
            .map { $0.color }
        
        var colors = Array(sortedColors)
        let averageBrightness = pixelCount > 0 ? totalBrightness / Double(pixelCount) : 0.5
        
        print("🎨 Extracted \(colors.count) colors (before enhancement):")
        for (index, color) in colors.enumerated() {
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            let brightness = (r + g + b) / 3.0
            print("  Color \(index): R:\(String(format: "%.2f", r)) G:\(String(format: "%.2f", g)) B:\(String(format: "%.2f", b)) Brightness:\(String(format: "%.2f", brightness))")
        }
        
        // Enhance colors if too dark
        if averageBrightness < 0.3 {
            print("⚡ Enhancing dark colors (avg brightness: \(String(format: "%.2f", averageBrightness)))")
            colors = colors.map { color in
                let uiColor = UIColor(color)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                
                // Boost brightness while preserving color relationships
                let boostFactor: CGFloat = 1.5
                let enhancedR = min(r * boostFactor, 1.0)
                let enhancedG = min(g * boostFactor, 1.0)
                let enhancedB = min(b * boostFactor, 1.0)
                
                return Color(red: enhancedR, green: enhancedG, blue: enhancedB)
            }
        }
        
        // Ensure at least one bright color
        let brightestColor = colors.max { color1, color2 in
            let ui1 = UIColor(color1)
            let ui2 = UIColor(color2)
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0
            ui1.getRed(&r1, green: &g1, blue: &b1, alpha: nil)
            ui2.getRed(&r2, green: &g2, blue: &b2, alpha: nil)
            return (r1 + g1 + b1) < (r2 + g2 + b2)
        }
        
        if let brightest = brightestColor {
            let uiColor = UIColor(brightest)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            let brightness = (r + g + b) / 3.0
            
            if brightness < 0.5 {
                // Replace the first color with a brightened version
                let boostFactor: CGFloat = 0.7 / brightness
                colors[0] = Color(red: min(r * boostFactor, 1.0), 
                                green: min(g * boostFactor, 1.0), 
                                blue: min(b * boostFactor, 1.0))
            }
        }
        
        print("🎨 Enhanced colors:")
        for (index, color) in colors.enumerated() {
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            let brightness = (r + g + b) / 3.0
            print("  Color \(index): R:\(String(format: "%.2f", r)) G:\(String(format: "%.2f", g)) B:\(String(format: "%.2f", b)) Brightness:\(String(format: "%.2f", brightness))")
        }
        print("🔆 Average brightness: \(String(format: "%.2f", averageBrightness))")
        
        // Temporary debug boost for testing
        if averageBrightness < 0.3 && colors.isEmpty == false {
            print("🔥 DEBUG: Applying additional brightness boost")
            colors = colors.map { color in
                let uiColor = UIColor(color)
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                
                // Boost saturation and brightness
                let boostedS = min(s * 1.3, 1.0)
                let boostedB = min(b + 0.3, 0.9)
                
                return Color(hue: Double(h), saturation: Double(boostedS), brightness: Double(boostedB))
            }
        }
        
        return (colors, averageBrightness)
    }
    
    // Resize image for faster processing
    private static func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        let newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}