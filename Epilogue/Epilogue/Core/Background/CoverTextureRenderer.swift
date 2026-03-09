import SwiftUI
import UIKit

/// Renders a book cover as a blurred, scaled texture background — the Apple Music approach.
/// Used when color extraction confidence is low, bypassing extraction entirely
/// to produce organic, contextual backgrounds from the cover image itself.
struct CoverTextureRenderer: View {
    let coverImage: UIImage
    let intensity: Double
    let warmthShift: Double // -1 (cool) to +1 (warm), 0 = neutral

    @State private var breathePhase: Double = 0

    init(coverImage: UIImage, intensity: Double = 1.0, warmthShift: Double = 0) {
        self.coverImage = coverImage
        self.intensity = intensity
        self.warmthShift = warmthShift
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                // Layer 1: Base texture — heavily blurred, 2.5x scale
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: geometry.size.width * 2.5,
                        height: geometry.size.height * 2.5
                    )
                    .blur(radius: 80)
                    .opacity(intensity * 0.7)
                    .offset(x: -geometry.size.width * 0.3, y: -geometry.size.height * 0.2)

                // Layer 2: Rotated copy — different transform for organic feel
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: geometry.size.width * 2.0,
                        height: geometry.size.height * 2.0
                    )
                    .blur(radius: 60)
                    .rotationEffect(.degrees(15))
                    .opacity(intensity * 0.4)
                    .offset(x: geometry.size.width * 0.2, y: geometry.size.height * 0.1)
                    .blendMode(.plusLighter)

                // Layer 3: Offset copy for depth
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: geometry.size.width * 3.0,
                        height: geometry.size.height * 3.0
                    )
                    .blur(radius: 100)
                    .rotationEffect(.degrees(-10))
                    .opacity(intensity * 0.3)
                    .offset(x: 0, y: geometry.size.height * 0.3)

                // Warmth/coolness grading overlay
                if warmthShift != 0 {
                    colorGradingOverlay
                }

                // Vignette for depth
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.4)],
                    center: UnitPoint(x: 0.5, y: 0.3),
                    startRadius: geometry.size.width * 0.3,
                    endRadius: geometry.size.width * 0.9
                )
            }
            .clipped()
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var colorGradingOverlay: some View {
        if warmthShift > 0 {
            // Warm shift — amber overlay
            Color(lightness: 0.5, chroma: 0.08, hue: 55)
                .opacity(Double(warmthShift) * 0.15)
                .blendMode(.overlay)
        } else {
            // Cool shift — blue overlay
            Color(lightness: 0.5, chroma: 0.08, hue: 240)
                .opacity(Double(-warmthShift) * 0.15)
                .blendMode(.overlay)
        }
    }
}

// MARK: - Blended Renderer

/// Blends cover texture with extracted atmosphere for medium-confidence covers.
/// Confidence drives the blend ratio: more texture for lower confidence.
struct BlendedAtmosphereRenderer: View {
    let coverImage: UIImage
    let palette: DisplayPalette
    let confidence: Float
    let intensity: Double
    let audioLevel: Float

    /// 0 = full texture, 1 = full atmosphere
    private var atmosphereBlend: Double {
        // Map confidence 0.25-0.5 to blend 0.0-1.0
        Double(max(0, min(1, (confidence - 0.25) / 0.25)))
    }

    var body: some View {
        ZStack {
            // Texture base
            CoverTextureRenderer(
                coverImage: coverImage,
                intensity: intensity * (1.0 - atmosphereBlend)
            )

            // Atmosphere overlay
            UnifiedAtmosphericGradient(
                palette: palette,
                preset: .atmospheric,
                intensity: intensity * atmosphereBlend,
                audioLevel: audioLevel
            )
        }
    }
}
