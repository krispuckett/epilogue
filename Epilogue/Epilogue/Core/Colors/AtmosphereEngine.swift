import SwiftUI
import UIKit
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "AtmosphereEngine")

/// Atmosphere Engine v2 — the bridge between raw color extraction and cinematic gradients.
///
/// Pipeline: Cover Image → OKLABColorExtractor → CoverClassifier → OKLCH Conversion
///           → DisplayPalette (cover-type-aware enhancement) → UnifiedAtmosphericGradient
///
/// This replaces the ad-hoc HSB enhancement in BookAtmosphericGradientView with
/// perceptually uniform OKLCH enhancement driven by cover classification.
@MainActor
final class AtmosphereEngine {
    static let shared = AtmosphereEngine()

    // MARK: - Cache

    /// In-memory DisplayPalette cache (keyed by bookID)
    private let displayPaletteCache = NSCache<NSString, DisplayPaletteWrapper>()

    /// Unified extractor for v2 pipeline
    private let atmosphereExtractor = AtmosphereExtractor()

    /// Whether to use the unified extractor (Gandalf toggle)
    private var useUnifiedExtractor: Bool {
        let key = "feature.gradient.unified_extractor"
        return UserDefaults.standard.object(forKey: key) == nil || UserDefaults.standard.bool(forKey: key)
    }

    /// Whether v2 atmosphere engine is enabled (Gandalf toggle)
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "atmosphereEngineV2")
    }

    private init() {
        displayPaletteCache.countLimit = 50
        displayPaletteCache.name = "AtmosphereEngine.DisplayPalette"
    }

    // MARK: - Public API

    /// Extract a DisplayPalette from a book's cover image.
    /// Returns cached result if available, otherwise runs full pipeline.
    func extractDisplayPalette(
        bookID: String,
        coverURL: String
    ) async -> DisplayPalette? {
        // Check memory cache
        if let cached = displayPaletteCache.object(forKey: bookID as NSString) {
            return cached.palette
        }

        // Check disk cache (stored alongside legacy palette)
        if let diskPalette = await loadDisplayPaletteFromDisk(bookID: bookID) {
            displayPaletteCache.setObject(
                DisplayPaletteWrapper(diskPalette),
                forKey: bookID as NSString
            )
            return diskPalette
        }

        // Full extraction pipeline
        guard let image = await SharedBookCoverManager.shared.loadFullImage(from: coverURL) else {
            logger.warning("Failed to load cover image for \(bookID)")
            return nil
        }

        return await runPipeline(image: image, bookID: bookID, coverURL: coverURL)
    }

    /// Extract DisplayPalette from an already-loaded UIImage
    func extractDisplayPalette(
        from image: UIImage,
        bookID: String,
        coverURL: String? = nil
    ) async -> DisplayPalette? {
        // Check memory cache
        if let cached = displayPaletteCache.object(forKey: bookID as NSString) {
            return cached.palette
        }

        return await runPipeline(image: image, bookID: bookID, coverURL: coverURL)
    }

    /// Convert a legacy ColorPalette to DisplayPalette with cover classification.
    /// Used when we already have a ColorPalette but want v2 enhancement.
    func upgradeToDisplayPalette(
        _ legacy: ColorPalette,
        coverImage: UIImage?,
        bookID: String
    ) -> DisplayPalette {
        // Check cache first
        if let cached = displayPaletteCache.object(forKey: bookID as NSString) {
            return cached.palette
        }

        // Classify cover if image available, otherwise use balanced
        let coverType: CoverType
        if let cgImage = coverImage?.cgImage {
            coverType = CoverClassifier.classify(cgImage).coverType
        } else {
            coverType = .balanced
        }

        let palette = DisplayPalette.fromLegacy(legacy, coverType: coverType)

        // Cache it
        displayPaletteCache.setObject(
            DisplayPaletteWrapper(palette),
            forKey: bookID as NSString
        )

        return palette
    }

    /// Invalidate cached DisplayPalette for a book
    func invalidate(bookID: String) {
        displayPaletteCache.removeObject(forKey: bookID as NSString)
        removeDisplayPaletteFromDisk(bookID: bookID)
    }

    /// Clear all cached palettes
    func clearAll() {
        displayPaletteCache.removeAllObjects()
    }

    // MARK: - Pipeline

    /// Full extraction pipeline: Image → ColorCube → Classify → OKLCH → DisplayPalette
    private func runPipeline(
        image: UIImage,
        bookID: String,
        coverURL: String?
    ) async -> DisplayPalette? {
        guard let cgImage = image.cgImage else {
            logger.error("Failed to get CGImage for \(bookID)")
            return nil
        }

        // v2 path: Use unified extractor with saliency + confidence
        if Self.isEnabled && useUnifiedExtractor {
            return await runUnifiedPipeline(image: image, bookID: bookID, coverURL: coverURL)
        }

        // v1 legacy path: OKLABColorExtractor → CoverClassifier → DisplayPalette
        return await runLegacyPipeline(image: image, cgImage: cgImage, bookID: bookID, coverURL: coverURL)
    }

    /// v2 unified pipeline: AtmosphereExtractor with saliency + confidence scoring
    private func runUnifiedPipeline(
        image: UIImage,
        bookID: String,
        coverURL: String?
    ) async -> DisplayPalette? {
        guard let model = await atmosphereExtractor.extract(from: image, bookID: bookID) else {
            logger.warning("Unified extraction failed for \(bookID), falling back to legacy")
            guard let cgImage = image.cgImage else { return nil }
            return await runLegacyPipeline(image: image, cgImage: cgImage, bookID: bookID, coverURL: coverURL)
        }

        let displayPalette = model.toDisplayPalette()

        // Log quality metrics
        let metrics = GradientQualityMetrics.from(
            bookID: bookID,
            palette: displayPalette,
            qualityScore: model.qualityScore,
            usedSaliency: model.qualityScore.extractionPath == .saliency
        )
        GradientMetricsStore.shared.log(metrics)

        // Cache
        displayPaletteCache.setObject(
            DisplayPaletteWrapper(displayPalette),
            forKey: bookID as NSString
        )
        await saveDisplayPaletteToDisk(displayPalette, bookID: bookID)

        // Also cache legacy palette for backward compat
        let legacyPalette = displayPalette.toLegacy()
        await BookColorPaletteCache.shared.cachePalette(legacyPalette, for: bookID, coverURL: coverURL)

        return displayPalette
    }

    /// v1 legacy pipeline: OKLABColorExtractor → CoverClassifier → DisplayPalette
    private func runLegacyPipeline(
        image: UIImage,
        cgImage: CGImage,
        bookID: String,
        coverURL: String?
    ) async -> DisplayPalette? {
        // Step 1: Extract raw colors using existing OKLABColorExtractor
        let extractor = OKLABColorExtractor()
        let rawPalette: ColorPalette
        do {
            rawPalette = try await extractor.extractPalette(from: image, imageSource: bookID)
        } catch {
            logger.error("Color extraction failed for \(bookID): \(error)")
            return nil
        }

        // Step 2: Classify the cover image
        let classification = CoverClassifier.classify(cgImage)

        #if DEBUG
        let hueStr = classification.dominantHues.map { String(format: "%.0f°", $0) }.joined(separator: ", ")
        logger.info("""
        🎨 Atmosphere Engine Pipeline [\(bookID)]
          Cover type: \(classification.coverType.rawValue)
          Dark pixels: \(String(format: "%.1f%%", classification.darkPixelPercentage * 100))
          Avg chroma: \(String(format: "%.3f", classification.averageChroma))
          Hue range: \(String(format: "%.0f°", classification.hueRange))
          Dominant hues: [\(hueStr)]
        """)
        #endif

        // Step 3: Reorder palette colors to match actual pixel dominance
        let reorderedColors = reorderByDominantHue(
            colors: [
                rawPalette.primary.oklch,
                rawPalette.secondary.oklch,
                rawPalette.accent.oklch,
                rawPalette.background.oklch
            ],
            dominantHues: classification.dominantHues
        )

        #if DEBUG
        let originalPrimary = rawPalette.primary.oklch
        let newPrimary = reorderedColors[0]
        if abs(originalPrimary.hue - newPrimary.hue) > 15 {
            logger.info("🔄 Primary reordered: hue \(String(format: "%.0f°", originalPrimary.hue)) → \(String(format: "%.0f°", newPrimary.hue))")
        }
        #endif

        // Step 4: Build DisplayPalette
        let displayPalette = DisplayPalette(
            primary: reorderedColors[0],
            secondary: reorderedColors[1],
            accent: reorderedColors[2],
            background: reorderedColors[3],
            coverType: classification.coverType,
            dominantLightness: classification.dominantLightness,
            extractionConfidence: rawPalette.extractionQuality
        )

        // Log metrics for legacy path too
        let legacyScore = PaletteQualityScore.fromLegacy(rawPalette.extractionQuality)
        let metrics = GradientQualityMetrics.from(
            bookID: bookID,
            palette: displayPalette,
            qualityScore: legacyScore
        )
        GradientMetricsStore.shared.log(metrics)

        // Cache
        displayPaletteCache.setObject(
            DisplayPaletteWrapper(displayPalette),
            forKey: bookID as NSString
        )
        await saveDisplayPaletteToDisk(displayPalette, bookID: bookID)
        await BookColorPaletteCache.shared.cachePalette(rawPalette, for: bookID, coverURL: coverURL)

        #if DEBUG
        logger.info("✅ Atmosphere Engine (legacy): \(displayPalette)")
        #endif

        return displayPalette
    }

    // MARK: - Hue Reordering

    /// Reorder ALL extracted colors to match the image's actual hue dominance.
    /// Position 0 (primary) gets the color closest to the #1 dominant hue,
    /// position 1 (secondary) gets the closest to #2, and so on.
    /// This corrects the OKLABColorExtractor's tendency to pick minority peaks as primary.
    private func reorderByDominantHue(
        colors: [OKLCHColor],
        dominantHues: [Double]
    ) -> [OKLCHColor] {
        guard !dominantHues.isEmpty, colors.count == 4 else {
            return colors
        }

        var available = Array(colors.enumerated()) // (originalIndex, color)
        var result: [OKLCHColor] = []

        // Greedily assign: for each dominant hue (by rank), pick the closest unassigned color
        for hue in dominantHues.prefix(colors.count) {
            guard !available.isEmpty else { break }

            let bestIndex = available.enumerated().min(by: { a, b in
                let scoreA = hueDistance(a.element.element.hue, hue)
                    + (a.element.element.chroma < 0.03 ? 200.0 : 0.0) // Penalize achromatic
                let scoreB = hueDistance(b.element.element.hue, hue)
                    + (b.element.element.chroma < 0.03 ? 200.0 : 0.0)
                return scoreA < scoreB
            })!.offset

            result.append(available[bestIndex].element)
            available.remove(at: bestIndex)
        }

        // Append any remaining unassigned colors
        result.append(contentsOf: available.map { $0.element })

        #if DEBUG
        let before = colors.map { String(format: "%.0f°", $0.hue) }.joined(separator: "→")
        let after = result.map { String(format: "%.0f°", $0.hue) }.joined(separator: "→")
        if before != after {
            logger.info("🔄 Palette reordered: [\(before)] → [\(after)]")
        }
        #endif

        return result
    }

    /// Angular distance between two hues (0-180°)
    private func hueDistance(_ h1: Double, _ h2: Double) -> Double {
        let diff = abs(h1 - h2).truncatingRemainder(dividingBy: 360)
        return min(diff, 360 - diff)
    }

    // MARK: - Disk Persistence

    private var cacheDirectory: URL? {
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = cachesDir.appendingPathComponent("DisplayPalettes")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func diskURL(for bookID: String) -> URL? {
        guard let dir = cacheDirectory else { return nil }
        let sanitized = bookID
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return dir.appendingPathComponent("\(sanitized).json")
    }

    private func loadDisplayPaletteFromDisk(bookID: String) async -> DisplayPalette? {
        guard let url = diskURL(for: bookID),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let palette = try JSONDecoder().decode(DisplayPalette.self, from: data)

            // Version check
            guard palette.version == DisplayPalette.currentVersion else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }

            return palette
        } catch {
            #if DEBUG
            logger.error("Failed to load DisplayPalette from disk: \(error)")
            #endif
            return nil
        }
    }

    private func saveDisplayPaletteToDisk(_ palette: DisplayPalette, bookID: String) async {
        guard let url = diskURL(for: bookID) else { return }

        do {
            let data = try JSONEncoder().encode(palette)
            try data.write(to: url)
        } catch {
            #if DEBUG
            logger.error("Failed to save DisplayPalette to disk: \(error)")
            #endif
        }
    }

    private func removeDisplayPaletteFromDisk(bookID: String) {
        guard let url = diskURL(for: bookID) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - NSCache Wrapper

/// NSCache requires reference-type values
private class DisplayPaletteWrapper: NSObject {
    let palette: DisplayPalette

    init(_ palette: DisplayPalette) {
        self.palette = palette
    }
}
