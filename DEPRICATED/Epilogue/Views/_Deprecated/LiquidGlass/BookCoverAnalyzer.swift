import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Book Cover Analyzer
@MainActor
class BookCoverAnalyzer: ObservableObject {
    
    // MARK: - Color Analysis Result
    struct ColorAnalysis {
        let palette: ColorPalette
        let strategy: BackgroundStrategy
        let luminanceMap: LuminanceMap
        let dominantHue: Double
        let saturationLevel: SaturationLevel
        let coverType: CoverType
    }
    
    // MARK: - Color Palette
    struct ColorPalette {
        var primary: [Color] = []      // 2-3 dominant colors
        var secondary: [Color] = []    // 3-4 supporting colors
        var detail: [Color] = []       // 2-3 accent colors
        var glass: [Color] = []        // Colors optimized for glass effects
        
        var allColors: [Color] {
            primary + secondary + detail
        }
        
        var isEmpty: Bool {
            primary.isEmpty && secondary.isEmpty && detail.isEmpty
        }
    }
    
    // MARK: - Supporting Types
    struct LuminanceMap {
        let brightness: [[Double]] // 2D array of brightness values
        let averageLuminance: Double
        let contrastRatio: Double
        let darkRegions: [CGRect]
        let brightRegions: [CGRect]
    }
    
    enum SaturationLevel {
        case monochrome    // < 0.1
        case lowSaturation // 0.1 - 0.3
        case moderate      // 0.3 - 0.6
        case vibrant       // 0.6 - 0.8
        case hyperVibrant  // > 0.8
    }
    
    enum CoverType {
        case minimalistWhite  // White/light with small accents
        case watercolor       // Flowing, organic colors
        case photographic     // Photo-based cover
        case graphicDesign    // Bold geometric shapes
        case textHeavy        // Mostly text on solid background
        case complex          // Multi-element composition
    }
    
    // MARK: - Analysis Methods
    func analyzeCover(_ image: UIImage) async -> ColorAnalysis {
        guard let ciImage = CIImage(image: image) else {
            return ColorAnalysis(
                palette: ColorPalette(),
                strategy: .liquidGlass,
                luminanceMap: createEmptyLuminanceMap(),
                dominantHue: 0,
                saturationLevel: .moderate,
                coverType: .complex
            )
        }
        
        // Resize for performance
        let targetSize = CGSize(width: 200, height: 200)
        guard let resizedImage = await resizeImage(ciImage, to: targetSize) else {
            return ColorAnalysis(
                palette: ColorPalette(),
                strategy: .liquidGlass,
                luminanceMap: createEmptyLuminanceMap(),
                dominantHue: 0,
                saturationLevel: .moderate,
                coverType: .complex
            )
        }
        
        // Extract colors using multiple techniques
        let kMeansColors = await performKMeansClustering(resizedImage)
        let regionColors = await extractRegionalColors(resizedImage)
        let edgeColors = await extractEdgeColors(resizedImage)
        
        // Create luminance map
        let luminanceMap = await createLuminanceMap(resizedImage)
        
        // Analyze cover characteristics
        let coverType = determineCoverType(
            kMeansColors: kMeansColors,
            luminanceMap: luminanceMap
        )
        
        // Build color palette
        let palette = buildColorPalette(
            kMeans: kMeansColors,
            regional: regionColors,
            edge: edgeColors,
            coverType: coverType
        )
        
        // Determine saturation level
        let saturationLevel = calculateSaturationLevel(palette)
        
        // Calculate dominant hue
        let dominantHue = calculateDominantHue(palette.primary)
        
        // Select strategy
        let strategy = selectBackgroundStrategy(
            coverType: coverType,
            saturationLevel: saturationLevel,
            palette: palette
        )
        
        return ColorAnalysis(
            palette: palette,
            strategy: strategy,
            luminanceMap: luminanceMap,
            dominantHue: dominantHue,
            saturationLevel: saturationLevel,
            coverType: coverType
        )
    }
    
    // MARK: - K-Means Clustering
    private func performKMeansClustering(_ image: CIImage) async -> [UIColor] {
        // Sample pixels from the image
        let pixels = await samplePixels(from: image, sampleRate: 0.1)
        
        // Perform k-means with k=12
        let clusters = kMeans(pixels: pixels, k: 12, iterations: 20)
        
        // Sort by weight and return top colors
        return clusters
            .sorted { $0.weight > $1.weight }
            .map { $0.centroid }
    }
    
    private struct ColorCluster {
        var centroid: UIColor
        var pixels: [UIColor]
        var weight: Double
    }
    
    private func kMeans(pixels: [UIColor], k: Int, iterations: Int) -> [ColorCluster] {
        // Initialize centroids using k-means++
        var centroids = kMeansPlusPlus(pixels: pixels, k: k)
        var clusters = [ColorCluster]()
        
        for _ in 0..<iterations {
            // Reset clusters
            clusters = centroids.map { ColorCluster(centroid: $0, pixels: [], weight: 0) }
            
            // Assign pixels to nearest centroid
            for pixel in pixels {
                let nearestIndex = findNearestCentroid(pixel: pixel, centroids: centroids)
                clusters[nearestIndex].pixels.append(pixel)
            }
            
            // Update centroids
            for i in 0..<k {
                if !clusters[i].pixels.isEmpty {
                    centroids[i] = averageColor(clusters[i].pixels)
                    clusters[i].centroid = centroids[i]
                    clusters[i].weight = Double(clusters[i].pixels.count) / Double(pixels.count)
                }
            }
        }
        
        return clusters.filter { !$0.pixels.isEmpty }
    }
    
    private func kMeansPlusPlus(pixels: [UIColor], k: Int) -> [UIColor] {
        guard !pixels.isEmpty else { return [] }
        
        var centroids = [UIColor]()
        
        // Choose first centroid randomly
        centroids.append(pixels.randomElement()!)
        
        // Choose remaining centroids
        for _ in 1..<k {
            var distances = [Double]()
            
            // Calculate distance to nearest centroid for each pixel
            for pixel in pixels {
                let minDistance = centroids.map { colorDistance(pixel, $0) }.min() ?? 0
                distances.append(minDistance * minDistance)
            }
            
            // Choose next centroid with probability proportional to squared distance
            let totalDistance = distances.reduce(0, +)
            if totalDistance > 0 {
                let random = Double.random(in: 0..<totalDistance)
                var cumulative = 0.0
                
                for (index, distance) in distances.enumerated() {
                    cumulative += distance
                    if cumulative >= random {
                        centroids.append(pixels[index])
                        break
                    }
                }
            }
        }
        
        return centroids
    }
    
    // MARK: - Regional Color Extraction
    private func extractRegionalColors(_ image: CIImage) async -> [UIColor] {
        let width = image.extent.width
        let height = image.extent.height
        
        // Define regions using golden ratio
        let phi = (1 + sqrt(5)) / 2
        let regions = [
            CGRect(x: 0, y: 0, width: width/phi, height: height/phi), // Top left
            CGRect(x: width - width/phi, y: 0, width: width/phi, height: height/phi), // Top right
            CGRect(x: 0, y: height - height/phi, width: width/phi, height: height/phi), // Bottom left
            CGRect(x: width - width/phi, y: height - height/phi, width: width/phi, height: height/phi), // Bottom right
            CGRect(x: width/2 - width/(phi*2), y: height/2 - height/(phi*2), width: width/phi, height: height/phi) // Center
        ]
        
        var colors = [UIColor]()
        
        for region in regions {
            if let color = await extractDominantColor(from: image, in: region) {
                colors.append(color)
            }
        }
        
        return colors
    }
    
    // MARK: - Edge Color Extraction
    private func extractEdgeColors(_ image: CIImage) async -> [UIColor] {
        // Apply edge detection filter
        guard let edges = applyEdgeDetection(to: image) else { return [] }
        
        // Sample colors along detected edges
        let edgePixels = await samplePixels(from: edges, sampleRate: 0.05)
        
        // Cluster edge colors
        let clusters = kMeans(pixels: edgePixels, k: 4, iterations: 10)
        
        return clusters
            .sorted { $0.weight > $1.weight }
            .map { $0.centroid }
    }
    
    private func applyEdgeDetection(to image: CIImage) -> CIImage? {
        let filter = CIFilter(name: "CIEdgeWork")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(6.0, forKey: kCIInputRadiusKey)
        return filter?.outputImage
    }
    
    // MARK: - Luminance Map Creation
    private func createLuminanceMap(_ image: CIImage) async -> LuminanceMap {
        let gridSize = 10
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        let cellWidth = width / gridSize
        let cellHeight = height / gridSize
        
        var brightness = [[Double]]()
        var totalLuminance = 0.0
        var darkRegions = [CGRect]()
        var brightRegions = [CGRect]()
        
        for y in 0..<gridSize {
            var row = [Double]()
            for x in 0..<gridSize {
                let rect = CGRect(
                    x: x * cellWidth,
                    y: y * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
                
                let luminance = await calculateAverageLuminance(image, in: rect)
                row.append(luminance)
                totalLuminance += luminance
                
                if luminance < 0.3 {
                    darkRegions.append(rect)
                } else if luminance > 0.7 {
                    brightRegions.append(rect)
                }
            }
            brightness.append(row)
        }
        
        let averageLuminance = totalLuminance / Double(gridSize * gridSize)
        let contrastRatio = calculateContrastRatio(brightness)
        
        return LuminanceMap(
            brightness: brightness,
            averageLuminance: averageLuminance,
            contrastRatio: contrastRatio,
            darkRegions: darkRegions,
            brightRegions: brightRegions
        )
    }
    
    // MARK: - Helper Methods
    private func resizeImage(_ image: CIImage, to size: CGSize) async -> CIImage? {
        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = image
        filter.scale = Float(size.width / image.extent.width)
        return filter.outputImage
    }
    
    private func samplePixels(from image: CIImage, sampleRate: Double) async -> [UIColor] {
        let context = CIContext()
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return [] }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let bitmapContext = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        
        bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var colors = [UIColor]()
        let step = Int(1.0 / sampleRate)
        
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let index = (y * width + x) * bytesPerPixel
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                colors.append(UIColor(red: r, green: g, blue: b, alpha: 1.0))
            }
        }
        
        return colors
    }
    
    private func extractDominantColor(from image: CIImage, in region: CGRect) async -> UIColor? {
        let cropped = image.cropped(to: region)
        let pixels = await samplePixels(from: cropped, sampleRate: 0.2)
        return averageColor(pixels)
    }
    
    private func colorDistance(_ c1: UIColor, _ c2: UIColor) -> Double {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: nil)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: nil)
        
        let dr = Double(r1 - r2)
        let dg = Double(g1 - g2)
        let db = Double(b1 - b2)
        
        return sqrt(dr * dr + dg * dg + db * db)
    }
    
    private func averageColor(_ colors: [UIColor]) -> UIColor {
        guard !colors.isEmpty else { return .gray }
        
        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0
        
        for color in colors {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            totalR += r
            totalG += g
            totalB += b
        }
        
        let count = CGFloat(colors.count)
        return UIColor(red: totalR / count, green: totalG / count, blue: totalB / count, alpha: 1.0)
    }
    
    private func findNearestCentroid(pixel: UIColor, centroids: [UIColor]) -> Int {
        var minDistance = Double.infinity
        var nearestIndex = 0
        
        for (index, centroid) in centroids.enumerated() {
            let distance = colorDistance(pixel, centroid)
            if distance < minDistance {
                minDistance = distance
                nearestIndex = index
            }
        }
        
        return nearestIndex
    }
    
    private func calculateAverageLuminance(_ image: CIImage, in rect: CGRect) async -> Double {
        let cropped = image.cropped(to: rect)
        let pixels = await samplePixels(from: cropped, sampleRate: 0.5)
        
        var totalLuminance = 0.0
        for pixel in pixels {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            pixel.getRed(&r, green: &g, blue: &b, alpha: nil)
            // Use standard luminance formula
            totalLuminance += Double(0.299 * r + 0.587 * g + 0.114 * b)
        }
        
        return totalLuminance / Double(pixels.count)
    }
    
    private func calculateContrastRatio(_ brightness: [[Double]]) -> Double {
        let flattened = brightness.flatMap { $0 }
        guard !flattened.isEmpty else { return 1.0 }
        
        let min = flattened.min() ?? 0
        let max = flattened.max() ?? 1
        
        return (max + 0.05) / (min + 0.05)
    }
    
    private func createEmptyLuminanceMap() -> LuminanceMap {
        return LuminanceMap(
            brightness: [[Double]](),
            averageLuminance: 0.5,
            contrastRatio: 1.0,
            darkRegions: [],
            brightRegions: []
        )
    }
    
    // MARK: - Cover Type Detection
    private func determineCoverType(
        kMeansColors: [UIColor],
        luminanceMap: LuminanceMap
    ) -> CoverType {
        // Check for minimalist white
        if luminanceMap.averageLuminance > 0.8 && luminanceMap.contrastRatio < 2.0 {
            return .minimalistWhite
        }
        
        // Check for watercolor (high color variance, soft edges)
        let colorVariance = calculateColorVariance(kMeansColors)
        if colorVariance > 0.5 && luminanceMap.contrastRatio < 4.0 {
            return .watercolor
        }
        
        // Check for photographic (many colors, high detail)
        if kMeansColors.count > 8 && luminanceMap.contrastRatio > 5.0 {
            return .photographic
        }
        
        // Check for graphic design (bold colors, high contrast)
        let saturation = calculateAverageSaturation(kMeansColors)
        if saturation > 0.6 && luminanceMap.contrastRatio > 8.0 {
            return .graphicDesign
        }
        
        // Check for text heavy
        if luminanceMap.darkRegions.count > luminanceMap.brightRegions.count * 2 {
            return .textHeavy
        }
        
        return .complex
    }
    
    private func calculateColorVariance(_ colors: [UIColor]) -> Double {
        guard colors.count > 1 else { return 0 }
        
        var totalDistance = 0.0
        var count = 0
        
        for i in 0..<colors.count {
            for j in (i + 1)..<colors.count {
                totalDistance += colorDistance(colors[i], colors[j])
                count += 1
            }
        }
        
        return totalDistance / Double(count)
    }
    
    private func calculateAverageSaturation(_ colors: [UIColor]) -> Double {
        var totalSaturation = 0.0
        
        for color in colors {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            totalSaturation += Double(s)
        }
        
        return totalSaturation / Double(colors.count)
    }
    
    // MARK: - Palette Building
    private func buildColorPalette(
        kMeans: [UIColor],
        regional: [UIColor],
        edge: [UIColor],
        coverType: CoverType
    ) -> ColorPalette {
        var palette = ColorPalette()
        
        // Select primary colors (2-3)
        switch coverType {
        case .minimalistWhite:
            // For minimal covers, use edge colors as primary
            palette.primary = Array(edge.prefix(2).map { Color(uiColor: $0) })
            if palette.primary.count < 2 {
                palette.primary.append(contentsOf: kMeans.prefix(2 - palette.primary.count).map { Color(uiColor: $0) })
            }
        case .watercolor:
            // Use regional colors for watercolor effect
            palette.primary = Array(regional.prefix(3).map { Color(uiColor: $0) })
        default:
            // Use k-means for others
            palette.primary = Array(kMeans.prefix(3).map { Color(uiColor: $0) })
        }
        
        // Select secondary colors (3-4)
        let usedColorHashes = Set(palette.primary.map { $0.description.hashValue })
        palette.secondary = kMeans
            .filter { !usedColorHashes.contains($0.description.hashValue) }
            .prefix(4)
            .map { Color(uiColor: $0) }
        
        // Select detail colors (2-3)
        palette.detail = edge
            .filter { !usedColorHashes.contains($0.description.hashValue) }
            .prefix(3)
            .map { Color(uiColor: $0) }
        
        // Create glass-optimized colors
        palette.glass = palette.primary.map { color in
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            // Boost saturation and adjust brightness for glass
            return Color(hue: Double(h), saturation: min(Double(s) * 1.3, 1.0), brightness: min(Double(b) * 1.1, 0.9))
        }
        
        return palette
    }
    
    // MARK: - Strategy Selection
    private func selectBackgroundStrategy(
        coverType: CoverType,
        saturationLevel: SaturationLevel,
        palette: ColorPalette
    ) -> BackgroundStrategy {
        switch coverType {
        case .minimalistWhite:
            return .minimalAccent
        case .watercolor:
            return .oceanicFlow
        case .photographic:
            return saturationLevel == .vibrant || saturationLevel == .hyperVibrant ? .richTapestry : .liquidGlass
        case .graphicDesign:
            return .richTapestry
        case .textHeavy:
            return saturationLevel == .monochrome ? .monochromaticDepth : .minimalAccent
        case .complex:
            return .liquidGlass
        }
    }
    
    private func calculateSaturationLevel(_ palette: ColorPalette) -> SaturationLevel {
        let allColors = palette.allColors
        guard !allColors.isEmpty else { return .moderate }
        
        var totalSaturation = 0.0
        
        for color in allColors {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            totalSaturation += Double(s)
        }
        
        let avgSaturation = totalSaturation / Double(allColors.count)
        
        if avgSaturation < 0.1 { return .monochrome }
        if avgSaturation < 0.3 { return .lowSaturation }
        if avgSaturation < 0.6 { return .moderate }
        if avgSaturation < 0.8 { return .vibrant }
        return .hyperVibrant
    }
    
    private func calculateDominantHue(_ colors: [Color]) -> Double {
        guard !colors.isEmpty else { return 0 }
        
        var totalHue = 0.0
        
        for color in colors {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            totalHue += Double(h)
        }
        
        return totalHue / Double(colors.count)
    }
}

// MARK: - Background Strategy
enum BackgroundStrategy {
    case oceanicFlow      // Water/flowing themes
    case minimalAccent    // White/light covers
    case monochromaticDepth // Single color dominant
    case richTapestry     // Complex multi-colored
    case liquidGlass      // Default iOS 26 style
    
    var description: String {
        switch self {
        case .oceanicFlow: return "Oceanic Flow"
        case .minimalAccent: return "Minimal Accent"
        case .monochromaticDepth: return "Monochromatic Depth"
        case .richTapestry: return "Rich Tapestry"
        case .liquidGlass: return "Liquid Glass"
        }
    }
}