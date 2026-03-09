import SwiftUI

/// Gandalf-mode debug overlay showing extraction roles, confidence, and quality metrics.
/// Only visible when both gandalfMode and atmosphereEngineV2 are enabled.
struct GradientDebugOverlay: View {
    let palette: DisplayPalette
    let qualityScore: PaletteQualityScore?

    @AppStorage("gandalfMode") private var gandalfMode = false
    @AppStorage("atmosphereEngineV2") private var atmosphereV2 = false

    @State private var isExpanded = false

    var body: some View {
        if gandalfMode && atmosphereV2 {
            VStack(alignment: .leading, spacing: 0) {
                // Compact bar — always visible
                compactBar
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded.toggle()
                        }
                    }

                // Expanded detail panel
                if isExpanded {
                    expandedPanel
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
    }

    // MARK: - Compact Bar

    @ViewBuilder
    private var compactBar: some View {
        HStack(spacing: 6) {
            // Confidence dot
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)

            // Cover type
            Text(palette.coverType.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))

            // Quality score
            if let score = qualityScore {
                Text(String(format: "Q:%.0f%%", score.composite * 100))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))

                Text(score.confidenceTier.rawValue)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(confidenceColor.opacity(0.8))
            }

            Spacer()

            // Color role swatches
            HStack(spacing: 3) {
                roleSwatch(palette.primary, label: "P")
                roleSwatch(palette.secondary, label: "S")
                roleSwatch(palette.accent, label: "A")
                roleSwatch(palette.background, label: "B")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(confidenceColor.opacity(0.3), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Expanded Panel

    @ViewBuilder
    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Role details
            VStack(alignment: .leading, spacing: 4) {
                Text("ROLES")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))

                roleRow("Field", color: palette.primary)
                roleRow("Shadow", color: palette.secondary)
                roleRow("Accent", color: palette.accent)
                roleRow("BG", color: palette.background)
                roleRow("Comp", color: palette.complementary)
                roleRow("Analog", color: palette.analogous)
            }

            // Quality breakdown
            if let score = qualityScore {
                Divider().opacity(0.2)

                VStack(alignment: .leading, spacing: 3) {
                    Text("QUALITY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))

                    metricRow("Spread", value: score.spread)
                    metricRow("Chroma", value: score.chromaRichness)
                    metricRow("L Range", value: score.lightnessRange)
                    metricRow("Harmony", value: score.harmonyFit)
                    metricRow("Text ×", value: score.textContamination)
                    metricRow("Saliency", value: score.saliencySupport)

                    Text(String(format: "%.0fms • %@", score.extractionTimeMs, score.extractionPath.rawValue))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            // Aggregate stats
            let stats = GradientMetricsStore.shared.aggregateStats
            if stats.count > 0 {
                Divider().opacity(0.2)

                VStack(alignment: .leading, spacing: 3) {
                    Text("SESSION (\(stats.count) books)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))

                    Text(String(format: "Avg Q: %.0f%% • WCAG fail: %.0f%%",
                                stats.avgQuality * 100, stats.wcagFailureRate * 100))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))

                    Text(String(format: "Avg time: %.0fms", stats.avgExtractionTimeMs))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Components

    @ViewBuilder
    private func roleSwatch(_ color: OKLCHColor, label: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(color.color)
                .frame(width: 16, height: 16)
            Text(label)
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(color.lightness > 0.6 ? Color.black : Color.white)
        }
    }

    @ViewBuilder
    private func roleRow(_ label: String, color: OKLCHColor) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.color)
                .frame(width: 12, height: 12)

            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 40, alignment: .leading)

            Text(String(format: "L%.2f C%.3f H%.0f°", color.lightness, color.chroma, color.hue))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    @ViewBuilder
    private func metricRow(_ label: String, value: Float) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 50, alignment: .leading)

            // Mini bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(metricColor(value))
                        .frame(width: geo.size.width * CGFloat(min(value, 1.0)))
                }
            }
            .frame(height: 4)

            Text(String(format: "%.0f%%", value * 100))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 28, alignment: .trailing)
        }
    }

    // MARK: - Colors

    private var confidenceColor: Color {
        guard let score = qualityScore else { return .gray }
        switch score.confidenceTier {
        case .high:    return .green
        case .medium:  return .yellow
        case .low:     return .orange
        case .veryLow: return .red
        }
    }

    private func metricColor(_ value: Float) -> Color {
        switch value {
        case 0.7...:    return .green
        case 0.4..<0.7: return .yellow
        case 0.2..<0.4: return .orange
        default:        return .red
        }
    }
}
