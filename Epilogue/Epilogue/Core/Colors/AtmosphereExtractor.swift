import SwiftUI
import UIKit
import Vision
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AtmosphereExtractor")

// MARK: - Atmosphere Model

/// The output of the unified extraction engine. Contains typed visual roles
/// instead of raw colors, plus confidence scoring for fallback decisions.
struct AtmosphereModel: Codable, Equatable {
    /// Dominant background wash — widest spatial support
    let field: OKLCHColor
    /// Dark anchor tone — preserves hue of field
    let shadow: OKLCHColor
    /// High-lightness moderate-chroma accent — for glow/bloom effects
    let glow: OKLCHColor
    /// Sparse high-saliency color (may be nil if no confident accent found)
    let accent: OKLCHColor
    /// Low-chroma support tone — for fades and text safety
    let neutral: OKLCHColor

    /// Quality score with confidence tier
    let qualityScore: PaletteQualityScore

    /// Cover classification
    let coverType: CoverType

    /// Dominant lightness of the source image
    let dominantLightness: Double

    /// Convert to DisplayPalette for rendering
    func toDisplayPalette() -> DisplayPalette {
        DisplayPalette(
            primary: field,
            secondary: shadow,
            accent: accent,
            background: neutral,
            coverType: coverType,
            dominantLightness: dominantLightness,
            extractionConfidence: Double(qualityScore.composite)
        )
    }
}

// MARK: - Atmosphere Extractor

/// Unified extraction engine that replaces the 4 competing extractors.
/// Uses saliency-weighted perceptual clustering and outputs confidence-scored
/// visual roles instead of raw color arrays.
@MainActor
final class AtmosphereExtractor {

    /// Whether to use Vision saliency (behind feature flag)
    private var useSaliency: Bool {
        let key = "feature.gradient.saliency_extraction"
        return UserDefaults.standard.object(forKey: key) == nil || UserDefaults.standard.bool(forKey: key)
    }

    /// Whether to use confidence scoring (behind feature flag)
    private var useConfidenceScoring: Bool {
        let key = "feature.gradient.confidence_scoring"
        return UserDefaults.standard.object(forKey: key) == nil || UserDefaults.standard.bool(forKey: key)
    }

    // MARK: - Public API

    /// Extract an AtmosphereModel from a cover image.
    func extract(from image: UIImage, bookID: String) async -> AtmosphereModel? {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let cgImage = image.cgImage else {
            logger.error("No CGImage for \(bookID)")
            return nil
        }

        // Step 1: Classify the cover
        let classification = CoverClassifier.classify(cgImage)

        // Step 2: Get saliency map (if enabled)
        let saliencyMap: [[Float]]?
        if useSaliency {
            saliencyMap = await generateSaliencyMap(cgImage)
        } else {
            saliencyMap = nil
        }

        // Step 3: Extract weighted color clusters in OKLab space
        let clusters = extractWeightedClusters(
            cgImage: cgImage,
            saliencyMap: saliencyMap,
            classification: classification
        )

        guard !clusters.isEmpty else {
            logger.warning("No clusters extracted for \(bookID)")
            return nil
        }

        // Step 4: Synthesize roles from clusters
        let roles = synthesizeRoles(from: clusters, classification: classification)

        // Step 5: Score the quality
        let extractionTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let allRoles = [roles.field, roles.shadow, roles.glow, roles.accent, roles.neutral]
        let textContamination = estimateTextContamination(cgImage)

        let qualityScore = PaletteQualityScore.score(
            roles: allRoles,
            textContamination: textContamination,
            saliencySupport: saliencyMap != nil ? 0.8 : 0.5,
            extractionTimeMs: extractionTime,
            extractionPath: saliencyMap != nil ? .saliency : .unified
        )

        // Step 6: Apply confidence-aware fallback if needed
        let finalRoles: (field: OKLCHColor, shadow: OKLCHColor, glow: OKLCHColor, accent: OKLCHColor, neutral: OKLCHColor)

        if useConfidenceScoring {
            finalRoles = applyConfidenceFallback(
                roles: roles,
                quality: qualityScore,
                classification: classification
            )
        } else {
            finalRoles = roles
        }

        let model = AtmosphereModel(
            field: finalRoles.field,
            shadow: finalRoles.shadow,
            glow: finalRoles.glow,
            accent: finalRoles.accent,
            neutral: finalRoles.neutral,
            qualityScore: qualityScore,
            coverType: classification.coverType,
            dominantLightness: classification.dominantLightness
        )

        #if DEBUG
        logger.info("""
        🔬 AtmosphereExtractor [\(bookID)]
          Confidence: \(String(format: "%.2f", qualityScore.composite)) (\(qualityScore.confidenceTier.rawValue))
          Field: \(finalRoles.field)
          Shadow: \(finalRoles.shadow)
          Glow: \(finalRoles.glow)
          Accent: \(finalRoles.accent)
          Neutral: \(finalRoles.neutral)
          Time: \(String(format: "%.0fms", extractionTime))
        """)
        #endif

        return model
    }

    // MARK: - Vision Saliency

    /// Generate attention-based saliency map using Vision framework
    private func generateSaliencyMap(_ cgImage: CGImage) async -> [[Float]]? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()

        return await withCheckedContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                guard let observation = request.results?.first else {
                    continuation.resume(returning: nil)
                    return
                }

                // Convert CVPixelBuffer to 2D float array
                let pixelBuffer = observation.pixelBuffer
                CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
                defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

                let width = CVPixelBufferGetWidth(pixelBuffer)
                let height = CVPixelBufferGetHeight(pixelBuffer)
                guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
                    continuation.resume(returning: nil)
                    return
                }

                let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
                var map: [[Float]] = []
                for y in 0..<height {
                    var row: [Float] = []
                    for x in 0..<width {
                        row.append(floatBuffer[y * width + x])
                    }
                    map.append(row)
                }

                continuation.resume(returning: map)
            } catch {
                logger.error("Vision saliency failed: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Weighted Clustering

    /// Weighted color cluster from OKLab space
    private struct ColorCluster {
        var labL: Double
        var labA: Double
        var labB: Double
        var weight: Double
        var pixelCount: Int

        var oklch: OKLCHColor {
            let C = sqrt(labA * labA + labB * labB)
            var H = atan2(labB, labA) * 180.0 / .pi
            if H < 0 { H += 360 }
            return OKLCHColor(lightness: labL, chroma: C, hue: H)
        }
    }

    /// Extract saliency-weighted color clusters in OKLab space
    private func extractWeightedClusters(
        cgImage: CGImage,
        saliencyMap: [[Float]]?,
        classification: CoverClassifier.Classification
    ) -> [ColorCluster] {
        let width = cgImage.width
        let height = cgImage.height

        // Downsample large images
        let maxDim = 200
        let scale = min(1.0, Double(maxDim) / Double(max(width, height)))
        let sampleW = max(1, Int(Double(width) * scale))
        let sampleH = max(1, Int(Double(height) * scale))

        // Create bitmap context
        guard let context = CGContext(
            data: nil,
            width: sampleW,
            height: sampleH,
            bitsPerComponent: 8,
            bytesPerRow: sampleW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleW, height: sampleH))

        guard let pixelData = context.data else { return [] }
        let data = pixelData.bindMemory(to: UInt8.self, capacity: sampleW * sampleH * 4)

        // Build OKLab histogram with weights
        // Use 8×8×8 grid in OKLab space
        let gridSize = 8
        var buckets: [Int: (labL: Double, labA: Double, labB: Double, weight: Double, count: Int)] = [:]

        let saliencyW = saliencyMap?.first?.count ?? 1
        let saliencyH = saliencyMap?.count ?? 1

        for y in 0..<sampleH {
            for x in 0..<sampleW {
                let offset = (y * sampleW + x) * 4
                let r = Double(data[offset]) / 255.0
                let g = Double(data[offset + 1]) / 255.0
                let b = Double(data[offset + 2]) / 255.0

                // Skip near-black pixels
                if r + g + b < 0.09 { continue }

                // Convert to OKLab
                let lab = srgbToOKLab(r: r, g: g, b: b)

                // Calculate pixel weight
                var weight: Double = 1.0

                // Saliency weight
                if let sMap = saliencyMap {
                    let sx = min(Int(Double(x) / Double(sampleW) * Double(saliencyW)), saliencyW - 1)
                    let sy = min(Int(Double(y) / Double(sampleH) * Double(saliencyH)), saliencyH - 1)
                    weight *= Double(1.0 + sMap[sy][sx] * 2.0) // Saliency boost up to 3x
                }

                // Center bias (mild)
                let cx = Double(x) / Double(sampleW) - 0.5
                let cy = Double(y) / Double(sampleH) - 0.5
                let centerDist = sqrt(cx * cx + cy * cy)
                weight *= 1.0 + max(0, 0.5 - centerDist)

                // Quantize to grid cell
                let qi = Int(max(0, min(Double(gridSize - 1), lab.L * Double(gridSize))))
                let qa = Int(max(0, min(Double(gridSize - 1), (lab.a + 0.4) / 0.8 * Double(gridSize))))
                let qb = Int(max(0, min(Double(gridSize - 1), (lab.b + 0.4) / 0.8 * Double(gridSize))))
                let key = qi * gridSize * gridSize + qa * gridSize + qb

                if var bucket = buckets[key] {
                    // Running weighted average
                    let totalWeight = bucket.weight + weight
                    bucket.labL = (bucket.labL * bucket.weight + lab.L * weight) / totalWeight
                    bucket.labA = (bucket.labA * bucket.weight + lab.a * weight) / totalWeight
                    bucket.labB = (bucket.labB * bucket.weight + lab.b * weight) / totalWeight
                    bucket.weight = totalWeight
                    bucket.count += 1
                    buckets[key] = bucket
                } else {
                    buckets[key] = (lab.L, lab.a, lab.b, weight, 1)
                }
            }
        }

        // Convert to clusters and sort by weight
        let clusters = buckets.values
            .filter { $0.count >= 3 } // Minimum pixel threshold
            .map { ColorCluster(labL: $0.labL, labA: $0.labA, labB: $0.labB, weight: $0.weight, pixelCount: $0.count) }
            .sorted { $0.weight > $1.weight }

        // Return top clusters (merge similar ones)
        return mergeSimilarClusters(Array(clusters.prefix(20)), threshold: 0.06)
    }

    /// Merge clusters that are perceptually close
    private func mergeSimilarClusters(_ clusters: [ColorCluster], threshold: Double) -> [ColorCluster] {
        var result: [ColorCluster] = []

        for cluster in clusters {
            let oklch = cluster.oklch
            if let matchIndex = result.firstIndex(where: { $0.oklch.distance(to: oklch) < threshold }) {
                // Merge into existing
                var existing = result[matchIndex]
                let totalWeight = existing.weight + cluster.weight
                existing.labL = (existing.labL * existing.weight + cluster.labL * cluster.weight) / totalWeight
                existing.labA = (existing.labA * existing.weight + cluster.labA * cluster.weight) / totalWeight
                existing.labB = (existing.labB * existing.weight + cluster.labB * cluster.weight) / totalWeight
                existing.weight = totalWeight
                existing.pixelCount += cluster.pixelCount
                result[matchIndex] = existing
            } else {
                result.append(cluster)
            }
        }

        return result.sorted { $0.weight > $1.weight }
    }

    // MARK: - Role Synthesis

    /// Assign typed visual roles from weighted clusters
    private func synthesizeRoles(
        from clusters: [ColorCluster],
        classification: CoverClassifier.Classification
    ) -> (field: OKLCHColor, shadow: OKLCHColor, glow: OKLCHColor, accent: OKLCHColor, neutral: OKLCHColor) {
        guard !clusters.isEmpty else {
            let fallback = EditorialAtmosphere.ink.palette
            return (fallback.field, fallback.shadow, fallback.glow, fallback.accent,
                    OKLCHColor(lightness: 0.3, chroma: 0.02, hue: 0))
        }

        // Field: highest weight cluster (widest spatial support)
        let field = clusters[0].oklch

        // Shadow: darker adjacent tone preserving field's hue
        let shadow = OKLCHColor(
            lightness: max(field.lightness * 0.45, 0.10),
            chroma: field.chroma * 0.6,
            hue: field.hue
        )

        // Glow: higher-lightness, moderate-chroma cousin of field
        let glow = OKLCHColor(
            lightness: min(field.lightness * 1.4, 0.80),
            chroma: min(field.chroma * 1.1, 0.25),
            hue: field.hue + 5 // Slight hue shift for depth
        )

        // Accent: most chromatic cluster that's perceptually distinct from field
        let accent: OKLCHColor
        if let accentCluster = clusters.dropFirst().first(where: {
            $0.oklch.chroma > 0.05 && $0.oklch.distance(to: field) > 0.08
        }) {
            accent = accentCluster.oklch
        } else if clusters.count > 1 {
            accent = clusters[1].oklch
        } else {
            // Synthesize from harmonies
            accent = OKLCHColor(
                lightness: field.lightness * 0.9,
                chroma: max(field.chroma * 1.3, 0.08),
                hue: field.hue + 40 // Analogous shift
            )
        }

        // Neutral: low-chroma support tone derived from field
        let neutral = OKLCHColor(
            lightness: field.lightness * 0.7,
            chroma: min(field.chroma * 0.3, 0.04),
            hue: field.hue
        )

        return (field, shadow, glow, accent, neutral)
    }

    // MARK: - Confidence Fallback

    /// Apply confidence-aware corrections to roles
    private func applyConfidenceFallback(
        roles: (field: OKLCHColor, shadow: OKLCHColor, glow: OKLCHColor, accent: OKLCHColor, neutral: OKLCHColor),
        quality: PaletteQualityScore,
        classification: CoverClassifier.Classification
    ) -> (field: OKLCHColor, shadow: OKLCHColor, glow: OKLCHColor, accent: OKLCHColor, neutral: OKLCHColor) {
        switch quality.confidenceTier {
        case .high:
            // Stay close to extracted hues
            return roles

        case .medium:
            // Compress chroma range, increase tonal spacing
            return (
                field:   OKLCHColor(lightness: roles.field.lightness, chroma: min(roles.field.chroma, 0.20), hue: roles.field.hue),
                shadow:  OKLCHColor(lightness: max(roles.shadow.lightness, 0.12), chroma: roles.shadow.chroma * 0.8, hue: roles.shadow.hue),
                glow:    OKLCHColor(lightness: min(roles.glow.lightness * 1.1, 0.75), chroma: roles.glow.chroma, hue: roles.glow.hue),
                accent:  roles.accent,
                neutral: roles.neutral
            )

        case .low:
            // Preserve 1-2 believable hues, synthesize rest from OKLCH harmonies
            let baseHue = roles.field.hue
            return (
                field:   OKLCHColor(lightness: 0.42, chroma: max(roles.field.chroma, 0.06), hue: baseHue),
                shadow:  OKLCHColor(lightness: 0.18, chroma: 0.04, hue: baseHue),
                glow:    OKLCHColor(lightness: 0.58, chroma: 0.10, hue: baseHue + 15),
                accent:  OKLCHColor(lightness: 0.55, chroma: 0.12, hue: baseHue + 120), // Triadic
                neutral: OKLCHColor(lightness: 0.30, chroma: 0.03, hue: baseHue)
            )

        case .veryLow:
            // Editorial atmosphere family seeded by strongest surviving hue
            let dominantHue = classification.dominantHues.first ?? roles.field.hue
            let atmosphere = EditorialAtmosphere.bestMatch(for: dominantHue)
            let p = atmosphere.palette
            return (p.field, p.shadow, p.glow, p.accent,
                    OKLCHColor(lightness: 0.28, chroma: 0.02, hue: dominantHue))
        }
    }

    // MARK: - Text Contamination

    /// Estimate how much of the image is text (high-contrast thin features)
    private func estimateTextContamination(_ cgImage: CGImage) -> Float {
        let width = cgImage.width
        let height = cgImage.height
        let maxDim = 100
        let scale = min(1.0, Double(maxDim) / Double(max(width, height)))
        let sW = max(1, Int(Double(width) * scale))
        let sH = max(1, Int(Double(height) * scale))

        guard let context = CGContext(
            data: nil, width: sW, height: sH,
            bitsPerComponent: 8, bytesPerRow: sW,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sW, height: sH))
        guard let data = context.data?.bindMemory(to: UInt8.self, capacity: sW * sH) else { return 0 }

        // Count high-contrast horizontal edges (text indicator)
        var edgeCount = 0
        let totalPixels = sW * sH
        for y in 1..<(sH - 1) {
            for x in 1..<(sW - 1) {
                let _ = Int(data[y * sW + x])
                let left = Int(data[y * sW + x - 1])
                let right = Int(data[y * sW + x + 1])
                let above = Int(data[(y - 1) * sW + x])
                let below = Int(data[(y + 1) * sW + x])

                let hDiff = abs(left - right)
                let vDiff = abs(above - below)
                if hDiff > 60 || vDiff > 60 {
                    edgeCount += 1
                }
            }
        }

        return min(Float(edgeCount) / Float(max(totalPixels / 4, 1)), 1.0)
    }

    // MARK: - OKLab Conversion (inline for performance)

    private func srgbToOKLab(r: Double, g: Double, b: Double) -> (L: Double, a: Double, b: Double) {
        let lr = r <= 0.04045 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let lg = g <= 0.04045 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let lb = b <= 0.04045 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)

        let l = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
        let m = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
        let s = 0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb

        let l_ = cbrt(l)
        let m_ = cbrt(m)
        let s_ = cbrt(s)

        let L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
        let a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
        let bVal = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

        return (L, a, bVal)
    }

    private func cbrt(_ x: Double) -> Double {
        x >= 0 ? pow(x, 1.0 / 3.0) : -pow(-x, 1.0 / 3.0)
    }
}
