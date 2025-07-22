import SwiftUI
import UIKit
import CoreImage

// MARK: - Smart Accent Color Extractor
// Intelligently extracts the best accent color for UI elements from book covers

class SmartAccentColorExtractor {
    
    // MARK: - Main Extraction Method
    static func extractAccentColor(from image: UIImage, bookTitle: String? = nil) -> Color {
        print("🎨 SmartAccentColorExtractor - Analyzing cover for: \(bookTitle ?? "Unknown")")
        
        guard let cgImage = image.cgImage else {
            print("❌ Failed to get CGImage, returning default")
            return Color.orange // Default fallback
        }
        
        // Check if the cover has significant gold/yellow elements before prioritizing them
        let hasGoldElements = checkForGoldElements(cgImage)
        print("🔍 Gold elements check for \(bookTitle ?? "Unknown"): \(hasGoldElements)")
        if hasGoldElements, let goldColor = extractGoldAccent(from: cgImage) {
            print("🏆 Found gold/yellow accent - using it as primary accent")
            return softenHarshColors(goldColor)
        }
        
        // 1. Analyze cover characteristics
        let analysis = analyzeCoverCharacteristics(cgImage)
        print("📊 Cover analysis - Brightness: \(analysis.averageBrightness), Contrast: \(analysis.hasHighContrast)")
        
        // 2. Extract candidate colors using multiple strategies
        var candidates: [AccentCandidate] = []
        
        // Strategy 1: Center region sampling (often where title/key elements are)
        candidates.append(contentsOf: extractCenterRegionColors(cgImage, analysis: analysis))
        
        // Strategy 2: Edge detection for text and graphic elements
        candidates.append(contentsOf: extractEdgeColors(cgImage, analysis: analysis))
        
        // Strategy 3: High saturation colors (often used for accents)
        candidates.append(contentsOf: extractVibrantColors(cgImage, analysis: analysis))
        
        // Strategy 4: Statistical outliers (colors that stand out)
        candidates.append(contentsOf: extractOutlierColors(cgImage, analysis: analysis))
        
        // 3. Score and rank candidates
        let rankedCandidates = rankCandidates(candidates, coverAnalysis: analysis)
        
        // 4. Select the best accent color
        if let bestCandidate = rankedCandidates.first {
            print("✅ Selected accent color: \(describeColor(bestCandidate.color)) with score: \(bestCandidate.score)")
            
            // Post-process to soften harsh colors
            return softenHarshColors(bestCandidate.color)
        }
        
        // Fallback based on cover type
        return generateFallbackAccent(for: analysis)
    }
    
    // MARK: - Cover Analysis
    private static func analyzeCoverCharacteristics(_ cgImage: CGImage) -> CoverAnalysis {
        let width = cgImage.width
        let height = cgImage.height
        
        // Sample the image for analysis
        let sampleSize = CGSize(width: min(200, width), height: min(300, height))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * Int(sampleSize.width)
        
        var pixelData = [UInt8](repeating: 0, count: Int(sampleSize.width * sampleSize.height) * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: Int(sampleSize.width),
            height: Int(sampleSize.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return CoverAnalysis(averageBrightness: 0.5, dominantHue: 0, hasHighContrast: false, isMonochromatic: false, isLightBlueGray: false, averageSaturation: 0.5)
        }
        
        context.draw(cgImage, in: CGRect(origin: .zero, size: sampleSize))
        
        // Analyze pixels
        var totalBrightness: CGFloat = 0
        var hueHistogram: [Int: Int] = [:]
        var brightnessValues: [CGFloat] = []
        
        for y in stride(from: 0, to: Int(sampleSize.height), by: 2) {
            for x in stride(from: 0, to: Int(sampleSize.width), by: 2) {
                let index = (y * Int(sampleSize.width) + x) * bytesPerPixel
                
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                let brightness = 0.299 * r + 0.587 * g + 0.114 * b
                totalBrightness += brightness
                brightnessValues.append(brightness)
                
                // Track hue distribution
                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                
                if s > 0.1 { // Only count colors with some saturation
                    let hueKey = Int(h * 12) // Quantize to 12 hue buckets
                    hueHistogram[hueKey, default: 0] += 1
                }
            }
        }
        
        let pixelCount = (Int(sampleSize.width) * Int(sampleSize.height)) / 4
        let avgBrightness = totalBrightness / CGFloat(pixelCount)
        
        // Calculate contrast (standard deviation of brightness)
        let variance = brightnessValues.reduce(0) { sum, brightness in
            sum + pow(brightness - avgBrightness, 2)
        } / CGFloat(brightnessValues.count)
        let stdDev = sqrt(variance)
        let hasHighContrast = stdDev > 0.25
        
        // Find dominant hue
        let dominantHue = hueHistogram.max(by: { $0.value < $1.value })?.key ?? 0
        
        // Check if monochromatic - also check overall saturation
        var totalSaturation: CGFloat = 0
        var saturationCount = 0
        var blueGrayPixels = 0
        var totalColorDeviation: CGFloat = 0
        
        // Recalculate with saturation tracking and blue-gray detection
        for y in stride(from: 0, to: Int(sampleSize.height), by: 2) {
            for x in stride(from: 0, to: Int(sampleSize.width), by: 2) {
                let index = (y * Int(sampleSize.width) + x) * bytesPerPixel
                
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                
                totalSaturation += s
                saturationCount += 1
                
                // Detect blue-gray pixels (common in light blue covers)
                // Blue-gray has slight blue tint with low saturation
                if h > 0.5 && h < 0.75 && s < 0.3 && s > 0.05 {
                    blueGrayPixels += 1
                }
                
                // Calculate color deviation from pure gray
                let gray = (r + g + b) / 3.0
                let deviation = abs(r - gray) + abs(g - gray) + abs(b - gray)
                totalColorDeviation += deviation
            }
        }
        
        let avgSaturation = saturationCount > 0 ? totalSaturation / CGFloat(saturationCount) : 0
        let avgColorDeviation = saturationCount > 0 ? totalColorDeviation / CGFloat(saturationCount) : 0
        let blueGrayRatio = Double(blueGrayPixels) / Double(saturationCount)
        
        // More sophisticated monochromatic detection
        // Consider it monochromatic if:
        // 1. Low average saturation OR
        // 2. High blue-gray ratio (light blue covers) OR
        // 3. Low color deviation (close to grayscale)
        let isMonochromatic = avgSaturation < 0.15 || blueGrayRatio > 0.3 || avgColorDeviation < 0.1
        
        // Special case: light blue-gray covers (like "On Quality")
        let isLightBlueGray = avgBrightness > 0.6 && blueGrayRatio > 0.2 && avgSaturation < 0.25
        
        return CoverAnalysis(
            averageBrightness: avgBrightness,
            dominantHue: CGFloat(dominantHue) / 12.0,
            hasHighContrast: hasHighContrast,
            isMonochromatic: isMonochromatic,
            isLightBlueGray: isLightBlueGray,
            averageSaturation: avgSaturation
        )
    }
    
    // MARK: - Center Region Strategy
    private static func extractCenterRegionColors(_ cgImage: CGImage, analysis: CoverAnalysis) -> [AccentCandidate] {
        var candidates: [AccentCandidate] = []
        
        // Sample the center regions where titles often appear
        let regions = [
            CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.2), // Upper center (title area)
            CGRect(x: 0.3, y: 0.4, width: 0.4, height: 0.2), // Center
            CGRect(x: 0.2, y: 0.6, width: 0.6, height: 0.2), // Lower center
            CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.3), // Dead center (for central elements like rings)
        ]
        
        for region in regions {
            if let color = extractDominantNonBackgroundColor(cgImage, in: region, backgroundBrightness: analysis.averageBrightness) {
                candidates.append(color)
            }
        }
        
        return candidates
    }
    
    private static func extractDominantNonBackgroundColor(_ cgImage: CGImage, in region: CGRect, backgroundBrightness: CGFloat) -> AccentCandidate? {
        let width = cgImage.width
        let height = cgImage.height
        
        let regionRect = CGRect(
            x: Int(CGFloat(width) * region.origin.x),
            y: Int(CGFloat(height) * region.origin.y),
            width: Int(CGFloat(width) * region.size.width),
            height: Int(CGFloat(height) * region.size.height)
        )
        
        guard let croppedImage = cgImage.cropping(to: regionRect) else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * croppedImage.width
        
        var pixelData = [UInt8](repeating: 0, count: croppedImage.width * croppedImage.height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: croppedImage.width,
            height: croppedImage.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(croppedImage, in: CGRect(x: 0, y: 0, width: croppedImage.width, height: croppedImage.height))
        
        var colorFrequency: [String: (color: UIColor, count: Int, saturation: CGFloat)] = [:]
        
        // Sample colors and find non-background colors
        for y in stride(from: 0, to: croppedImage.height, by: 3) {
            for x in stride(from: 0, to: croppedImage.width, by: 3) {
                let index = (y * croppedImage.width + x) * bytesPerPixel
                
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                let brightness = 0.299 * r + 0.587 * g + 0.114 * b
                let brightnessDiff = abs(brightness - backgroundBrightness)
                
                // Skip colors too similar to background
                // For light covers, be more aggressive about finding contrast
                let minBrightnessDiff = backgroundBrightness > 0.6 ? 0.25 : 0.15
                if brightnessDiff < minBrightnessDiff { continue }
                
                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                
                // Prioritize saturated colors (likely text/graphics)
                if s > 0.2 || brightnessDiff > 0.4 {
                    let key = "\(Int(h * 36))-\(Int(s * 10))-\(Int(br * 10))"
                    if let existing = colorFrequency[key] {
                        colorFrequency[key] = (existing.color, existing.count + 1, s)
                    } else {
                        colorFrequency[key] = (color, 1, s)
                    }
                }
            }
        }
        
        // Find the most prominent non-background color
        if let best = colorFrequency.values
            .filter({ $0.count > 5 })
            .max(by: { 
                // Prioritize by saturation and frequency
                let score1 = $0.saturation * 2.0 + CGFloat($0.count) / 100.0
                let score2 = $1.saturation * 2.0 + CGFloat($1.count) / 100.0
                return score1 < score2
            }) {
            
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            best.color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            let uiColor = Color(
                hue: Double(h),
                saturation: Double(min(s * 1.3, 1.0)),
                brightness: Double(b)
            )
            
            let score = Double(s) * 3.0 + Double(best.count) / 100.0 + 2.0 // Center region bonus
            return AccentCandidate(color: uiColor, score: score, source: .center)
        }
        
        return nil
    }
    
    // MARK: - Edge Detection Strategy
    private static func extractEdgeColors(_ cgImage: CGImage, analysis: CoverAnalysis) -> [AccentCandidate] {
        var candidates: [AccentCandidate] = []
        
        // Apply edge detection to find text and graphic elements
        guard let edgeImage = applyEdgeDetection(to: cgImage) else { return candidates }
        
        // Sample colors near edges
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        var edgeData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let edgeContext = CGContext(
            data: &edgeData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return candidates }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        edgeContext.draw(edgeImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var colorFrequency: [String: (color: UIColor, count: Int)] = [:]
        
        // Sample colors where edges are detected
        for y in stride(from: 0, to: height, by: 5) {
            for x in stride(from: 0, to: width, by: 5) {
                let index = (y * width + x) * bytesPerPixel
                
                // Check if this pixel is an edge
                let edgeBrightness = CGFloat(edgeData[index]) / 255.0
                if edgeBrightness > 0.5 {
                    // Get the color from the original image
                    let r = CGFloat(pixelData[index]) / 255.0
                    let g = CGFloat(pixelData[index + 1]) / 255.0
                    let b = CGFloat(pixelData[index + 2]) / 255.0
                    
                    let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                    var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                    color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                    
                    // Consider all colors that aren't too dark or pure white
                    // Lower threshold to catch more text colors
                    // Special case for light covers: include dark colors even with low saturation
                    let isLightCover = analysis.averageBrightness > 0.6
                    let isDarkColor = br < 0.4
                    
                    if ((s > 0.15 || (isLightCover && isDarkColor)) || br < 0.2 || br > 0.8) && !(r > 0.95 && g > 0.95 && b > 0.95) {
                        let key = "\(Int(h * 36))-\(Int(s * 10))-\(Int(br * 10))"
                        if let existing = colorFrequency[key] {
                            colorFrequency[key] = (existing.color, existing.count + 1)
                        } else {
                            colorFrequency[key] = (color, 1)
                        }
                    }
                }
            }
        }
        
        // Convert to candidates
        let sortedColors = colorFrequency.values
            .filter { $0.count > 10 }
            .sorted { $0.count > $1.count }
            .prefix(5)
        
        for (color, count) in sortedColors {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            // Boost saturation for UI use
            let uiColor = Color(
                hue: Double(h),
                saturation: Double(min(s * 1.2, 1.0)),
                brightness: Double(b)
            )
            
            let score = Double(s) * 2.0 + Double(count) / 1000.0 + 1.0 // Edge colors get bonus
            candidates.append(AccentCandidate(color: uiColor, score: score, source: .edge))
        }
        
        return candidates
    }
    
    // MARK: - Vibrant Colors Strategy
    private static func extractVibrantColors(_ cgImage: CGImage, analysis: CoverAnalysis) -> [AccentCandidate] {
        var candidates: [AccentCandidate] = []
        
        // Sample the image
        let sampleSize = CGSize(width: min(200, cgImage.width), height: min(300, cgImage.height))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * Int(sampleSize.width)
        
        var pixelData = [UInt8](repeating: 0, count: Int(sampleSize.width * sampleSize.height) * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: Int(sampleSize.width),
            height: Int(sampleSize.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return candidates }
        
        context.draw(cgImage, in: CGRect(origin: .zero, size: sampleSize))
        
        var vibrantColors: [String: (color: UIColor, vibrancy: CGFloat, count: Int)] = [:]
        
        for y in stride(from: 0, to: Int(sampleSize.height), by: 3) {
            for x in stride(from: 0, to: Int(sampleSize.width), by: 3) {
                let index = (y * Int(sampleSize.width) + x) * bytesPerPixel
                
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                
                // Calculate vibrancy score
                let vibrancy = s * (0.5 + br * 0.5) // Balance saturation and brightness
                
                // For monochromatic covers, include grays and low saturation colors
                // For light covers, also include dark colors with lower vibrancy thresholds
                let vibrancyThreshold = analysis.averageBrightness > 0.6 ? 0.2 : 0.4
                if vibrancy > vibrancyThreshold || (analysis.isMonochromatic && s < 0.2 && br > 0.2 && br < 0.8) || (analysis.isLightBlueGray && br < 0.4) {
                    let key = "\(Int(h * 36))-\(Int(s * 10))-\(Int(br * 10))"
                    if let existing = vibrantColors[key] {
                        vibrantColors[key] = (existing.color, max(existing.vibrancy, vibrancy), existing.count + 1)
                    } else {
                        vibrantColors[key] = (color, vibrancy, 1)
                    }
                }
            }
        }
        
        // Sort by vibrancy and frequency
        let sortedColors = vibrantColors.values
            .filter { $0.count > 5 }
            .sorted { $0.vibrancy * CGFloat($0.count) > $1.vibrancy * CGFloat($1.count) }
            .prefix(5)
        
        for (color, vibrancy, count) in sortedColors {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            let uiColor = Color(
                hue: Double(h),
                saturation: Double(min(s * 1.1, 1.0)),
                brightness: Double(min(b * 1.1, 0.9))
            )
            
            let score = Double(vibrancy) * 1.5 + Double(count) / 1000.0
            candidates.append(AccentCandidate(color: uiColor, score: score, source: .vibrant))
        }
        
        return candidates
    }
    
    // MARK: - Statistical Outliers Strategy
    private static func extractOutlierColors(_ cgImage: CGImage, analysis: CoverAnalysis) -> [AccentCandidate] {
        var candidates: [AccentCandidate] = []
        
        // If the cover is very dark or very light, look for colors that stand out
        if analysis.averageBrightness < 0.3 || analysis.averageBrightness > 0.7 {
            // Sample specific regions where accent colors often appear
            let regions = [
                CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.3), // Top region (titles)
                CGRect(x: 0.0, y: 0.4, width: 1.0, height: 0.2), // Middle stripe
                CGRect(x: 0.1, y: 0.7, width: 0.8, height: 0.2), // Bottom region
                CGRect(x: 0.0, y: 0.0, width: 0.2, height: 1.0), // Left edge
                CGRect(x: 0.8, y: 0.0, width: 0.2, height: 1.0)  // Right edge
            ]
            
            for region in regions {
                if let outlierColor = findOutlierInRegion(cgImage, region: region, backgroundBrightness: analysis.averageBrightness) {
                    candidates.append(outlierColor)
                }
            }
        }
        
        return candidates
    }
    
    // MARK: - Helper Methods
    private static func applyEdgeDetection(to cgImage: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: cgImage)
        
        // Use Sobel edge detection
        let edges = ciImage
            .applyingFilter("CIEdges", parameters: ["inputIntensity": 10.0])
            .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 1.0])
        
        let context = CIContext()
        return context.createCGImage(edges, from: edges.extent)
    }
    
    private static func findOutlierInRegion(_ cgImage: CGImage, region: CGRect, backgroundBrightness: CGFloat) -> AccentCandidate? {
        let width = cgImage.width
        let height = cgImage.height
        
        let regionRect = CGRect(
            x: Int(CGFloat(width) * region.origin.x),
            y: Int(CGFloat(height) * region.origin.y),
            width: Int(CGFloat(width) * region.size.width),
            height: Int(CGFloat(height) * region.size.height)
        )
        
        guard let croppedImage = cgImage.cropping(to: regionRect) else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * croppedImage.width
        
        var pixelData = [UInt8](repeating: 0, count: croppedImage.width * croppedImage.height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: croppedImage.width,
            height: croppedImage.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(croppedImage, in: CGRect(x: 0, y: 0, width: croppedImage.width, height: croppedImage.height))
        
        var bestOutlier: (color: UIColor, score: CGFloat)?
        
        for y in stride(from: 0, to: croppedImage.height, by: 5) {
            for x in stride(from: 0, to: croppedImage.width, by: 5) {
                let index = (y * croppedImage.width + x) * bytesPerPixel
                
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                let brightness = 0.299 * r + 0.587 * g + 0.114 * b
                let brightnessDiff = abs(brightness - backgroundBrightness)
                
                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                
                // Score based on how much it stands out
                let outlierScore = brightnessDiff * 2.0 + s * 1.5
                
                if outlierScore > 0.8 && s > 0.3 {
                    if bestOutlier == nil || outlierScore > bestOutlier!.score {
                        bestOutlier = (color, outlierScore)
                    }
                }
            }
        }
        
        if let (color, score) = bestOutlier {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            let uiColor = Color(
                hue: Double(h),
                saturation: Double(min(s * 1.2, 1.0)),
                brightness: Double(min(b * 1.1, 0.9))
            )
            
            return AccentCandidate(color: uiColor, score: Double(score), source: .outlier)
        }
        
        return nil
    }
    
    // MARK: - Candidate Ranking
    private static func rankCandidates(_ candidates: [AccentCandidate], coverAnalysis: CoverAnalysis) -> [AccentCandidate] {
        var rankedCandidates = candidates
        
        // Adjust scores based on cover characteristics
        for i in 0..<rankedCandidates.count {
            var candidate = rankedCandidates[i]
            let uiColor = UIColor(candidate.color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            // Special boost for gold/yellow colors (often important accent elements)
            // Use same range as detection for consistency
            let isGold = h >= 0.05 && h <= 0.20 && s > 0.3 && b > 0.4
            if isGold {
                candidate.score += 1.5 // Stronger boost for gold/yellow
                print("🏆 Found gold/yellow accent: H:\(h) S:\(s) B:\(b)")
            }
            
            // Bonus for colors that contrast with the background
            if coverAnalysis.averageBrightness < 0.3 && b > 0.6 {
                candidate.score += 0.5 // Bright colors on dark backgrounds
            } else if coverAnalysis.averageBrightness > 0.7 && b < 0.4 {
                candidate.score += 0.5 // Dark colors on light backgrounds
            }
            
            // Bonus for saturated colors
            if s > 0.7 {
                candidate.score += 0.3
            }
            
            // Special handling for light blue-gray covers (like "On Quality")
            if coverAnalysis.isLightBlueGray {
                // For light blue-gray covers, we need high contrast
                // Prefer darker colors or highly saturated colors
                if b < 0.4 || s > 0.7 {
                    candidate.score += 1.0 // Strong boost for contrast
                }
                // Penalize colors too similar to the background
                if h > 0.5 && h < 0.75 && s < 0.3 && b > 0.5 {
                    candidate.score *= 0.3 // Strong penalty
                }
            }
            // For monochromatic covers, boost colors that match the cover's tone
            else if coverAnalysis.isMonochromatic {
                // If it's a blue-gray cover, boost blue-gray colors
                if coverAnalysis.dominantHue > 0.5 && coverAnalysis.dominantHue < 0.75 && h > 0.5 && h < 0.75 {
                    candidate.score += 0.5
                }
                // For true grayscale, prefer the actual gray
                if s < 0.15 {
                    candidate.score += 0.3
                }
            } else {
                // Penalty for colors too similar to the dominant hue (for colorful covers)
                let hueDiff = abs(h - coverAnalysis.dominantHue)
                if hueDiff < 0.1 && !isGold { // Don't penalize gold
                    candidate.score *= 0.8
                }
            }
            
            // Bonus for center and edge-detected colors (likely text/graphics)
            // Edge detection often finds text which is usually the primary accent
            if candidate.source == .edge {
                candidate.score += 1.0 // Highest priority for text/graphics
            } else if candidate.source == .center {
                candidate.score += 0.8 // High priority for center elements
            }
            
            rankedCandidates[i] = candidate
        }
        
        // Sort by score
        rankedCandidates.sort { $0.score > $1.score }
        
        // If we have multiple candidates with similar scores, prefer the more saturated one
        if rankedCandidates.count >= 2 {
            let topScore = rankedCandidates[0].score
            let similarCandidates = rankedCandidates.filter { abs($0.score - topScore) < 0.2 }
            
            if similarCandidates.count > 1 {
                let mostSaturated = similarCandidates.max { first, second in
                    let firstUI = UIColor(first.color)
                    let secondUI = UIColor(second.color)
                    var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0
                    var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0
                    firstUI.getHue(&h1, saturation: &s1, brightness: &b1, alpha: nil)
                    secondUI.getHue(&h2, saturation: &s2, brightness: &b2, alpha: nil)
                    return s1 < s2
                }
                
                if let best = mostSaturated {
                    rankedCandidates.removeAll { $0.color == best.color }
                    rankedCandidates.insert(best, at: 0)
                }
            }
        }
        
        return rankedCandidates
    }
    
    // MARK: - Fallback Generation
    private static func generateFallbackAccent(for analysis: CoverAnalysis) -> Color {
        print("⚠️ Using fallback accent color generation")
        
        // Special handling for light blue-gray covers
        if analysis.isLightBlueGray {
            print("🔵 Light blue-gray cover detected - using high contrast accent")
            // For light blue-gray, use a deep blue or charcoal for maximum contrast
            if analysis.averageSaturation > 0.1 {
                // If there's some blue tint, use deep blue
                return Color(hue: 0.6, saturation: 0.8, brightness: 0.3)
            } else {
                // Otherwise use dark charcoal
                return Color(white: 0.25)
            }
        }
        else if analysis.isMonochromatic {
            // Monochromatic/grayscale covers
            // Check the dominant hue to see if it's actually blue-gray
            if analysis.dominantHue > 0.5 && analysis.dominantHue < 0.75 {
                // Blue-gray monochromatic - use the actual blue-gray
                print("🔵 Detected blue-gray monochromatic cover")
                return Color(hue: Double(analysis.dominantHue), saturation: 0.25, brightness: 0.55)
            } else if analysis.averageBrightness < 0.3 {
                // Dark monochromatic - use light gray
                return Color(white: 0.7)
            } else {
                // Light monochromatic - use dark gray
                return Color(white: 0.3)
            }
        } else if analysis.averageBrightness < 0.3 {
            // Dark cover - use warm accent
            return Color(hue: 0.08, saturation: 0.8, brightness: 0.9) // Warm orange
        } else if analysis.averageBrightness > 0.7 {
            // Light cover - check dominant hue first
            if analysis.dominantHue > 0.5 && analysis.dominantHue < 0.75 {
                // Light blue cover - use blue
                return Color(hue: Double(analysis.dominantHue), saturation: 0.5, brightness: 0.6)
            } else if analysis.isMonochromatic {
                // Light monochromatic - use dark gray for contrast
                return Color(white: 0.3)
            } else {
                // Light covers (white, beige, cream) - try harder to find actual accent colors
                // Only use brown as absolute last resort
                print("🎨 Light cover detected - defaulting to neutral dark accent")
                return Color(red: 0.25, green: 0.25, blue: 0.28) // Cool dark gray (more neutral)
            }
        } else {
            // Default based on dominant hue
            if analysis.dominantHue < 0.1 || analysis.dominantHue > 0.9 {
                // Reddish - use the red
                return Color(hue: Double(analysis.dominantHue), saturation: 0.8, brightness: 0.8)
            } else if analysis.dominantHue > 0.1 && analysis.dominantHue < 0.2 {
                // Orange/yellow - use it
                return Color(hue: Double(analysis.dominantHue), saturation: 0.9, brightness: 0.85)
            } else {
                // Other colors - enhance them
                return Color(hue: Double(analysis.dominantHue), saturation: 0.7, brightness: 0.7)
            }
        }
    }
    
    // MARK: - Utility Methods
    private static func describeColor(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        let hue = Int(h * 360)
        let saturation = Int(s * 100)
        let brightness = Int(b * 100)
        
        // Get color name
        let colorName: String
        switch hue {
        case 0...10, 340...360: colorName = "Red"
        case 11...40: colorName = "Orange"
        case 41...70: colorName = "Yellow"
        case 71...160: colorName = "Green"
        case 161...250: colorName = "Blue"
        case 251...290: colorName = "Purple"
        case 291...339: colorName = "Pink"
        default: colorName = "Unknown"
        }
        
        return "\(colorName) (H:\(hue)° S:\(saturation)% B:\(brightness)%)"
    }
    
    // MARK: - Data Structures
    private struct CoverAnalysis {
        let averageBrightness: CGFloat
        let dominantHue: CGFloat
        let hasHighContrast: Bool
        let isMonochromatic: Bool
        let isLightBlueGray: Bool
        let averageSaturation: CGFloat
    }
    
    private struct AccentCandidate {
        var color: Color
        var score: Double
        let source: ExtractionSource
    }
    
    private enum ExtractionSource {
        case center     // From center region (likely title/main element)
        case edge       // From edge detection (likely text/graphics)
        case vibrant    // From vibrant color extraction
        case outlier    // From statistical outlier detection
    }
    
    // MARK: - Gold Detection Check
    private static func checkForGoldElements(_ cgImage: CGImage) -> Bool {
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var goldPixelCount = 0
        let totalPixels = width * height
        
        // Sample every 5th pixel for better accuracy
        let sampleStep = 5
        var sampledPixels = 0
        
        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let index = (y * width + x) * bytesPerPixel
                
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                
                // Check for gold/yellow hues - expanded range and lower thresholds
                if h >= 0.05 && h <= 0.20 && s > 0.2 && br > 0.3 {
                    goldPixelCount += 1
                }
                sampledPixels += 1
            }
        }
        
        // Consider it has gold if more than 0.3% of sampled pixels are gold (lowered threshold)
        let goldPercentage = Double(goldPixelCount * 100) / Double(sampledPixels)
        print("🔍 Gold pixel percentage: \(goldPercentage)%")
        return goldPercentage > 0.3
    }
    
    // MARK: - Special Gold Extraction
    private static func extractGoldAccent(from cgImage: CGImage) -> Color? {
        print("🏆 Looking for gold/yellow accent colors")
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var goldCandidates: [(color: UIColor, score: CGFloat)] = []
        var goldPixelCount = 0
        
        // Focus on center and lower portions where the ring often appears
        let scanRegions = [
            (startY: height / 3, endY: 2 * height / 3),     // Middle third
            (startY: height / 2, endY: 3 * height / 4),     // Lower middle
            (startY: 2 * height / 3, endY: height)          // Bottom third
        ]
        
        for region in scanRegions {
            for y in stride(from: region.startY, to: region.endY, by: 2) {
                for x in stride(from: 0, to: width, by: 2) {
                    let index = (y * width + x) * bytesPerPixel
                    
                    let r = CGFloat(pixelData[index]) / 255.0
                    let g = CGFloat(pixelData[index + 1]) / 255.0
                    let b = CGFloat(pixelData[index + 2]) / 255.0
                    
                    let color = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                    var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                    color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                    
                    // Look for gold/yellow hues (0.05 to 0.20) - expanded range
                    if h >= 0.05 && h <= 0.20 && s > 0.15 && br > 0.25 {
                        goldPixelCount += 1
                        // Score based on how "gold" it is
                        let goldScore = s * br * (1.0 - abs(h - 0.125) * 2.0) // Peak at 0.125 (yellow-gold)
                        goldCandidates.append((color, goldScore))
                    }
                }
            }
        }
        
        // Sort by score and take the best gold color
        goldCandidates.sort { $0.score > $1.score }
        
        if let bestGold = goldCandidates.first {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            bestGold.color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            print("🏆 Found gold accent: H:\(h * 360)° S:\(s * 100)% B:\(b * 100)%")
            
            // Enhance the gold more prominently
            return Color(
                hue: Double(h),
                saturation: Double(min(s * 1.4, 1.0)),
                brightness: Double(min(b * 1.2, 0.95))
            )
        }
        
        // If no gold found but we detected gold pixels, return a default warm gold
        if goldPixelCount > 0 {
            print("⚠️ Using default gold accent")
            return Color(hue: 0.125, saturation: 0.8, brightness: 0.85) // Warm gold
        }
        
        print("⚠️ No gold colors found in special extraction")
        return nil
    }
    
    // MARK: - Color Post-Processing
    private static func softenHarshColors(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        
        // Check if it's a pure red (hue near 0 or 1)
        let isRed = h < 0.05 || h > 0.95
        let isPureRed = isRed && s > 0.7 && b > 0.5
        
        if isPureRed {
            print("🔴 Detected vibrant red - keeping it prominent for book accents")
            // Only slightly reduce intensity to prevent harshness, but keep the red character
            // Books often use red as a deliberate accent color
            let newSaturation = s * 0.9 // Slightly reduce saturation
            let newBrightness = b * 0.95 // Barely reduce brightness
            
            return Color(
                hue: Double(h), // Keep original hue
                saturation: Double(newSaturation),
                brightness: Double(newBrightness)
            )
        }
        
        // Check for other harsh colors (very high saturation)
        if s > 0.85 && b > 0.7 {
            print("🎨 Detected harsh saturated color - softening")
            return Color(
                hue: Double(h),
                saturation: Double(s * 0.8),
                brightness: Double(b * 0.9)
            )
        }
        
        return color
    }
}