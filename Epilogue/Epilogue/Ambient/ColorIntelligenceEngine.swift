import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import simd
import Combine

class ColorIntelligenceEngine: ObservableObject {
    private let context = CIContext()
    
    func extractAmbientPalette(from uiImage: UIImage) async -> AmbientPalette {
        guard let inputImage = CIImage(image: uiImage) else {
            #if DEBUG
            print("Failed to create CIImage")
            #endif
            return AmbientPalette.default
        }
        
        #if DEBUG
        print("Starting enhanced color extraction for image size: \(uiImage.size)")
        #endif
        
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
        
        #if DEBUG
        print("Final palette - Luminance: \(luminance)")
        #endif
        for (index, color) in processedColors.enumerated() {
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            #if DEBUG
            print("Color \(index): R:\(String(format: "%.2f", r)) G:\(String(format: "%.2f", g)) B:\(String(format: "%.2f", b)) Brightness:\(String(format: "%.2f", (r+g+b)/3))")
            #endif
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
        colorControls.saturation = 1.8      // Much higher
        colorControls.contrast = 1.3        // More contrast
        colorControls.brightness = 0.2      // More brightness
        
        guard let enhanced = colorControls.outputImage else { return image }
        
        // Add exposure adjustment
        let exposureAdjust = CIFilter.exposureAdjust()
        exposureAdjust.inputImage = enhanced
        exposureAdjust.setValue(1.0, forKey: "inputEV")  // Full stop brighter (was 0.5)
        
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
        // First, apply edge detection to find important elements
        let edges = detectEdges(in: image)
        
        guard let cgImage = context.createCGImage(image, from: image.extent),
              let edgeCGImage = context.createCGImage(edges, from: edges.extent) else {
            return []
        }
        
        var pixelData: [(color: SIMD3<Float>, weight: Float, position: CGPoint)] = []
        
        // Strategy 1: Sample along edges (where important details are)
        pixelData.append(contentsOf: sampleAlongEdges(cgImage, edgeMap: edgeCGImage))
        
        // Strategy 2: Sample using spatial variance (avoid uniform areas)
        pixelData.append(contentsOf: sampleHighVarianceRegions(cgImage))
        
        // Strategy 3: Golden ratio sampling (existing)
        pixelData.append(contentsOf: sampleGoldenPoints(cgImage))
        
        #if DEBUG
        print("🎨 Multi-strategy sampling results:")
        #if DEBUG
        print("  Edge samples: \(sampleAlongEdges(cgImage, edgeMap: edgeCGImage).count)")
        #endif
        #if DEBUG
        print("  High variance samples: \(sampleHighVarianceRegions(cgImage).count)")
        #endif
        #if DEBUG
        print("  Golden point samples: \(sampleGoldenPoints(cgImage).count)")
        #endif
        #if DEBUG
        print("  Total samples: \(pixelData.count)")
        #endif
        #endif
        return pixelData
    }
    
    private func detectEdges(in image: CIImage) -> CIImage {
        // Use Sobel edge detection to find important features
        let edges = image
            .applyingFilter("CIEdges", parameters: ["inputIntensity": 10.0])
            .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 2.0])
        
        return edges
    }
    
    private func sampleAlongEdges(_ image: CGImage, edgeMap: CGImage) -> [(color: SIMD3<Float>, weight: Float, position: CGPoint)] {
        var samples: [(color: SIMD3<Float>, weight: Float, position: CGPoint)] = []
        
        // Get edge intensity data
        guard let edgeData = edgeMap.dataProvider?.data,
              let edgeBytes = CFDataGetBytePtr(edgeData),
              let imageData = image.dataProvider?.data,
              let imageBytes = CFDataGetBytePtr(imageData) else {
            return []
        }
        
        let width = image.width
        let height = image.height
        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow
        
        // Sample more densely where edges are strong
        for y in stride(from: 0, to: height, by: 3) {
            for x in stride(from: 0, to: width, by: 3) {
                let edgeOffset = y * edgeMap.bytesPerRow + x * (edgeMap.bitsPerPixel / 8)
                let edgeIntensity = Float(edgeBytes[edgeOffset]) / 255.0
                
                // Only sample where there's an edge
                if edgeIntensity > 0.3 {
                    let imageOffset = y * bytesPerRow + x * bytesPerPixel
                    
                    let r = Float(imageBytes[imageOffset]) / 255.0
                    let g = Float(imageBytes[imageOffset + 1]) / 255.0
                    let b = Float(imageBytes[imageOffset + 2]) / 255.0
                    
                    // Skip if it's too close to white or black
                    let brightness = (r + g + b) / 3.0
                    if brightness > 0.1 && brightness < 0.95 {
                        let saturation = calculateSaturation(r: r, g: g, b: b)
                        
                        // Higher weight for colorful pixels near edges
                        let weight = edgeIntensity * (1.0 + saturation * 2.0)
                        
                        samples.append((
                            color: SIMD3<Float>(r, g, b),
                            weight: weight,
                            position: CGPoint(x: CGFloat(x) / CGFloat(width), 
                                            y: CGFloat(y) / CGFloat(height))
                        ))
                    }
                }
            }
        }
        
        return samples
    }
    
    private func sampleHighVarianceRegions(_ image: CGImage) -> [(color: SIMD3<Float>, weight: Float, position: CGPoint)] {
        // Divide image into grid cells and calculate color variance
        let gridSize = 20
        let cellWidth = image.width / gridSize
        let cellHeight = image.height / gridSize
        
        var highVarianceSamples: [(color: SIMD3<Float>, weight: Float, position: CGPoint)] = []
        
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let variance = calculateCellVariance(
                    image: image,
                    x: col * cellWidth,
                    y: row * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
                
                // Only sample from high-variance cells (where interesting stuff is)
                if variance > 0.1 {
                    // Sample center of high-variance cell
                    let samples = sampleCell(
                        image: image,
                        x: col * cellWidth,
                        y: row * cellHeight,
                        width: cellWidth,
                        height: cellHeight,
                        weight: variance * 3.0
                    )
                    highVarianceSamples.append(contentsOf: samples)
                }
            }
        }
        
        return highVarianceSamples
    }
    
    private func calculateCellVariance(image: CGImage, x: Int, y: Int, width: Int, height: Int) -> Float {
        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0
        }
        
        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow
        
        var colors: [SIMD3<Float>] = []
        let sampleStep = 5
        
        for dy in stride(from: 0, to: height, by: sampleStep) {
            for dx in stride(from: 0, to: width, by: sampleStep) {
                let px = min(x + dx, image.width - 1)
                let py = min(y + dy, image.height - 1)
                let offset = py * bytesPerRow + px * bytesPerPixel
                
                let r = Float(bytes[offset]) / 255.0
                let g = Float(bytes[offset + 1]) / 255.0
                let b = Float(bytes[offset + 2]) / 255.0
                
                colors.append(SIMD3<Float>(r, g, b))
            }
        }
        
        guard colors.count > 1 else { return 0 }
        
        // Calculate variance
        let mean = colors.reduce(SIMD3<Float>(0, 0, 0), +) / Float(colors.count)
        let variance = colors.reduce(Float(0)) { sum, color in
            let diff = color - mean
            return sum + simd_length_squared(diff)
        } / Float(colors.count)
        
        return sqrt(variance)
    }
    
    private func sampleCell(image: CGImage, x: Int, y: Int, width: Int, height: Int, weight: Float) -> [(color: SIMD3<Float>, weight: Float, position: CGPoint)] {
        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return []
        }
        
        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow
        
        var samples: [(color: SIMD3<Float>, weight: Float, position: CGPoint)] = []
        
        // Sample a few points from the cell
        let samplePoints = [
            (dx: width / 2, dy: height / 2),
            (dx: width / 3, dy: height / 3),
            (dx: 2 * width / 3, dy: 2 * height / 3)
        ]
        
        for point in samplePoints {
            let px = min(x + point.dx, image.width - 1)
            let py = min(y + point.dy, image.height - 1)
            let offset = py * bytesPerRow + px * bytesPerPixel
            
            let r = Float(bytes[offset]) / 255.0
            let g = Float(bytes[offset + 1]) / 255.0
            let b = Float(bytes[offset + 2]) / 255.0
            
            let brightness = (r + g + b) / 3.0
            if brightness > 0.1 && brightness < 0.95 {
                samples.append((
                    color: SIMD3<Float>(r, g, b),
                    weight: weight,
                    position: CGPoint(x: CGFloat(px) / CGFloat(image.width),
                                    y: CGFloat(py) / CGFloat(image.height))
                ))
            }
        }
        
        return samples
    }
    
    private func sampleGoldenPoints(_ image: CGImage) -> [(color: SIMD3<Float>, weight: Float, position: CGPoint)] {
        guard let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return []
        }
        
        var pixelData: [(color: SIMD3<Float>, weight: Float, position: CGPoint)] = []
        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow
        
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
        
        // Sample around golden points
        for goldenPoint in goldenPoints {
            let centerX = Int(goldenPoint.x * CGFloat(image.width))
            let centerY = Int(goldenPoint.y * CGFloat(image.height))
            
            // Sample in a small radius around each golden point
            for dy in -10...10 {
                for dx in -10...10 {
                    let x = min(max(0, centerX + dx), image.width - 1)
                    let y = min(max(0, centerY + dy), image.height - 1)
                    
                    let offset = y * bytesPerRow + x * bytesPerPixel
                    
                    let r = Float(bytes[offset]) / 255.0
                    let g = Float(bytes[offset + 1]) / 255.0
                    let b = Float(bytes[offset + 2]) / 255.0
                    
                    let brightness = (r + g + b) / 3.0
                    let saturation = calculateSaturation(r: r, g: g, b: b)
                    
                    // Skip very dark or very light pixels
                    if brightness > 0.1 && brightness < 0.95 {
                        // Distance from golden point center
                        let distance = hypot(CGFloat(dx), CGFloat(dy)) / 10.0
                        let weight = Float(1.0 - distance) * (1.0 + saturation)
                        
                        pixelData.append((
                            color: SIMD3<Float>(r, g, b),
                            weight: weight,
                            position: CGPoint(x: CGFloat(x) / CGFloat(image.width),
                                            y: CGFloat(y) / CGFloat(image.height))
                        ))
                    }
                }
            }
        }
        
        return pixelData
    }
    
    private func performEnhancedKMeans(pixelData: [(color: SIMD3<Float>, weight: Float, position: CGPoint)], k: Int) -> [Color] {
        guard !pixelData.isEmpty else { return [] }
        
        // If we have very few unique colors (like white covers), reduce k
        let uniqueColors = Set(pixelData.map { 
            "\(Int($0.color.x * 10))-\(Int($0.color.y * 10))-\(Int($0.color.z * 10))" 
        })
        
        let effectiveK = min(k, max(3, uniqueColors.count))
        
        // Initialize with colors that have highest weight (most important)
        let sortedByWeight = pixelData.sorted { $0.weight > $1.weight }
        var centers: [SIMD3<Float>] = []
        
        // Take the most important colors as initial centers
        for i in 0..<effectiveK {
            if i < sortedByWeight.count {
                centers.append(sortedByWeight[i].color)
            }
        }
        var clusters: [[Int]] = Array(repeating: [], count: effectiveK)
        
        // Perform k-means iterations
        for _ in 0..<20 {
            // Clear clusters
            clusters = Array(repeating: [], count: effectiveK)
            
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
        
        #if DEBUG
        print("Average brightness before processing: \(avgBrightness)")
        #endif
        
        // Force minimum brightness for ALL colors
        processedColors = processedColors.map { color in
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            // Force minimum brightness of 0.5 for ALL colors
            let minBrightness: CGFloat = 0.5
            if b < minBrightness {
                return Color(hue: h, saturation: s, brightness: minBrightness, opacity: a)
            }
            
            // Otherwise boost by 50%
            let newBrightness = min(1.0, b * 1.5)
            let newSaturation = min(1.0, s * 1.4)
            
            return Color(hue: h, saturation: newSaturation, brightness: newBrightness, opacity: a)
        }
        
        // Ensure primary color is ALWAYS bright
        if let firstColor = processedColors.first {
            let uiColor = UIColor(firstColor)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            // Primary color should be at least 0.7 brightness
            if b < 0.7 {
                processedColors[0] = Color(hue: h, saturation: s, brightness: 0.8, opacity: a)
            }
        }
        
        // Check for monochrome (all similar colors)
        if isMonochrome(colors: processedColors) {
            #if DEBUG
            print("Detected monochrome cover, generating variations")
            #endif
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