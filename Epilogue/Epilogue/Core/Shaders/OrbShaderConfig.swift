import Foundation
import simd

/// Runtime-tweakable parameters for the Ambient Orb shader.
/// Must match `OrbParams` in AmbientOrbShader.metal exactly (field order + types).
struct OrbShaderConfig {
    // MARK: - Original params (16 floats)
    var speed: Float
    var circleSize: Float
    var freqMix: Float
    var bloomIntensity: Float
    var smoothing: Float
    var rotationBase: Float
    var turbAmplitude: Float
    var brightness: Float
    var tonemapGain: Float
    var colorTint: Float
    var maskInner: Float
    var maskOuter: Float
    var paletteSweep: Float
    var bloomClamp: Float
    var bloomMix: Float
    var rotationSpeed: Float

    // MARK: - Palette coefficients (12 floats)
    // Cosine palette: a + b * cos(TAU * (c * t + d))
    var palAR: Float; var palAG: Float; var palAB: Float
    var palBR: Float; var palBG: Float; var palBB: Float
    var palCR: Float; var palCG: Float; var palCB: Float
    var palDR: Float; var palDG: Float; var palDB: Float

    // MARK: - Press (2 floats)
    var pressBoost: Float       // max brightness multiplier on press
    var pressSmoothing: Float   // interpolation speed (0.15 = ~6 frames at 60fps)

    // MARK: - Secondary color blend (4 floats)
    var secondaryBlend: Float   // 0-1: how much secondary color mixes into palette
    var secondaryR: Float; var secondaryG: Float; var secondaryB: Float

    // MARK: - Parallax / gyroscope (3 floats)
    var parallaxAmount: Float   // tilt strength (0.0-0.15)
    var parallaxX: Float        // live gyro tilt X (set from CoreMotion)
    var parallaxY: Float        // live gyro tilt Y (set from CoreMotion)

    // MARK: - Audio reactivity (2 floats)
    var audioReactivity: Float  // strength of audio on bloom/turb (0-1)
    var audioLevel: Float       // live audio RMS level (set from AVAudioEngine)

    // MARK: - Depth layer (3 floats)
    var depthLayerScale: Float  // spatial scale for second pass (0 = off)
    var depthLayerBlend: Float  // blend amount (0-1)
    var depthLayerSpeed: Float  // time multiplier for depth layer

    // Total: 16 + 12 + 2 + 4 + 3 + 2 + 3 = 42 floats = 168 bytes

    /// Production golden baseline.
    static let golden = OrbShaderConfig(
        speed: 2.40, circleSize: 0.19, freqMix: 0.20,
        bloomIntensity: 0.53, smoothing: 1.45, rotationBase: 0.17,
        turbAmplitude: 0.27, brightness: 1.2, tonemapGain: 4.0,
        colorTint: 1.5, maskInner: 0.42, maskOuter: 0.52,
        paletteSweep: 0.19, bloomClamp: 250.0, bloomMix: 3.0,
        rotationSpeed: 0.07,
        // Palette: original cosine palette
        palAR: 0.5, palAG: 0.5, palAB: 0.5,
        palBR: 0.5, palBG: 0.5, palBB: 0.5,
        palCR: 1.0, palCG: 1.0, palCB: 1.0,
        palDR: 0.0, palDG: 0.243, palDB: 0.231,
        // Press
        pressBoost: 1.3, pressSmoothing: 0.15,
        // Secondary color (off by default)
        secondaryBlend: 0.0,
        secondaryR: 0.3, secondaryG: 0.5, secondaryB: 0.8,
        // Parallax (off by default)
        parallaxAmount: 0.0, parallaxX: 0.0, parallaxY: 0.0,
        // Audio (off by default)
        audioReactivity: 0.0, audioLevel: 0.0,
        // Depth layer (off by default)
        depthLayerScale: 0.0, depthLayerBlend: 0.0, depthLayerSpeed: 0.5
    )

    /// Copyable parameter dump for sharing tuned values.
    var exportString: String {
        """
        speed: \(f(speed)), circleSize: \(f(circleSize)), freqMix: \(f(freqMix)), \
        bloomIntensity: \(f(bloomIntensity)), smoothing: \(f(smoothing)), \
        rotationBase: \(f(rotationBase)), turbAmplitude: \(f(turbAmplitude)), \
        brightness: \(f(brightness)), tonemapGain: \(f(tonemapGain)), \
        colorTint: \(f(colorTint)), maskInner: \(f(maskInner)), maskOuter: \(f(maskOuter)), \
        paletteSweep: \(f(paletteSweep)), bloomClamp: \(f(bloomClamp)), \
        bloomMix: \(f(bloomMix)), rotationSpeed: \(f(rotationSpeed)), \
        palA: (\(f(palAR)), \(f(palAG)), \(f(palAB))), \
        palB: (\(f(palBR)), \(f(palBG)), \(f(palBB))), \
        palC: (\(f(palCR)), \(f(palCG)), \(f(palCB))), \
        palD: (\(f(palDR)), \(f(palDG)), \(f(palDB))), \
        pressBoost: \(f(pressBoost)), secondaryBlend: \(f(secondaryBlend)), \
        parallaxAmount: \(f(parallaxAmount)), audioReactivity: \(f(audioReactivity)), \
        depthLayerScale: \(f(depthLayerScale)), depthLayerBlend: \(f(depthLayerBlend)), \
        depthLayerSpeed: \(f(depthLayerSpeed))
        """
    }

    private func f(_ v: Float) -> String { String(format: "%.3f", v) }
}
