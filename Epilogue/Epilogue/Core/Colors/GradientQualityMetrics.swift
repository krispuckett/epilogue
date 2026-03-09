import Foundation
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "GradientQuality")

/// Per-cover gradient quality metrics. Logged on every extraction for observability.
/// Persisted in Gandalf mode for cross-session analysis.
struct GradientQualityMetrics: Codable {
    let bookID: String
    let timestamp: Date

    // Extraction metrics
    let qualityScore: PaletteQualityScore
    let coverType: CoverType

    // OKLCH metrics
    let hueSpread: Double         // Range of hues in degrees
    let chromaSpread: Double      // Range of chroma values
    let lightnessRange: Double    // Lightness max - min

    // Rendering path
    let usedTextureRenderer: Bool
    let usedMeshGradient: Bool
    let usedSaliency: Bool

    // Accessibility
    let contrastRatio: Double     // WCAG contrast of text over rendered background
    let meetsWCAGAA: Bool         // >= 4.5:1 for normal text

    // MARK: - Factory

    static func from(
        bookID: String,
        palette: DisplayPalette,
        qualityScore: PaletteQualityScore,
        usedTexture: Bool = false,
        usedMesh: Bool = false,
        usedSaliency: Bool = false
    ) -> GradientQualityMetrics {
        let colors = [palette.primary, palette.secondary, palette.accent, palette.background]
        let chromatic = colors.filter { $0.chroma > 0.02 }

        let hues = chromatic.map(\.hue)
        let hueSpread: Double
        if hues.count >= 2 {
            let sorted = hues.sorted()
            // Find largest gap to compute effective hue span
            var maxGap = 0.0
            for i in 0..<sorted.count {
                let next = (i + 1) % sorted.count
                let gap = next > i ? sorted[next] - sorted[i] : (360 - sorted[i] + sorted[next])
                maxGap = max(maxGap, gap)
            }
            hueSpread = 360 - maxGap
        } else {
            hueSpread = 0
        }

        let chromas = colors.map(\.chroma)
        let lightnesses = colors.map(\.lightness)

        // WCAG contrast ratio approximation
        // Using relative luminance from OKLCH lightness (simplified)
        let bgLuminance = max(palette.background.lightness, 0.05)
        let textLuminance = 0.95 // White text
        let contrast = (textLuminance + 0.05) / (bgLuminance + 0.05)

        return GradientQualityMetrics(
            bookID: bookID,
            timestamp: .now,
            qualityScore: qualityScore,
            coverType: palette.coverType,
            hueSpread: hueSpread,
            chromaSpread: (chromas.max() ?? 0) - (chromas.min() ?? 0),
            lightnessRange: (lightnesses.max() ?? 0) - (lightnesses.min() ?? 0),
            usedTextureRenderer: usedTexture,
            usedMeshGradient: usedMesh,
            usedSaliency: usedSaliency,
            contrastRatio: contrast,
            meetsWCAGAA: contrast >= 4.5
        )
    }
}

// MARK: - Metrics Store

/// Stores and manages gradient quality metrics for observability.
@MainActor
final class GradientMetricsStore {
    static let shared = GradientMetricsStore()

    /// Recent metrics (in-memory ring buffer)
    private(set) var recentMetrics: [GradientQualityMetrics] = []
    private let maxRecent = 100

    private init() {}

    /// Log a metrics entry
    func log(_ metrics: GradientQualityMetrics) {
        recentMetrics.append(metrics)
        if recentMetrics.count > maxRecent {
            recentMetrics.removeFirst(recentMetrics.count - maxRecent)
        }

        #if DEBUG
        logger.info("""
        📊 Gradient Metrics [\(metrics.bookID)]
          Quality: \(String(format: "%.2f", metrics.qualityScore.composite)) (\(metrics.qualityScore.confidenceTier.rawValue))
          Hue spread: \(String(format: "%.0f°", metrics.hueSpread))
          Chroma spread: \(String(format: "%.3f", metrics.chromaSpread))
          WCAG contrast: \(String(format: "%.1f:1", metrics.contrastRatio)) \(metrics.meetsWCAGAA ? "✅" : "⚠️")
          Path: \(metrics.qualityScore.extractionPath.rawValue)\(metrics.usedTextureRenderer ? " + texture" : "")\(metrics.usedMeshGradient ? " + mesh" : "")
          Time: \(String(format: "%.0fms", metrics.qualityScore.extractionTimeMs))
        """)
        #endif

        // Persist in Gandalf mode
        if UserDefaults.standard.bool(forKey: "gandalfMode") {
            persistToDisk(metrics)
        }
    }

    /// Aggregate stats for all recent metrics
    var aggregateStats: AggregateStats {
        guard !recentMetrics.isEmpty else { return .empty }

        let composites = recentMetrics.map { Double($0.qualityScore.composite) }
        let contrasts = recentMetrics.map(\.contrastRatio)
        let wcagFails = recentMetrics.filter { !$0.meetsWCAGAA }.count

        return AggregateStats(
            count: recentMetrics.count,
            avgQuality: composites.reduce(0, +) / Double(composites.count),
            minQuality: composites.min() ?? 0,
            maxQuality: composites.max() ?? 0,
            avgContrast: contrasts.reduce(0, +) / Double(contrasts.count),
            wcagFailureRate: Double(wcagFails) / Double(recentMetrics.count),
            avgExtractionTimeMs: recentMetrics.map(\.qualityScore.extractionTimeMs).reduce(0, +) / Double(recentMetrics.count),
            tierDistribution: Dictionary(grouping: recentMetrics, by: { $0.qualityScore.confidenceTier }).mapValues(\.count)
        )
    }

    struct AggregateStats {
        let count: Int
        let avgQuality: Double
        let minQuality: Double
        let maxQuality: Double
        let avgContrast: Double
        let wcagFailureRate: Double
        let avgExtractionTimeMs: Double
        let tierDistribution: [PaletteQualityScore.ConfidenceTier: Int]

        static let empty = AggregateStats(
            count: 0, avgQuality: 0, minQuality: 0, maxQuality: 0,
            avgContrast: 0, wcagFailureRate: 0, avgExtractionTimeMs: 0,
            tierDistribution: [:]
        )
    }

    // MARK: - Disk Persistence

    private var metricsFileURL: URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = caches.appendingPathComponent("GradientMetrics")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("metrics.json")
    }

    private func persistToDisk(_ metrics: GradientQualityMetrics) {
        guard let url = metricsFileURL else { return }
        // Append to existing file (simple JSON lines format)
        do {
            let data = try JSONEncoder().encode(metrics)
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.write("\n".data(using: .utf8)!)
                handle.closeFile()
            } else {
                try data.write(to: url)
            }
        } catch {
            // Non-critical — don't fail extraction for metrics
        }
    }
}
