import SwiftUI

/// Fluid ambient gradient using domain-warped FBM noise.
/// Single-pass Metal colorEffect shader — liquid, organic quality.
struct FluidAmbientGradientView: View {
    let colorSet: FluidLabColorSet
    @Binding var config: FluidAmbientConfig

    @State private var startTime = Date.now

    var body: some View {
        let cfg = config
        let cs = colorSet

        TimelineView(.animation) { timeline in
            let elapsed = Float(startTime.distance(to: timeline.date))
            let time = elapsed * cfg.animationSpeed

            Rectangle()
                .visualEffect { content, geometryProxy in
                    content.colorEffect(
                        ShaderLibrary.fluidAmbient(
                            .float2(geometryProxy.size),
                            .float(time),
                            .color(cs.primary),
                            .color(cs.secondary),
                            .color(cs.accent),
                            .color(cs.background),
                            .color(cs.complementary),
                            .float(cfg.colorIntensity),
                            .float(cfg.noiseAmplitude),
                            .float(cfg.darkFadeStart),
                            .float(cfg.accentInfluence),
                            .float(cfg.secondarySpread),
                            .float(cfg.noiseScale),
                            .float(cfg.warpIntensity),
                            .float(cfg.originX),
                            .float(cfg.originY),
                            .float(cfg.backgroundBlend),
                            .float(cfg.complementaryMix),
                            .float(cfg.grainAmount),
                            .float(cfg.vignetteStrength),
                            .float(cfg.contrast),
                            .float(cfg.saturationBoost),
                            .float(cfg.rippleIntensity),
                            .float(cfg.rippleFrequency),
                            .float(cfg.rippleSpeed),
                            .float(cfg.colorTemperature),
                            .float(cfg.bloomStrength),
                            .float(cfg.brightnessBoost),
                            .float(cfg.swirlAmount),
                            .float(cfg.fadeExponent)
                        )
                    )
                }
                .drawingGroup()
                .ignoresSafeArea()
        }
    }
}
