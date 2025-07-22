import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import simd

class ColorIntelligenceEngine: ObservableObject {
    private let context = CIContext()
    
    func extractAmbientPalette(from uiImage: UIImage) async -> AmbientPalette {
        guard let inputImage = CIImage(image: uiImage) else {
            print("Failed to create CIImage")
            return AmbientPalette.default
        }
        
        print("Starting enhanced color extraction for image size: \(uiImage.size)")
        
        // Step 1: Enhance image vibrancy before extraction
        let enhancedImage = enhanceImageVibrancy(inputImage)
        
        // Step 2: Smart resize for performance
        let resizedImage = resizeImage(enhancedImage, targetSize: CGSize(width: 150, height: 200))
        
        // Step 3: Extract pixel data with intelligent sampling
        let pixelData = extractPixelData(from: resizedImage)
        
        // Step 4: Perform enhanced k-means clustering
        let clusteredColors = performEnhancedKMeans(pixelData: pixelData, k: 7)
        
        // Step 5: Post-process and validate colors
        let processedColors = postProcessColors(clusteredColors, originalImage: uiImage)
        
        // Step 6: Calculate luminance and create palette
        let luminance = calculateAverageLuminance(processedColors)
        
        print("Final palette - Luminance: \(luminance)")
        for (index, color) in processedColors.enumerated() {
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            print("Color \(index): R:\(String(format: "%.2f", r)) G:\(String(format: "%.2f", g)) B:\(String(format: "%.2f", b)) Brightness:\(String(format: "%.2f", (r+g+b)/3))")
        }
        
        return AmbientPalette(
            primary: processedColors.first ?? .gray,
            accents: Array(processedColors.dropFirst()),
            luminance: luminance
        )
    }
    
    private func enhanceImageVibrancy(_ image: CIImage) -> CIImage {
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = image
        colorControls.saturation = 1.5      // Increased from 1.3
        colorControls.contrast = 1.2        // Increased from 1.1  
        colorControls.brightness = 0.1      // Increased from 0.05
        
        guard let enhanced = colorControls.outputImage else { return image }
        
        // Add exposure adjustment for extra brightness
        let exposureAdjust = CIFilter.exposureAdjust()
        exposureAdjust.inputImage = enhanced
        exposureAdjust.setValue(0.5, forKey: "inputEV")  // Half stop brighter
        
        return exposureAdjust.outputImage ?? enhanced
    }
    
    private func resizeImage(_ image: CIImage, targetSize: CGSize) -> CIImage {
        let scale = min(targetSize.width / image.extent.width,
                       targetSize.height / image.extent.height)
        
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = Float(scale)
        
        return filter.outputImage ?? image
    }
    
    private func extractPixelData(from image: CIImage) -> [(color: SIMD3<Float>, weight: Float, position: CGPoint)] {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return []
        }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return []
        }
        
        var pixelData: [(color: SIMD3<Float>, weight: Float, position: CGPoint)] = []
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        // Golden ratio points for better sampling
        let goldenPoints: [CGPoint] = [
            CGPoint(x: 0.5, y: 0.5),      // Center
            CGPoint(x: 0.382, y: 0.382),  // Golden ratio points
            CGPoint(x: 0.618, y: 0.382),
            CGPoint(x: 0.382, y: 0.618),
            CGPoint(x: 0.618, y: 0.618),
            CGPoint(x: 0.5, y: 0.2),      // Top center (often has title)
            CGPoint(x: 0.5, y: 0.8)       // Bottom center
        ]
        
        // Sample more densely around golden points
        let samplingStep = 3 // Sample every 3rd pixel
        
        for y in stride(from: 0, to: height, by: samplingStep) {
            for x in stride(from: 0, to: width, by: samplingStep) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                
                let r = Float(bytes[offset]) / 255.0
                let g = Float(bytes[offset + 1]) / 255.0
                let b = Float(bytes[offset + 2]) / 255.0
                
                let brightness = (r + g + b) / 3.0
                let saturation = calculateSaturation(r: r, g: g, b: b)
                
                // Skip very dark or very light pixels
                guard brightness > 0.1 && brightness < 0.95 else { continue }
                
                // Skip low saturation pixels unless they're mid-tone grays
                if saturation < 0.1 && (brightness < 0.3 || brightness > 0.7) {
                    continue
                }
                
                // Calculate position weight based on golden points
                let normalizedX = CGFloat(x) / CGFloat(width)
                let normalizedY = CGFloat(y) / CGFloat(height)
                let position = CGPoint(x: normalizedX, y: normalizedY)
                
                var weight: Float = 1.0
                
                // Increase weight for pixels near golden points
                for goldenPoint in goldenPoints {
                    let distance = hypot(normalizedX - goldenPoint.x, normalizedY - goldenPoint.y)
                    if distance < 0.2 {
                        weight += Float(1.0 - distance * 5.0) * 2.0
                    }
                }
                
                // Boost weight for saturated colors
                weight *= (1.0 + saturation)
                
                pixelData.append((
                    color: SIMD3<Float>(r, g, b),
                    weight: weight,
                    position: position
                ))
            }
        }
        
        print("Sampled \(pixelData.count) pixels with intelligent weighting")
        return pixelData
    }
    
    private func performEnhancedKMeans(pixelData: [(color: SIMD3<Float>, weight: Float, position: CGPoint)], k: Int) -> [Color] {
        guard !pixelData.isEmpty else { return [] }
        
        // K-means++ initialization for better starting centers
        var centers = initializeKMeansPlusPlus(pixelData: pixelData, k: k)
        var clusters: [[Int]] = Array(repeating: [], count: k)
        
        // Perform k-means iterations
        for _ in 0..<20 {
            // Clear clusters
            clusters = Array(repeating: [], count: k)
            
            // Assign pixels to nearest center
            for (index, pixel) in pixelData.enumerated() {
                var minDistance: Float = .infinity
                var nearestCluster = 0
                
                for (clusterIndex, center) in centers.enumerated() {
                    let distance = simd_distance(pixel.color, center)
                    if distance < minDistance {
                        minDistance = distance
                        nearestCluster = clusterIndex
                    }
                }
                
                clusters[nearestCluster].append(index)
            }
            
            // Update centers with weighted average
            var newCenters: [SIMD3<Float>] = []
            
            for cluster in clusters {
                if cluster.isEmpty {
                    // Keep the old center if cluster is empty
                    newCenters.append(centers[newCenters.count])
                } else {
                    var weightedSum = SIMD3<Float>(0, 0, 0)
                    var totalWeight: Float = 0
                    
                    for pixelIndex in cluster {
                        let pixel = pixelData[pixelIndex]
                        weightedSum += pixel.color * pixel.weight
                        totalWeight += pixel.weight
                    }
                    
                    newCenters.append(weightedSum / totalWeight)
                }
            }
            
            centers = newCenters
        }
        
        // Convert to Colors and sort by cluster size and vibrancy
        var colorClusters: [(color: Color, size: Int, vibrancy: Float)] = []
        
        for (index, cluster) in clusters.enumerated() {
            let center = centers[index]
            let color = Color(
                red: Double(center.x),
                green: Double(center.y),
                blue: Double(center.z)
            )
            
            let vibrancy = calculateVibrancy(r: center.x, g: center.y, b: center.z)
            colorClusters.append((color: color, size: cluster.count, vibrancy: vibrancy))
        }
        
        // Sort by vibrancy * size to get the most prominent vibrant colors
        colorClusters.sort { $0.vibrancy * Float($0.size) > $1.vibrancy * Float($1.size) }
        
        // Take top 5 colors
        return Array(colorClusters.prefix(5).map { $0.color })
    }
    
    private func initializeKMeansPlusPlus(pixelData: [(color: SIMD3<Float>, weight: Float, position: CGPoint)], k: Int) -> [SIMD3<Float>] {
        var centers: [SIMD3<Float>] = []
        
        // First center: weighted random selection favoring vibrant colors
        let weights = pixelData.map { pixel in
            let vibrancy = calculateVibrancy(r: pixel.color.x, g: pixel.color.y, b: pixel.color.z)
            return pixel.weight * vibrancy
        }
        
        let totalWeight = weights.reduce(0, +)
        var random = Float.random(in: 0..<totalWeight)
        var firstIndex = 0
        
        for (index, weight) in weights.enumerated() {
            random -= weight
            if random <= 0 {
                firstIndex = index
                break
            }
        }
        
        centers.append(pixelData[firstIndex].color)
        
        // Remaining centers using k-means++ algorithm
        for _ in 1..<k {
            var distances: [Float] = []
            
            for pixel in pixelData {
                let minDistance = centers.map { simd_distance(pixel.color, $0) }.min() ?? 0
                distances.append(minDistance * minDistance * pixel.weight)
            }
            
            let totalDistance = distances.reduce(0, +)
            var random = Float.random(in: 0..<totalDistance)
            
            for (index, distance) in distances.enumerated() {
                random -= distance
                if random <= 0 {
                    centers.append(pixelData[index].color)
                    break
                }
            }
        }
        
        return centers
    }
    
    private func postProcessColors(_ colors: [Color], originalImage: UIImage) -> [Color] {
        var processedColors = colors
        
        // Calculate average brightness
        let avgBrightness = colors.reduce(0.0) { sum, color in
            let uiColor = UIColor(color)
            var brightness: CGFloat = 0
            uiColor.getHue(nil, saturation: nil, brightness: &brightness, alpha: nil)
            return sum + brightness
        } / Double(colors.count)
        
        print("Average brightness before processing: \(avgBrightness)")
        
        // If too dark, boost all colors
        if avgBrightness < 0.5 {  // Changed from 0.4
            processedColors = processedColors.map { color in
                let uiColor = UIColor(color)
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                
                // More aggressive boost
                let newBrightness = min(1.0, b * 2.0 + 0.3)  // Changed from 1.5 + 0.2
                let newSaturation = min(1.0, s * 1.3)        // More saturation
                
                return Color(hue: h, saturation: newSaturation, brightness: newBrightness, opacity: a)
            }
        }
        
        // Always ensure the primary color is bright enough
        if let firstColor = processedColors.first {
            let uiColor = UIColor(firstColor)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            if b < 0.7 {  // Primary should always be bright
                processedColors[0] = Color(hue: h, saturation: s, brightness: 0.8, opacity: a)
            }
        }
        
        // Check for monochrome (all similar colors)
        if isMonochrome(colors: processedColors) {
            print("Detected monochrome cover, generating variations")
            processedColors = generateMonochromeVariations(baseColor: processedColors.first ?? .gray)
        }
        
        // Ensure we have at least one bright accent
        let brightestColor = processedColors.max { color1, color2 in
            UIColor(color1).brightness < UIColor(color2).brightness
        }
        
        if let brightest = brightestColor, UIColor(brightest).brightness < 0.6 {
            // Add a bright accent based on the primary color
            if let primary = processedColors.first {
                let brightAccent = createBrightAccent(from: primary)
                processedColors.insert(brightAccent, at: 1)
            }
        }
        
        // Limit to 5 colors and ensure variety
        processedColors = Array(processedColors.prefix(5))
        
        return processedColors
    }
    
    private func calculateSaturation(r: Float, g: Float, b: Float) -> Float {
        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)
        
        if maxVal == 0 { return 0 }
        return (maxVal - minVal) / maxVal
    }
    
    private func calculateVibrancy(r: Float, g: Float, b: Float) -> Float {
        let saturation = calculateSaturation(r: r, g: g, b: b)
        let brightness = (r + g + b) / 3.0
        
        // Vibrancy is high when saturation is high and brightness is moderate
        let brightnessScore = 1.0 - abs(brightness - 0.6) * 2.0 // Peak at 0.6 brightness
        return saturation * brightnessScore
    }
    
    private func isMonochrome(colors: [Color]) -> Bool {
        guard colors.count > 1 else { return false }
        
        let hues = colors.map { color -> CGFloat in
            let uiColor = UIColor(color)
            var h: CGFloat = 0
            uiColor.getHue(&h, saturation: nil, brightness: nil, alpha: nil)
            return h
        }
        
        // Check if all hues are within 30 degrees
        let minHue = hues.min() ?? 0
        let maxHue = hues.max() ?? 0
        
        return (maxHue - minHue) < 0.083 // 30 degrees in 0-1 scale
    }
    
    private func generateMonochromeVariations(baseColor: Color) -> [Color] {
        let uiColor = UIColor(baseColor)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        return [
            // Original
            baseColor,
            // Lighter version
            Color(hue: h, saturation: s * 0.7, brightness: min(1.0, b * 1.3), opacity: a),
            // Darker version
            Color(hue: h, saturation: s, brightness: b * 0.7, opacity: a),
            // Complementary accent
            Color(hue: (h + 0.5).truncatingRemainder(dividingBy: 1.0), saturation: s * 0.8, brightness: b, opacity: a),
            // Slightly shifted hue
            Color(hue: (h + 0.083).truncatingRemainder(dividingBy: 1.0), saturation: s, brightness: b * 0.9, opacity: a)
        ]
    }
    
    private func createBrightAccent(from color: Color) -> Color {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        // Create a bright, saturated version
        return Color(hue: h, saturation: min(1.0, s * 1.5), brightness: 0.9, opacity: a)
    }
    
    private func calculateAverageLuminance(_ colors: [Color]) -> Double {
        let luminances = colors.map { color in
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            return 0.299 * r + 0.587 * g + 0.114 * b
        }
        
        return luminances.reduce(0, +) / Double(colors.count)
    }
}

// MARK: - Extensions

extension UIColor {
    var brightness: CGFloat {
        var b: CGFloat = 0
        getHue(nil, saturation: nil, brightness: &b, alpha: nil)
        return b
    }
}


// MARK: - AmbientPalette Model

struct AmbientPalette: Equatable {
    let primary: Color
    let accents: [Color]
    let luminance: Double
    
    var colors: [Color] {
        [primary] + accents
    }
    
    static let `default` = AmbientPalette(
        primary: .blue,
        accents: [.purple, .indigo],
        luminance: 0.5
    )
}