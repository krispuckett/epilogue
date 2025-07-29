import SwiftUI
import UIKit
import Vision
import CoreImage
import Accelerate
import CryptoKit
import Foundation

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
    
    /// Extract color palette from UIImage using ColorCube-inspired 3D histogram
    public func extractPalette(from image: UIImage, imageSource: String = "Unknown") async throws -> ColorPalette {
        
        // Calculate checksum
        let _ = calculateChecksum(for: image)
        
        // Debug saving disabled
        // saveImageForDebug(image, suffix: "EXTRACTED_\(imageSource)")
        
        // Check image size to detect cropped covers
        if image.size.width < 100 || image.size.height < 100 {
            print("WARNING: Image too small (\(image.size.width)x\(image.size.height)), likely cropped!")
        }
        
        guard let cgImage = image.cgImage else {
            return createFallbackPalette()
        }
        
        return await extractPalette(from: cgImage, imageSource: imageSource)
    }
    
    /// Extract color palette from CGImage using ColorCube-inspired 3D histogram with async processing
    public func extractPalette(from cgImage: CGImage, imageSource: String) async -> ColorPalette {
        // Check if image needs downsampling
        let maxDimension: CGFloat = 400
        let scale = min(maxDimension / CGFloat(cgImage.width), maxDimension / CGFloat(cgImage.height), 1.0)
        
        if scale < 1.0 {
            print("  Image too large (\(cgImage.width)x\(cgImage.height)), downsampling to \(Int(CGFloat(cgImage.width) * scale))x\(Int(CGFloat(cgImage.height) * scale))")
            
            // Downsample image first
            if let downsampledImage = await downsampleImage(cgImage, scale: scale) {
                return await extractPaletteFromProcessedImage(downsampledImage, imageSource: imageSource, originalSize: CGSize(width: cgImage.width, height: cgImage.height))
            }
        }
        
        // Process directly if small enough
        return await extractPaletteFromProcessedImage(cgImage, imageSource: imageSource, originalSize: CGSize(width: cgImage.width, height: cgImage.height))
    }
    
    /// Downsample image for faster processing
    private func downsampleImage(_ cgImage: CGImage, scale: CGFloat) async -> CGImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let newWidth = Int(CGFloat(cgImage.width) * scale)
                let newHeight = Int(CGFloat(cgImage.height) * scale)
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                guard let context = CGContext(
                    data: nil,
                    width: newWidth,
                    height: newHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                context.interpolationQuality = .high
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                
                continuation.resume(returning: context.makeImage())
            }
        }
    }
    
    /// Extract color palette from already processed CGImage
    private func extractPaletteFromProcessedImage(_ cgImage: CGImage, imageSource: String, originalSize: CGSize) async -> ColorPalette {
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                let palette = self.extractPaletteSync(from: cgImage, imageSource: imageSource, originalSize: originalSize)
                continuation.resume(returning: palette)
            }
        }
    }
    
    /// Synchronous extraction (moved from original extractPalette)
    private func extractPaletteSync(from cgImage: CGImage, imageSource: String, originalSize: CGSize) -> ColorPalette {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow
        
        print("\nColorCube Extraction for \(imageSource)")
        print("  🚀 FRESH EXTRACTION STARTING (not from cache)")
        print("  Processing size: \(width)x\(height) = \(width * height) pixels")
        if originalSize.width > CGFloat(width) {
            print("  Original size: \(Int(originalSize.width))x\(Int(originalSize.height))")
        }
        
        // Add debug logging
        print("  Creating bitmap context...")
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return createFallbackPalette()
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        print("  Building ColorCube...")
        // Build 3D color histogram (ColorCube)
        let cubeSize = 16  // 16x16x16 = 4096 possible colors
        var colorCube = Array(repeating: Array(repeating: Array(repeating: 0, count: cubeSize), count: cubeSize), count: cubeSize)
        var totalValidPixels = 0
        var blackPixels = 0
        
        // COMMENT OUT THIS ENTIRE SECTION
        // print("  Starting edge detection...")
        // let edgePixels = detectEdges(pixelData: pixelData, width: width, height: height, bytesPerRow: bytesPerRow)
        // print("  Edge detection complete. Found \(edgePixels.count) edge pixels")
        
        // INSTEAD, just use an empty set
        let edgePixels: [(Int, Int)] = []
        print("  Skipping edge detection for performance...")
        
        print("  Building histogram from \(width * height) pixels...")
        // First pass: Build 3D histogram
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                guard offset + 3 < pixelData.count else { continue }
                
                let r = pixelData[offset]
                let g = pixelData[offset + 1]
                let b = pixelData[offset + 2]
                let a = pixelData[offset + 3]
                
                // Skip transparent
                if a < 128 { continue }
                
                let totalBrightness = Int(r) + Int(g) + Int(b)
                
                // Skip truly black pixels but keep dark colors
                if totalBrightness < 30 {
                    blackPixels += 1
                    continue
                }
                
                totalValidPixels += 1
                
                // Map to cube coordinates
                let cubeR = Int(r) * cubeSize / 256
                let cubeG = Int(g) * cubeSize / 256
                let cubeB = Int(b) * cubeSize / 256
                
                // Change this:
                // let weight = edgePixels.contains(where: { $0.0 == x && $0.1 == y }) ? 3 : 1
                
                // To this:
                let weight = 1
                colorCube[cubeR][cubeG][cubeB] += weight
            }
        }
        
        let blackPercentage = Double(blackPixels) * 100.0 / Double(width * height)
        let isDarkCover = blackPercentage > 70
        
        print("  Black pixels: \(String(format: "%.1f", blackPercentage))%")
        print("  Dark cover detected: \(isDarkCover)")
        
        // For dark covers, perform multi-scale analysis to find small accent colors
        if isDarkCover {
            print("\nPerforming multi-scale analysis for dark cover...")
            // Skip multi-scale if already downsampled significantly
            let wasDownsampled = originalSize.width > CGFloat(width) * 1.5
            if wasDownsampled {
                print("  Skipping multi-scale (already downsampled)")
            }
            
            let multiScaleColors = wasDownsampled ? [] : performMultiScaleAnalysis(cgImage: cgImage, pixelData: pixelData, width: width, height: height, bytesPerRow: bytesPerRow)
            
            // Merge multi-scale results into the main color cube
            for (color, weight) in multiScaleColors {
                // Map color to cube coordinates
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                
                let cubeR = Int(r * 255) * cubeSize / 256
                let cubeG = Int(g * 255) * cubeSize / 256
                let cubeB = Int(b * 255) * cubeSize / 256
                
                // Add weighted contribution
                colorCube[cubeR][cubeG][cubeB] += weight
            }
        }
        
        // Find local maxima in the color cube (distinct color peaks)
        var colorPeaks: [(color: UIColor, count: Int, distinctiveness: Double)] = []
        
        for r in 1..<(cubeSize-1) {
            for g in 1..<(cubeSize-1) {
                for b in 1..<(cubeSize-1) {
                    let centerCount = colorCube[r][g][b]
                    if centerCount < 10 { continue }  // Ignore noise
                    
                    // Check if this is a local maximum
                    var isLocalMax = true
                    var neighborSum = 0
                    
                    for dr in -1...1 {
                        for dg in -1...1 {
                            for db in -1...1 {
                                if dr == 0 && dg == 0 && db == 0 { continue }
                                let neighborCount = colorCube[r+dr][g+dg][b+db]
                                neighborSum += neighborCount
                                if neighborCount > centerCount {
                                    isLocalMax = false
                                }
                            }
                        }
                    }
                    
                    if isLocalMax {
                        // Convert back to color
                        let red = CGFloat(r) / CGFloat(cubeSize - 1)
                        let green = CGFloat(g) / CGFloat(cubeSize - 1)
                        let blue = CGFloat(b) / CGFloat(cubeSize - 1)
                        let color = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
                        
                        // Calculate distinctiveness (how different from neighbors)
                        let distinctiveness = Double(centerCount) / max(Double(neighborSum), 1.0)
                        
                        // For dark covers, boost bright accent colors
                        var adjustedCount = centerCount
                        if isDarkCover {
                            var h: CGFloat = 0, s: CGFloat = 0, brightness: CGFloat = 0
                            color.getHue(&h, saturation: &s, brightness: &brightness, alpha: nil)
                            if brightness > 0.5 && s > 0.5 {
                                adjustedCount *= 3  // Triple weight for bright colors on dark covers
                            }
                        }
                        
                        colorPeaks.append((color, adjustedCount, distinctiveness))
                    }
                }
            }
        }
        
        // Sort by visual importance (prioritize frequency for better color selection)
        colorPeaks.sort { peak1, peak2 in
            // For non-dark covers, prioritize frequency over distinctiveness
            if !isDarkCover {
                return peak1.count > peak2.count  // Sort by frequency first!
            } else {
                // For dark covers, still use combined score
                let score1 = Double(peak1.count) * peak1.distinctiveness
                let score2 = Double(peak2.count) * peak2.distinctiveness
                return score1 > score2
            }
        }
        
        print("\nFound \(colorPeaks.count) distinct color peaks")
        
        // After sorting peaks
        print("DEBUG: Sorted peaks for role assignment:")
        for (index, peak) in colorPeaks.prefix(3).enumerated() {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            peak.color.getRed(&r, green: &g, blue: &b, alpha: &a)
            print("  \(index+1). RGB(\(Int(r*255)), \(Int(g*255)), \(Int(b*255))) - Count: \(peak.count)")
        }
        
        // Filter out compression artifacts (colors that appear in regular patterns)
        let filteredPeaks = filterCompressionArtifacts(colorPeaks)
        
        // Select top colors based on visual importance
        var selectedColors: [UIColor] = []
        var colorInfo: [(color: UIColor, info: String)] = []
        
        for (index, peak) in filteredPeaks.prefix(6).enumerated() {
            selectedColors.append(peak.color)
            
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            peak.color.getRed(&r, green: &g, blue: &b, alpha: &a)
            var h: CGFloat = 0, s: CGFloat = 0, brightness: CGFloat = 0
            peak.color.getHue(&h, saturation: &s, brightness: &brightness, alpha: nil)
            
            let info = String(format: "Peak %d: RGB(%d,%d,%d) H:%d° S:%.2f B:%.2f - Count:%d Distinct:%.2f",
                            index + 1,
                            Int(r*255), Int(g*255), Int(b*255),
                            Int(h*360), s, brightness,
                            peak.count, peak.distinctiveness)
            colorInfo.append((peak.color, info))
            print("  \(info)")
        }
        
        // Ensure we have at least 4 colors
        while selectedColors.count < 4 {
            selectedColors.append(selectedColors.last ?? UIColor.black)
        }
        
        // Assign roles based on the sorted order (frequency)
        let roles = assignColorRolesDirectly(filteredPeaks, isDarkCover: isDarkCover)
        
        print("\nFinal ColorCube Palette:")
        print("  Primary: \(colorDescription(roles.primary))")
        print("  Secondary: \(colorDescription(roles.secondary))")
        print("  Accent: \(colorDescription(roles.accent))")
        print("  Background: \(colorDescription(roles.background))")
        
        return ColorPalette(
            primary: Color(roles.primary),
            secondary: Color(roles.secondary),
            accent: Color(roles.accent),
            background: Color(roles.background),
            textColor: luminance(of: roles.primary) > 0.5 ? .black : .white,
            luminance: luminance(of: roles.primary),
            isMonochromatic: false,
            extractionQuality: min(Double(selectedColors.count) / 4.0, 1.0)
        )
    }
    
    // Multi-scale analysis for finding small accent colors on dark covers
    private func performMultiScaleAnalysis(cgImage: CGImage, pixelData: [UInt8], width: Int, height: Int, bytesPerRow: Int) -> [(UIColor, Int)] {
        var aggregatedColors: [UIColor: Int] = [:]
        
        // Analyze at three scales: 25%, 50%, and 100%
        let scales: [(scale: CGFloat, weight: Double)] = [
            (1.0, 0.5),   // 100% scale = 50% weight
            (0.5, 0.3),   // 50% scale = 30% weight
            (0.25, 0.2)   // 25% scale = 20% weight
        ]
        
        for (scale, weight) in scales {
            print("  Analyzing at \(Int(scale * 100))% scale (weight: \(Int(weight * 100))%)...")
            
            if scale == 1.0 {
                // Use existing pixel data for 100% scale
                let colors = extractColorsFromPixelData(pixelData, width: width, height: height, bytesPerRow: bytesPerRow, skipBlack: true)
                
                // Apply weight
                for (color, count) in colors {
                    let weightedCount = Int(Double(count) * weight)
                    aggregatedColors[color, default: 0] += weightedCount
                }
            } else {
                // Create scaled version
                let scaledWidth = Int(CGFloat(width) * scale)
                let scaledHeight = Int(CGFloat(height) * scale)
                
                guard let scaledImage = resizeImage(cgImage, to: CGSize(width: scaledWidth, height: scaledHeight)) else {
                    continue
                }
                
                // Extract colors from scaled image
                let colors = extractColorsFromCGImage(scaledImage, skipBlack: true)
                
                // Apply weight and scale factor
                // Smaller images have concentrated colors, so boost their counts
                let scaleBoost = 1.0 / (scale * scale)  // Inverse square of scale
                for (color, count) in colors {
                    let weightedCount = Int(Double(count) * weight * scaleBoost)
                    aggregatedColors[color, default: 0] += weightedCount
                }
            }
        }
        
        // Filter for non-black, vibrant colors
        let vibrantColors = aggregatedColors.compactMap { (color, count) -> (UIColor, Int)? in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            var h: CGFloat = 0, s: CGFloat = 0, brightness: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &brightness, alpha: nil)
            
            // Keep colors that are bright or saturated (accent colors)
            if (brightness > 0.3 && s > 0.3) || brightness > 0.6 {
                return (color, count)
            }
            return nil
        }
        
        // Sort by weighted count
        let sortedColors = vibrantColors.sorted { $0.1 > $1.1 }
        
        print("  Found \(sortedColors.count) vibrant colors across scales")
        for (index, (color, count)) in sortedColors.prefix(5).enumerated() {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            print("    \(index + 1). RGB(\(Int(r*255)), \(Int(g*255)), \(Int(b*255))) - Weighted count: \(count)")
        }
        
        return sortedColors
    }
    
    // Helper: Extract colors from pixel data
    private func extractColorsFromPixelData(_ pixelData: [UInt8], width: Int, height: Int, bytesPerRow: Int, skipBlack: Bool) -> [(UIColor, Int)] {
        var colorHistogram: [UIColor: Int] = [:]
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * 4)
                guard offset + 3 < pixelData.count else { continue }
                
                let r = pixelData[offset]
                let g = pixelData[offset + 1]
                let b = pixelData[offset + 2]
                let a = pixelData[offset + 3]
                
                if a < 128 { continue }  // Skip transparent
                
                if skipBlack && (Int(r) + Int(g) + Int(b)) < 30 { continue }
                
                // Quantize color
                let quantizedR = round(CGFloat(r) / 255.0 * 10) / 10
                let quantizedG = round(CGFloat(g) / 255.0 * 10) / 10
                let quantizedB = round(CGFloat(b) / 255.0 * 10) / 10
                
                let color = UIColor(red: quantizedR, green: quantizedG, blue: quantizedB, alpha: 1.0)
                colorHistogram[color, default: 0] += 1
            }
        }
        
        return Array(colorHistogram)
    }
    
    // Helper: Extract colors from CGImage
    private func extractColorsFromCGImage(_ cgImage: CGImage, skipBlack: Bool) -> [(UIColor, Int)] {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow
        
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return extractColorsFromPixelData(pixelData, width: width, height: height, bytesPerRow: bytesPerRow, skipBlack: skipBlack)
    }
    
    // Helper: Resize CGImage
    private func resizeImage(_ cgImage: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = width * 4
        
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
    
    // Edge detection to find important visual elements
    private func detectEdges(pixelData: [UInt8], width: Int, height: Int, bytesPerRow: Int) -> [(Int, Int)] {
        var edgePixels: [(Int, Int)] = []
        
        // Simple Sobel edge detection
        for y in 1..<(height-1) {
            for x in 1..<(width-1) {
                let offset = (y * bytesPerRow) + (x * 4)
                guard offset + 3 < pixelData.count else { continue }
                
                // Get center pixel brightness
                let _ = Int(pixelData[offset]) + Int(pixelData[offset + 1]) + Int(pixelData[offset + 2])
                
                // Calculate gradient
                var gradientX = 0
                var gradientY = 0
                
                // Horizontal gradient
                let leftOffset = offset - 4
                let rightOffset = offset + 4
                if leftOffset >= 0 && rightOffset < pixelData.count {
                    let leftBrightness = Int(pixelData[leftOffset]) + Int(pixelData[leftOffset + 1]) + Int(pixelData[leftOffset + 2])
                    let rightBrightness = Int(pixelData[rightOffset]) + Int(pixelData[rightOffset + 1]) + Int(pixelData[rightOffset + 2])
                    gradientX = abs(rightBrightness - leftBrightness)
                }
                
                // Vertical gradient
                let topOffset = ((y - 1) * bytesPerRow) + (x * 4)
                let bottomOffset = ((y + 1) * bytesPerRow) + (x * 4)
                if topOffset >= 0 && bottomOffset < pixelData.count {
                    let topBrightness = Int(pixelData[topOffset]) + Int(pixelData[topOffset + 1]) + Int(pixelData[topOffset + 2])
                    let bottomBrightness = Int(pixelData[bottomOffset]) + Int(pixelData[bottomOffset + 1]) + Int(pixelData[bottomOffset + 2])
                    gradientY = abs(bottomBrightness - topBrightness)
                }
                
                // If gradient is strong, it's an edge
                if gradientX + gradientY > 100 {
                    edgePixels.append((x, y))
                }
            }
        }
        
        return edgePixels
    }
    
    // Filter out JPEG compression artifacts
    private func filterCompressionArtifacts(_ peaks: [(color: UIColor, count: Int, distinctiveness: Double)]) -> [(color: UIColor, count: Int, distinctiveness: Double)] {
        return peaks.filter { peak in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            peak.color.getRed(&r, green: &g, blue: &b, alpha: &a)
            
            // Skip colors that are likely compression artifacts
            // These tend to be very close to gray with specific patterns
            let maxDiff = max(abs(r - g), abs(g - b), abs(r - b))
            let avgValue = (r + g + b) / 3
            
            // Skip near-grays that aren't pure gray (compression artifacts)
            if maxDiff < 0.05 && maxDiff > 0.01 && avgValue > 0.2 && avgValue < 0.8 {
                return false
            }
            
            return true
        }
    }
    
    // Assign roles based on the already-sorted peaks (by frequency)
    private func assignColorRolesDirectly(_ sortedPeaks: [(color: UIColor, count: Int, distinctiveness: Double)], isDarkCover: Bool) -> (primary: UIColor, secondary: UIColor, accent: UIColor, background: UIColor) {
        
        if isDarkCover {
            // For dark covers, prefer bright/saturated colors for primary
            let brightPeaks = sortedPeaks.filter { peak in
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
                peak.color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
                return b > 0.5 || s > 0.6  // Bright or saturated
            }
            
            let primary = brightPeaks.first?.color ?? sortedPeaks[safe: 0]?.color ?? UIColor.orange
            let secondary = sortedPeaks[safe: 1]?.color ?? primary
            let accent = sortedPeaks[safe: 2]?.color ?? secondary
            
            // For dark covers, background should always be very dark
            let background = UIColor.black
            
            print("🎯 Dark Cover Role Assignment:")
            print("  Sorted order: \(sortedPeaks.prefix(4).map { colorDescription($0.color) + " (\($0.count)px)" })")
            print("  Bright peaks: \(brightPeaks.prefix(3).map { colorDescription($0.color) })")
            print("  Assigned roles:")
            print("    Primary: \(colorDescription(primary))")
            print("    Secondary: \(colorDescription(secondary))")
            print("    Accent: \(colorDescription(accent))")
            print("    Background: \(colorDescription(background))")
            
            return (primary, secondary, accent, background)
        } else {
            // For normal covers, just use frequency order directly
            let primary = sortedPeaks[safe: 0]?.color ?? UIColor.orange
            let secondary = sortedPeaks[safe: 1]?.color ?? primary
            let accent = sortedPeaks[safe: 2]?.color ?? secondary
            
            // Smart background selection
            let background: UIColor
            if let darkestPeak = sortedPeaks.last {
                // Check if the "background" candidate is actually dark
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
                darkestPeak.color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
                
                if b < 0.3 {
                    // Use it if actually dark
                    background = darkestPeak.color
                    print("  Using darkest color as background: \(colorDescription(darkestPeak.color)) (brightness: \(String(format: "%.2f", b)))")
                } else {
                    // Otherwise, try to find a dark color in the peaks
                    if let darkColor = sortedPeaks.first(where: { peak in
                        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
                        peak.color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
                        return b < 0.3
                    }) {
                        background = darkColor.color
                        print("  Found dark color for background: \(colorDescription(darkColor.color)) (brightness: \(String(format: "%.2f", b)))")
                    } else {
                        // Default to dark gray if no dark colors found
                        background = UIColor(white: 0.1, alpha: 1)
                        print("  No dark colors found, using default dark gray for background")
                    }
                }
            } else {
                // Fallback to dark gray
                background = UIColor(white: 0.1, alpha: 1)
                print("  No peaks available, using default dark gray for background")
            }
            
            print("🎯 Normal Cover Role Assignment (Pure Frequency):")
            print("  Sorted order: \(sortedPeaks.prefix(4).map { colorDescription($0.color) + " (\($0.count)px)" })")
            print("  Assigned roles:")
            print("    Primary: \(colorDescription(primary))")
            print("    Secondary: \(colorDescription(secondary))")
            print("    Accent: \(colorDescription(accent))")
            print("    Background: \(colorDescription(background))")
            
            return (primary, secondary, accent, background)
        }
    }
    
    
    
    // MARK: - Color Helper Functions
    
    
    private func luminance(of color: UIColor) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    }
    
    
    
    private func colorDescription(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return "RGB(\(Int(r*255)), \(Int(g*255)), \(Int(b*255)))"
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
        // Debug saving disabled - no longer saves to photo library
        /*
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
        */
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
            let _ = try await extractPalette(from: image)
            
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

