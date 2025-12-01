import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import Accelerate

/// Intelligent color extraction using Apple's Vision framework
/// Uses saliency detection, text exclusion, and foreground segmentation
/// to extract meaningful colors from book covers
@MainActor
public class IntelligentColorExtractor {

    // MARK: - Types

    public struct IntelligentPalette {
        public let focalColors: [ExtractedColor]      // Colors from salient/focal regions
        public let backgroundColors: [ExtractedColor] // Colors from edges/background
        public let coverType: CoverType
        public let confidence: Double                  // 0-1 extraction confidence
        public let debugInfo: DebugInfo

        /// Primary color for gradients (most important focal color)
        public var primary: Color {
            focalColors.first?.color ?? .gray
        }

        /// Secondary color (second focal or contrasting background)
        public var secondary: Color {
            focalColors.dropFirst().first?.color ?? backgroundColors.first?.color ?? primary.opacity(0.7)
        }

        /// Accent color (vibrant focal accent)
        public var accent: Color {
            focalColors.max(by: { $0.saturation < $1.saturation })?.color ?? primary
        }

        /// Background base color
        public var background: Color {
            backgroundColors.first?.color ?? .black
        }

        /// Convert to ColorPalette for compatibility with existing system
        public func toColorPalette() -> ColorPalette {
            ColorPalette(
                primary: primary,
                secondary: secondary,
                accent: accent,
                background: background,
                textColor: coverType == .dark ? .white : .black,
                luminance: debugInfo.averageLuminance,
                isMonochromatic: coverType == .monochrome,
                extractionQuality: confidence
            )
        }
    }

    public struct ExtractedColor: Identifiable {
        public let id = UUID()
        public let color: Color
        public let uiColor: UIColor
        public let dominance: Double      // 0-1, how much of the region
        public let saturation: Double     // 0-1
        public let brightness: Double     // 0-1
        public let saliencyWeight: Double // How salient this region was

        public var isVibrant: Bool { saturation > 0.4 && brightness > 0.3 }
        public var isMuted: Bool { saturation < 0.3 }
        public var isDark: Bool { brightness < 0.3 }
    }

    public enum CoverType {
        case dark           // Dark background with light accents (LOTR)
        case light          // Light background with dark elements
        case vibrant        // Colorful, high saturation
        case monochrome     // Single hue or grayscale
        case photographic   // Photo-based cover
    }

    public struct DebugInfo {
        public let saliencyMapSize: CGSize
        public let textRegionsFound: Int
        public let textRegionsCoverage: Double   // % of image covered by text
        public let foregroundMaskAvailable: Bool
        public let averageSaliency: Double
        public let averageLuminance: Double
        public let processingTimeMs: Double
        public let extractionMethod: String
    }

    // MARK: - Properties

    private let context = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Main Extraction

    /// Extract colors intelligently from a book cover
    public func extractPalette(from image: UIImage, bookTitle: String = "") async throws -> IntelligentPalette {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let cgImage = image.cgImage else {
            throw ExtractionError.invalidImage
        }

        // Downsample for performance (max 600px on longest edge)
        let processImage = downsample(cgImage, maxDimension: 600)

        // Run Vision requests in parallel
        async let saliencyResult = performSaliencyAnalysis(on: processImage)
        async let textResult = performTextDetection(on: processImage)

        let (saliencyData, textBoxes) = try await (saliencyResult, textResult)

        // Try foreground segmentation (iOS 17+)
        let foregroundMask = try? await performForegroundSegmentation(on: processImage)

        // Create weighted extraction mask
        let imageSize = CGSize(width: processImage.width, height: processImage.height)
        let extractionWeights = createExtractionWeights(
            saliency: saliencyData,
            textRegions: textBoxes,
            foregroundMask: foregroundMask,
            imageSize: imageSize
        )

        // Extract colors with weighting
        let focalColors = extractWeightedColors(
            from: processImage,
            weights: extractionWeights.focalWeights,
            topK: 5
        )

        let backgroundColors = extractBackgroundColors(
            from: processImage,
            weights: extractionWeights.backgroundWeights,
            topK: 3
        )

        // Determine cover type
        let coverType = determineCoverType(
            focalColors: focalColors,
            backgroundColors: backgroundColors,
            saliencyData: saliencyData
        )

        // Calculate confidence
        let confidence = calculateConfidence(
            focalColors: focalColors,
            saliencyData: saliencyData,
            textCoverage: extractionWeights.textCoverage
        )

        let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        let debugInfo = DebugInfo(
            saliencyMapSize: CGSize(width: saliencyData.width, height: saliencyData.height),
            textRegionsFound: textBoxes.count,
            textRegionsCoverage: extractionWeights.textCoverage,
            foregroundMaskAvailable: foregroundMask != nil,
            averageSaliency: saliencyData.averageSaliency,
            averageLuminance: calculateAverageLuminance(focalColors + backgroundColors),
            processingTimeMs: processingTime,
            extractionMethod: foregroundMask != nil ? "saliency+text+foreground" : "saliency+text"
        )

        #if DEBUG
        print("🎨 [IntelligentExtractor] \(bookTitle)")
        print("   📊 Saliency: \(String(format: "%.2f", saliencyData.averageSaliency)) avg")
        print("   📝 Text regions: \(textBoxes.count) (\(String(format: "%.1f", extractionWeights.textCoverage * 100))% coverage)")
        print("   🎯 Focal colors: \(focalColors.count)")
        print("   🖼️ Cover type: \(coverType)")
        print("   ⏱️ Time: \(String(format: "%.1f", processingTime))ms")
        #endif

        return IntelligentPalette(
            focalColors: focalColors,
            backgroundColors: backgroundColors,
            coverType: coverType,
            confidence: confidence,
            debugInfo: debugInfo
        )
    }

    // MARK: - Vision Analysis

    private struct SaliencyData {
        let heatMap: [[Float]]  // Normalized 0-1 values
        let width: Int
        let height: Int
        let averageSaliency: Double
        let salientBounds: CGRect?  // Bounding box of most salient region
    }

    private func performSaliencyAnalysis(on image: CGImage) async throws -> SaliencyData {
        return try await withCheckedThrowingContinuation { continuation in
            // Guard against double-resume (Vision callbacks can fire synchronously)
            var hasResumed = false

            let request = VNGenerateAttentionBasedSaliencyImageRequest { request, error in
                guard !hasResumed else { return }
                hasResumed = true

                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observation = request.results?.first as? VNSaliencyImageObservation else {
                    continuation.resume(throwing: ExtractionError.saliencyFailed)
                    return
                }

                let pixelBuffer = observation.pixelBuffer

                // Extract heat map values
                let heatMap = self.extractHeatMapValues(from: pixelBuffer)
                let avgSaliency = heatMap.flatMap { $0 }.reduce(0, +) / Double(heatMap.count * (heatMap.first?.count ?? 1))

                let data = SaliencyData(
                    heatMap: heatMap.map { $0.map { Float($0) } },
                    width: CVPixelBufferGetWidth(pixelBuffer),
                    height: CVPixelBufferGetHeight(pixelBuffer),
                    averageSaliency: avgSaliency,
                    salientBounds: observation.salientObjects?.first?.boundingBox
                )

                continuation.resume(returning: data)
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(throwing: error)
            }
        }
    }

    private func extractHeatMapValues(from pixelBuffer: CVPixelBuffer) -> [[Double]] {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return [[]]
        }

        var heatMap: [[Double]] = []
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)

        for y in 0..<height {
            var row: [Double] = []
            for x in 0..<width {
                let index = y * (bytesPerRow / MemoryLayout<Float>.size) + x
                let value = Double(floatBuffer[index])
                row.append(min(1.0, max(0.0, value)))
            }
            heatMap.append(row)
        }

        return heatMap
    }

    private func performTextDetection(on image: CGImage) async throws -> [CGRect] {
        return try await withCheckedThrowingContinuation { continuation in
            // Guard against double-resume (Vision callbacks can fire synchronously)
            var hasResumed = false

            let request = VNRecognizeTextRequest { request, error in
                guard !hasResumed else { return }
                hasResumed = true

                if let error = error {
                    // Text detection failing is not critical
                    #if DEBUG
                    print("⚠️ Text detection failed: \(error)")
                    #endif
                    continuation.resume(returning: [])
                    return
                }

                let boxes = request.results?.compactMap { observation -> CGRect? in
                    guard let textObservation = observation as? VNRecognizedTextObservation else {
                        return nil
                    }
                    return textObservation.boundingBox
                } ?? []

                continuation.resume(returning: boxes)
            }

            // Fast mode for just getting bounding boxes
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: [])
            }
        }
    }

    private func performForegroundSegmentation(on image: CGImage) async throws -> CGImage? {
        // iOS 17+ only
        guard #available(iOS 17.0, *) else { return nil }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage?, any Error>) in
            // Guard against double-resume (Vision callbacks can fire synchronously)
            var hasResumed = false

            let request = VNGenerateForegroundInstanceMaskRequest { request, error in
                guard !hasResumed else { return }

                if let error = error {
                    hasResumed = true
                    #if DEBUG
                    print("⚠️ Foreground segmentation failed: \(error)")
                    #endif
                    continuation.resume(returning: nil)
                    return
                }

                guard let result = request.results?.first as? VNInstanceMaskObservation else {
                    hasResumed = true
                    continuation.resume(returning: nil)
                    return
                }

                // Generate mask
                let maskHandler = VNImageRequestHandler(cgImage: image, options: [:])
                do {
                    let maskBuffer = try result.generateScaledMaskForImage(
                        forInstances: result.allInstances,
                        from: maskHandler
                    )

                    let ciImage = CIImage(cvPixelBuffer: maskBuffer)
                    let cgImage = self.context.createCGImage(ciImage, from: ciImage.extent)
                    hasResumed = true
                    continuation.resume(returning: cgImage)
                } catch {
                    hasResumed = true
                    continuation.resume(returning: nil)
                }
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Weight Calculation

    private struct ExtractionWeights {
        let focalWeights: [[Float]]      // High = more important for focal colors
        let backgroundWeights: [[Float]] // High = more important for background
        let textCoverage: Double         // % of image covered by text
    }

    private func createExtractionWeights(
        saliency: SaliencyData,
        textRegions: [CGRect],
        foregroundMask: CGImage?,
        imageSize: CGSize
    ) -> ExtractionWeights {
        let width = Int(imageSize.width)
        let height = Int(imageSize.height)

        // Initialize weight grids
        var focalWeights = [[Float]](repeating: [Float](repeating: 0, count: width), count: height)
        var backgroundWeights = [[Float]](repeating: [Float](repeating: 0, count: width), count: height)

        // Scale saliency map to image size
        let saliencyScaleX = Float(saliency.width) / Float(width)
        let saliencyScaleY = Float(saliency.height) / Float(height)

        var textPixelCount = 0
        let totalPixels = width * height

        for y in 0..<height {
            for x in 0..<width {
                // Get saliency value (interpolated)
                let sx = min(Int(Float(x) * saliencyScaleX), saliency.width - 1)
                let sy = min(Int(Float(y) * saliencyScaleY), saliency.height - 1)
                let saliencyValue = saliency.heatMap[sy][sx]

                // Check if in text region (normalized coordinates, origin at bottom-left)
                let normalizedX = CGFloat(x) / imageSize.width
                let normalizedY = 1.0 - (CGFloat(y) / imageSize.height) // Flip Y for Vision coordinates
                var inTextRegion = false

                for textBox in textRegions {
                    if textBox.contains(CGPoint(x: normalizedX, y: normalizedY)) {
                        inTextRegion = true
                        textPixelCount += 1
                        break
                    }
                }

                // Check edge proximity (for background detection)
                let edgeDistance = min(
                    Float(x), Float(width - x),
                    Float(y), Float(height - y)
                ) / Float(min(width, height))
                let isEdge = edgeDistance < 0.1

                // Calculate weights
                if inTextRegion {
                    // Heavily penalize text regions for focal colors
                    focalWeights[y][x] = saliencyValue * 0.1
                    backgroundWeights[y][x] = 0.1
                } else if isEdge {
                    // Edges are good for background, not focal
                    focalWeights[y][x] = saliencyValue * 0.3
                    backgroundWeights[y][x] = 0.8
                } else {
                    // Non-edge, non-text: use saliency directly
                    focalWeights[y][x] = saliencyValue
                    backgroundWeights[y][x] = (1.0 - saliencyValue) * 0.5
                }
            }
        }

        let textCoverage = Double(textPixelCount) / Double(totalPixels)

        return ExtractionWeights(
            focalWeights: focalWeights,
            backgroundWeights: backgroundWeights,
            textCoverage: textCoverage
        )
    }

    // MARK: - Color Extraction

    private func extractWeightedColors(
        from image: CGImage,
        weights: [[Float]],
        topK: Int
    ) -> [ExtractedColor] {
        // Create CIImage for pixel access
        let ciImage = CIImage(cgImage: image)
        let width = image.width
        let height = image.height

        // Sample pixels with weighting
        var colorBuckets: [ColorBucket] = []
        let bucketSize = 32 // Quantize to 8 levels per channel (256/32)

        // Initialize buckets
        for r in 0..<8 {
            for g in 0..<8 {
                for b in 0..<8 {
                    colorBuckets.append(ColorBucket(r: r, g: g, b: b))
                }
            }
        }

        // Get pixel data
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return []
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow

        // Sample with weights
        let sampleStep = max(1, min(width, height) / 100) // Sample ~10,000 pixels

        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let weightY = min(y, weights.count - 1)
                let weightX = min(x, (weights.first?.count ?? 1) - 1)
                let weight = weights[weightY][weightX]

                // Skip low-weight pixels
                guard weight > 0.1 else { continue }

                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = Int(bytes[offset])
                let g = Int(bytes[offset + 1])
                let b = Int(bytes[offset + 2])

                // Quantize to bucket
                let bucketR = r / bucketSize
                let bucketG = g / bucketSize
                let bucketB = b / bucketSize
                let bucketIndex = bucketR * 64 + bucketG * 8 + bucketB

                // Add weighted sample
                colorBuckets[bucketIndex].addSample(
                    r: r, g: g, b: b,
                    weight: Double(weight)
                )
            }
        }

        // Sort by weighted count and filter
        let sortedBuckets = colorBuckets
            .filter { $0.weightedCount > 0 }
            .sorted { $0.weightedCount > $1.weightedCount }

        // Convert top buckets to ExtractedColor
        let totalWeight = sortedBuckets.reduce(0) { $0 + $1.weightedCount }

        var results: [ExtractedColor] = []
        for bucket in sortedBuckets.prefix(topK) {
            let (r, g, b) = bucket.averageColor
            let uiColor = UIColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)

            var hue: CGFloat = 0
            var sat: CGFloat = 0
            var bri: CGFloat = 0
            uiColor.getHue(&hue, saturation: &sat, brightness: &bri, alpha: nil)

            results.append(ExtractedColor(
                color: Color(uiColor),
                uiColor: uiColor,
                dominance: bucket.weightedCount / max(1, totalWeight),
                saturation: Double(sat),
                brightness: Double(bri),
                saliencyWeight: bucket.averageSaliency
            ))
        }

        return results
    }

    private func extractBackgroundColors(
        from image: CGImage,
        weights: [[Float]],
        topK: Int
    ) -> [ExtractedColor] {
        // Use same logic but with background weights
        return extractWeightedColors(from: image, weights: weights, topK: topK)
    }

    // MARK: - Analysis

    private func determineCoverType(
        focalColors: [ExtractedColor],
        backgroundColors: [ExtractedColor],
        saliencyData: SaliencyData
    ) -> CoverType {
        let avgFocalBrightness = focalColors.reduce(0) { $0 + $1.brightness } / Double(max(1, focalColors.count))
        let avgFocalSaturation = focalColors.reduce(0) { $0 + $1.saturation } / Double(max(1, focalColors.count))
        let avgBackgroundBrightness = backgroundColors.reduce(0) { $0 + $1.brightness } / Double(max(1, backgroundColors.count))

        // Check for monochrome (low saturation everywhere)
        if avgFocalSaturation < 0.15 {
            return .monochrome
        }

        // Check for dark cover (LOTR style)
        if avgBackgroundBrightness < 0.2 && avgFocalBrightness > avgBackgroundBrightness + 0.2 {
            return .dark
        }

        // Check for light cover
        if avgBackgroundBrightness > 0.7 {
            return .light
        }

        // Check for vibrant
        if avgFocalSaturation > 0.5 {
            return .vibrant
        }

        // Default to photographic
        return .photographic
    }

    private func calculateConfidence(
        focalColors: [ExtractedColor],
        saliencyData: SaliencyData,
        textCoverage: Double
    ) -> Double {
        var confidence = 0.5

        // Higher saliency contrast = more confident
        if saliencyData.averageSaliency > 0.3 {
            confidence += 0.2
        }

        // Found distinct colors = more confident
        if focalColors.count >= 3 {
            confidence += 0.15
        }

        // Has vibrant colors = more confident
        if focalColors.contains(where: { $0.isVibrant }) {
            confidence += 0.1
        }

        // Less text coverage = more confident in color extraction
        if textCoverage < 0.2 {
            confidence += 0.1
        } else if textCoverage > 0.5 {
            confidence -= 0.2
        }

        return min(1.0, max(0.0, confidence))
    }

    private func calculateAverageLuminance(_ colors: [ExtractedColor]) -> Double {
        guard !colors.isEmpty else { return 0.5 }
        return colors.reduce(0) { $0 + $1.brightness } / Double(colors.count)
    }

    // MARK: - Utilities

    private func downsample(_ image: CGImage, maxDimension: Int) -> CGImage {
        let width = image.width
        let height = image.height

        guard max(width, height) > maxDimension else { return image }

        let scale = CGFloat(maxDimension) / CGFloat(max(width, height))
        let newWidth = Int(CGFloat(width) * scale)
        let newHeight = Int(CGFloat(height) * scale)

        guard let colorSpace = image.colorSpace,
              let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: 8,
                bytesPerRow: newWidth * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        return context.makeImage() ?? image
    }

    // MARK: - Errors

    public enum ExtractionError: Error {
        case invalidImage
        case saliencyFailed
        case extractionFailed
    }
}

// MARK: - Color Bucket Helper

private struct ColorBucket {
    let r: Int
    let g: Int
    let b: Int

    var totalR: Int = 0
    var totalG: Int = 0
    var totalB: Int = 0
    var sampleCount: Int = 0
    var weightedCount: Double = 0
    var totalSaliency: Double = 0

    init(r: Int, g: Int, b: Int) {
        self.r = r
        self.g = g
        self.b = b
    }

    mutating func addSample(r: Int, g: Int, b: Int, weight: Double) {
        totalR += r
        totalG += g
        totalB += b
        sampleCount += 1
        weightedCount += weight
        totalSaliency += weight
    }

    var averageColor: (Int, Int, Int) {
        guard sampleCount > 0 else { return (r * 32 + 16, g * 32 + 16, b * 32 + 16) }
        return (totalR / sampleCount, totalG / sampleCount, totalB / sampleCount)
    }

    var averageSaliency: Double {
        guard sampleCount > 0 else { return 0 }
        return totalSaliency / Double(sampleCount)
    }
}
