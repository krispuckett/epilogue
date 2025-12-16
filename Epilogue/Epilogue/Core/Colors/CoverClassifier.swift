import SwiftUI
import CoreGraphics

// MARK: - Cover Classification Engine

/// Analyzes book cover images to determine their visual characteristics
/// This classification drives extraction strategy and enhancement configuration
struct CoverClassifier {

    // MARK: - Classification Result

    struct Classification {
        let coverType: CoverType
        let darkPixelPercentage: Double    // % of pixels with L < 0.2
        let lightPixelPercentage: Double   // % of pixels with L > 0.8
        let averageChroma: Double          // Mean chroma across image
        let hueRange: Double               // Range of hues present (0-360)
        let dominantLightness: Double      // Weighted average lightness

        /// Human-readable summary
        var summary: String {
            """
            Cover Classification: \(coverType.rawValue)
              Dark pixels: \(String(format: "%.1f%%", darkPixelPercentage * 100))
              Light pixels: \(String(format: "%.1f%%", lightPixelPercentage * 100))
              Avg chroma: \(String(format: "%.3f", averageChroma))
              Hue range: \(String(format: "%.0f°", hueRange))
              Dominant lightness: \(String(format: "%.2f", dominantLightness))
            """
        }
    }

    // MARK: - Classification Thresholds

    private enum Threshold {
        static let darkPixelLightness: Double = 0.2
        static let lightPixelLightness: Double = 0.8
        static let lightPixelChroma: Double = 0.1

        static let darkCoverThreshold: Double = 0.60    // >60% dark pixels = dark cover
        static let lightCoverThreshold: Double = 0.50   // >50% light/desaturated = light cover
        static let vibrantChromaThreshold: Double = 0.15 // Avg chroma > 0.15 = vibrant
        static let mutedChromaThreshold: Double = 0.05   // Avg chroma < 0.05 = muted
        static let monochromaticHueRange: Double = 30.0  // All hues within 30° = monochromatic
    }

    // MARK: - Main Classification Method

    /// Classify a cover image to determine optimal extraction strategy
    /// - Parameter cgImage: The cover image to analyze
    /// - Returns: Classification result with cover type and metrics
    static func classify(_ cgImage: CGImage) -> Classification {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow

        // Get pixel data
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
            return Classification(
                coverType: .balanced,
                darkPixelPercentage: 0,
                lightPixelPercentage: 0,
                averageChroma: 0.1,
                hueRange: 180,
                dominantLightness: 0.5
            )
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Analyze pixels using OKLCH
        var darkCount = 0
        var lightDesaturatedCount = 0
        var totalChroma: Double = 0
        var totalLightness: Double = 0
        var hueHistogram = [Int](repeating: 0, count: 36) // 10° buckets
        var validPixelCount = 0
        var chromaWeightedLightness: Double = 0
        var chromaWeightSum: Double = 0

        let stride = max(1, (width * height) / 10000) // Sample ~10K pixels for speed

        for y in Swift.stride(from: 0, to: height, by: Int(sqrt(Double(stride)))) {
            for x in Swift.stride(from: 0, to: width, by: Int(sqrt(Double(stride)))) {
                let offset = (y * bytesPerRow) + (x * 4)
                guard offset + 3 < pixelData.count else { continue }

                let r = Double(pixelData[offset]) / 255.0
                let g = Double(pixelData[offset + 1]) / 255.0
                let b = Double(pixelData[offset + 2]) / 255.0
                let a = pixelData[offset + 3]

                guard a > 128 else { continue }

                let oklch = OKLCHColorSpace.fromSRGB(r: r, g: g, b: b)
                validPixelCount += 1

                // Dark pixel detection
                if oklch.lightness < Threshold.darkPixelLightness {
                    darkCount += 1
                }

                // Light and desaturated pixel detection
                if oklch.lightness > Threshold.lightPixelLightness &&
                   oklch.chroma < Threshold.lightPixelChroma {
                    lightDesaturatedCount += 1
                }

                // Aggregate metrics
                totalChroma += oklch.chroma
                totalLightness += oklch.lightness

                // Hue histogram (only for chromatic pixels)
                if oklch.chroma > 0.03 {
                    let bucket = Int(oklch.hue / 10) % 36
                    hueHistogram[bucket] += 1

                    // Weight lightness by chroma for dominant lightness
                    chromaWeightedLightness += oklch.lightness * oklch.chroma
                    chromaWeightSum += oklch.chroma
                }
            }
        }

        guard validPixelCount > 0 else {
            return Classification(
                coverType: .balanced,
                darkPixelPercentage: 0,
                lightPixelPercentage: 0,
                averageChroma: 0.1,
                hueRange: 180,
                dominantLightness: 0.5
            )
        }

        // Calculate metrics
        let darkPercentage = Double(darkCount) / Double(validPixelCount)
        let lightPercentage = Double(lightDesaturatedCount) / Double(validPixelCount)
        let avgChroma = totalChroma / Double(validPixelCount)
        let dominantL = chromaWeightSum > 0
            ? chromaWeightedLightness / chromaWeightSum
            : totalLightness / Double(validPixelCount)

        // Calculate hue range
        let hueRange = calculateHueRange(histogram: hueHistogram)

        // Determine cover type
        let coverType = determineCoverType(
            darkPercentage: darkPercentage,
            lightPercentage: lightPercentage,
            avgChroma: avgChroma,
            hueRange: hueRange
        )

        return Classification(
            coverType: coverType,
            darkPixelPercentage: darkPercentage,
            lightPixelPercentage: lightPercentage,
            averageChroma: avgChroma,
            hueRange: hueRange,
            dominantLightness: dominantL
        )
    }

    // MARK: - Private Helpers

    /// Calculate the effective hue range from histogram
    private static func calculateHueRange(histogram: [Int]) -> Double {
        let threshold = histogram.max().map { $0 / 10 } ?? 1
        let significantBuckets = histogram.enumerated().filter { $0.element > threshold }

        guard significantBuckets.count > 1 else {
            return 0 // Monochromatic
        }

        // Find the largest gap to determine the effective range
        let sortedBuckets = significantBuckets.map { $0.offset }.sorted()
        guard !sortedBuckets.isEmpty, let lastBucket = sortedBuckets.last else {
            return 0
        }
        var maxGap = 0

        for i in 0..<sortedBuckets.count {
            let current = sortedBuckets[i]
            let prev = i > 0 ? sortedBuckets[i-1] : lastBucket
            let gap = (current - prev + 36) % 36

            if gap > maxGap {
                maxGap = gap
            }
        }

        // Range is 360 - largest gap
        return Double((36 - maxGap) * 10)
    }

    /// Determine cover type from metrics
    private static func determineCoverType(
        darkPercentage: Double,
        lightPercentage: Double,
        avgChroma: Double,
        hueRange: Double
    ) -> CoverType {
        // Priority order matters - check most specific conditions first

        // 1. Dark cover detection (most important for LOTR, Stillness, etc.)
        if darkPercentage > Threshold.darkCoverThreshold {
            return .dark
        }

        // 2. Monochromatic detection
        if hueRange < Threshold.monochromaticHueRange {
            return .monochromatic
        }

        // 3. Light cover detection
        if lightPercentage > Threshold.lightCoverThreshold {
            return .light
        }

        // 4. Chroma-based detection
        if avgChroma > Threshold.vibrantChromaThreshold {
            return .vibrant
        }

        if avgChroma < Threshold.mutedChromaThreshold {
            return .muted
        }

        // 5. Default to balanced
        return .balanced
    }
}

// NOTE: Array safe subscript extension is defined in TrueAmbientProcessor.swift
