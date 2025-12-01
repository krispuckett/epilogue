import SwiftUI

/// Renders beautiful atmospheric gradients from intelligent color extraction
/// Creates depth through layered radial glows rather than flat linear bands
struct AtmosphericGradientRenderer: View {
    let palette: IntelligentColorExtractor.IntelligentPalette
    var intensity: Double = 1.0
    var showDebugOverlay: Bool = false

    // Animation state
    @State private var animationPhase: Double = 0

    var body: some View {
        ZStack {
            // Layer 0: Base - the void/atmosphere
            baseLayer

            // Layer 1: Background wash (subtle, sets the tone)
            backgroundWash

            // Layer 2: Focal radiance (the hero glow)
            focalRadiance

            // Layer 3: Secondary accents (depth)
            secondaryAccents

            // Layer 4: Top fade for blending with content above
            topVignette

            // Layer 5: Bottom fade to black (for liquid glass)
            bottomFade

            // Debug overlay
            if showDebugOverlay {
                debugOverlay
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animationPhase = 1
            }
        }
    }

    // MARK: - Layer Components

    /// The deepest layer - pure background
    private var baseLayer: some View {
        Group {
            switch palette.coverType {
            case .dark:
                // Deep black for dark covers like LOTR
                Color.black
            case .light:
                // Off-white for light covers
                Color(white: 0.95)
            case .vibrant:
                // Darkened version of background for vibrant
                palette.background.opacity(0.3)
                    .overlay(Color.black.opacity(0.6))
            case .monochrome:
                // Grayscale base
                palette.background.saturation(0)
            case .photographic:
                // Neutral dark
                Color(white: 0.08)
            }
        }
        .ignoresSafeArea()
    }

    /// Subtle wash of background color across the view
    private var backgroundWash: some View {
        LinearGradient(
            stops: [
                .init(color: enhanceForAtmosphere(palette.background).opacity(0.4 * intensity), location: 0.0),
                .init(color: enhanceForAtmosphere(palette.background).opacity(0.2 * intensity), location: 0.3),
                .init(color: Color.clear, location: 0.6)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .blur(radius: 60)
    }

    /// The main focal point glow - emanates from where the "hero" element would be
    private var focalRadiance: some View {
        ZStack {
            // Primary focal glow
            if let primaryFocal = palette.focalColors.first {
                RadialGradient(
                    gradient: Gradient(colors: [
                        enhanceForGlow(primaryFocal.color).opacity(0.9 * intensity),
                        enhanceForGlow(primaryFocal.color).opacity(0.5 * intensity),
                        enhanceForGlow(primaryFocal.color).opacity(0.2 * intensity),
                        Color.clear
                    ]),
                    center: focalCenter,
                    startRadius: 0,
                    endRadius: 350
                )
                .blur(radius: 40)

                // Inner bright core
                RadialGradient(
                    gradient: Gradient(colors: [
                        enhanceForGlow(primaryFocal.color).opacity(0.6 * intensity),
                        Color.clear
                    ]),
                    center: focalCenter,
                    startRadius: 0,
                    endRadius: 150
                )
                .blur(radius: 25)
            }
        }
        .ignoresSafeArea()
    }

    /// Secondary color accents for depth
    private var secondaryAccents: some View {
        ZStack {
            // Secondary focal (offset to create asymmetry/depth)
            if palette.focalColors.count > 1 {
                let secondary = palette.focalColors[1]
                RadialGradient(
                    gradient: Gradient(colors: [
                        enhanceForGlow(secondary.color).opacity(0.5 * intensity),
                        enhanceForGlow(secondary.color).opacity(0.2 * intensity),
                        Color.clear
                    ]),
                    center: secondaryCenter,
                    startRadius: 0,
                    endRadius: 250
                )
                .blur(radius: 50)
            }

            // Accent highlight (if vibrant accent exists)
            if let accentColor = palette.focalColors.max(by: { $0.saturation < $1.saturation }),
               accentColor.saturation > 0.4 {
                RadialGradient(
                    gradient: Gradient(colors: [
                        enhanceForGlow(accentColor.color).opacity(0.3 * intensity),
                        Color.clear
                    ]),
                    center: .init(x: 0.7, y: 0.2),
                    startRadius: 0,
                    endRadius: 180
                )
                .blur(radius: 35)
            }
        }
        .ignoresSafeArea()
    }

    /// Subtle vignette at top to blend with any content above
    private var topVignette: some View {
        VStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
            Spacer()
        }
        .ignoresSafeArea()
    }

    /// Fade to black at bottom for liquid glass UI
    private var bottomFade: some View {
        VStack {
            Spacer()
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0.0),
                    .init(color: Color.black.opacity(0.5), location: 0.3),
                    .init(color: Color.black.opacity(0.85), location: 0.6),
                    .init(color: Color.black, location: 0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 400)
        }
        .ignoresSafeArea()
    }

    // MARK: - Positioning

    /// Where the main focal glow emanates from
    private var focalCenter: UnitPoint {
        switch palette.coverType {
        case .dark:
            // For dark covers like LOTR, glow from upper center (like the ring)
            return .init(x: 0.5, y: 0.15)
        case .light:
            // Light covers: subtle glow from center
            return .init(x: 0.5, y: 0.25)
        case .vibrant:
            // Vibrant: more dynamic positioning
            return .init(x: 0.4 + animationPhase * 0.1, y: 0.2)
        case .monochrome:
            // Monochrome: centered, subtle
            return .init(x: 0.5, y: 0.2)
        case .photographic:
            // Photos: upper center
            return .init(x: 0.5, y: 0.18)
        }
    }

    /// Secondary glow position (offset from primary for depth)
    private var secondaryCenter: UnitPoint {
        switch palette.coverType {
        case .dark:
            return .init(x: 0.3, y: 0.25)
        case .light:
            return .init(x: 0.6, y: 0.3)
        default:
            return .init(x: 0.6, y: 0.28)
        }
    }

    // MARK: - Color Enhancement

    /// Enhance color for atmospheric glow (more saturated, brighter)
    private func enhanceForGlow(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Boost saturation significantly for glowing effect
        let newSaturation = min(saturation * 1.5, 1.0)
        // Ensure minimum brightness for visibility
        let newBrightness = max(brightness, 0.5)

        return Color(hue: Double(hue), saturation: Double(newSaturation), brightness: Double(newBrightness))
    }

    /// Enhance color for atmospheric background (subtler)
    private func enhanceForAtmosphere(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Moderate saturation boost
        let newSaturation = min(saturation * 1.2, 0.8)
        // Keep brightness moderate for background
        let newBrightness = min(max(brightness, 0.3), 0.7)

        return Color(hue: Double(hue), saturation: Double(newSaturation), brightness: Double(newBrightness))
    }

    // MARK: - Debug Overlay

    private var debugOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Intelligent Extraction Debug")
                .font(.caption.bold())
                .foregroundStyle(.white)

            HStack(spacing: 4) {
                Text("Type:")
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(String(describing: palette.coverType))")
                    .foregroundStyle(.cyan)
            }
            .font(.caption2)

            HStack(spacing: 4) {
                Text("Confidence:")
                    .foregroundStyle(.white.opacity(0.7))
                Text("\(String(format: "%.0f", palette.confidence * 100))%")
                    .foregroundStyle(palette.confidence > 0.7 ? .green : .orange)
            }
            .font(.caption2)

            HStack(spacing: 4) {
                Text("Focal colors:")
                ForEach(palette.focalColors.prefix(4)) { color in
                    Circle()
                        .fill(color.color)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                }
            }
            .font(.caption2)

            HStack(spacing: 4) {
                Text("Background:")
                ForEach(palette.backgroundColors.prefix(2)) { color in
                    Circle()
                        .fill(color.color)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                }
            }
            .font(.caption2)

            Text("Method: \(palette.debugInfo.extractionMethod)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))

            Text("Text coverage: \(String(format: "%.1f", palette.debugInfo.textRegionsCoverage * 100))%")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))

            Text("Processing: \(String(format: "%.0f", palette.debugInfo.processingTimeMs))ms")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(0.9)
        )
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Legacy Compatibility Wrapper

/// Wrapper to use IntelligentPalette with existing ColorPalette-based views
struct IntelligentGradientView: View {
    let image: UIImage
    var intensity: Double = 1.0
    var showDebug: Bool = false

    @State private var palette: IntelligentColorExtractor.IntelligentPalette?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        ZStack {
            if let palette = palette {
                AtmosphericGradientRenderer(
                    palette: palette,
                    intensity: intensity,
                    showDebugOverlay: showDebug
                )
            } else if isLoading {
                Color.black
                    .overlay {
                        ProgressView()
                            .tint(.white.opacity(0.5))
                    }
            } else {
                // Fallback
                Color.black
            }
        }
        .task {
            await extractColors()
        }
    }

    private func extractColors() async {
        do {
            let extractor = IntelligentColorExtractor()
            palette = try await extractor.extractPalette(from: image, bookTitle: "preview")
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
            #if DEBUG
            print("❌ Intelligent extraction failed: \(error)")
            #endif
        }
    }
}

// MARK: - Preview

#Preview("Dark Cover (LOTR style)") {
    AtmosphericGradientRenderer(
        palette: .init(
            focalColors: [
                .init(color: Color(red: 0.83, green: 0.68, blue: 0.21), uiColor: .orange, dominance: 0.3, saturation: 0.75, brightness: 0.83, saliencyWeight: 0.9),
                .init(color: Color(red: 0.7, green: 0.2, blue: 0.1), uiColor: .red, dominance: 0.2, saturation: 0.85, brightness: 0.7, saliencyWeight: 0.7)
            ],
            backgroundColors: [
                .init(color: Color(white: 0.05), uiColor: .black, dominance: 0.5, saturation: 0, brightness: 0.05, saliencyWeight: 0.1)
            ],
            coverType: .dark,
            confidence: 0.85,
            debugInfo: .init(
                saliencyMapSize: CGSize(width: 68, height: 68),
                textRegionsFound: 2,
                textRegionsCoverage: 0.15,
                foregroundMaskAvailable: true,
                averageSaliency: 0.45,
                averageLuminance: 0.3,
                processingTimeMs: 150,
                extractionMethod: "saliency+text+foreground"
            )
        ),
        showDebugOverlay: true
    )
}
