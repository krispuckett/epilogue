#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// =============================================================================
// Fluid Ambient Gradient — Single-pass domain-warped FBM colorEffect
//
// Produces liquid, organic gradients from book cover colors.
// Uses Inigo Quilez's domain warping technique for the fluid quality.
// Applied via .colorEffect() on a Rectangle() — no MTKView needed.
// =============================================================================

// MARK: - Noise Utilities

// PCG hash for film grain
static float fa_hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Value noise with quintic interpolation
static float fa_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);

    // Quintic Hermite — smoother than cubic, no discontinuities in 2nd derivative
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float a = fa_hash(i + float2(0.0, 0.0));
    float b = fa_hash(i + float2(1.0, 0.0));
    float c = fa_hash(i + float2(0.0, 1.0));
    float d = fa_hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// FBM — fractional Brownian motion
// Rotation matrix per octave breaks axis-aligned artifacts
static float fa_fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float2x2 rot = float2x2(0.8, -0.6, 0.6, 0.8);

    for (int i = 0; i < octaves; i++) {
        value += amplitude * fa_noise(p);
        p = rot * p * 2.0; // lacunarity = 2.0
        amplitude *= 0.5;  // gain = 0.5
    }
    return value;
}

// MARK: - Domain-Warped Pattern (the "liquid" quality)
// Feed FBM output back as input coordinates — creates organic, marble-like flow.
// Reference: iquilezles.org/articles/warp

static float fa_fluidPattern(float2 p, float time) {
    // First warp layer
    float2 q = float2(
        fa_fbm(p + float2(0.0, 0.0) + time * 0.04, 5),
        fa_fbm(p + float2(5.2, 1.3) + time * 0.03, 5)
    );

    // Second warp layer — feeds off the first
    float2 r = float2(
        fa_fbm(p + 4.0 * q + float2(1.7, 9.2) + time * 0.02, 5),
        fa_fbm(p + 4.0 * q + float2(8.3, 2.8) + time * 0.025, 5)
    );

    // Final pattern — double domain-warped
    return fa_fbm(p + 4.0 * r, 5);
}

// MARK: - HSL Saturation Boost

static half3 fa_adjustSaturation(half3 rgb, float amount) {
    // Luminance weights (Rec. 709)
    half luma = dot(rgb, half3(0.2126h, 0.7152h, 0.0722h));
    return mix(half3(luma), rgb, half(amount));
}

// MARK: - Main Shader

[[ stitchable ]] half4 fluidAmbient(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    // Colors (pre-converted from OKLCH to sRGB on Swift side)
    half4 primaryColor,
    half4 secondaryColor,
    half4 accentColor,
    half4 backgroundColor,
    half4 complementaryColor,
    // Cover-type-aware config params
    float colorIntensity,     // 0.3-0.9: overall color vibrancy
    float noiseAmplitude,     // 0.04-0.15: organic variation strength
    float darkFadeStart,      // 0.2-0.4: where vertical fade to black begins
    float accentInfluence,    // 0.1-0.6: accent color presence
    float secondarySpread,    // 0.15-0.6: secondary color spread
    float noiseScale,         // 1.5-4.0: spatial frequency of noise field
    float warpIntensity,      // 0.5-2.0: domain warp strength multiplier
    // Extended params
    float originX,            // 0.0-1.0: focal point X
    float originY,            // 0.0-1.0: focal point Y
    float backgroundBlend,    // 0.0-0.6: background color presence
    float complementaryMix,   // 0.0-0.5: complementary color presence
    float grainAmount,        // 0.0-0.08: film grain intensity
    float vignetteStrength,   // 0.0-1.0: edge darkening
    float contrast,           // 0.5-2.0: power curve on result
    float saturationBoost,    // 0.5-2.0: post-process saturation
    // Ripple params
    float rippleIntensity,    // 0.0-0.3: concentric wave strength
    float rippleFrequency,    // 8.0-30.0: wave tightness
    float rippleSpeed,        // 1.0-5.0: wave expansion speed
    // New extended params
    float colorTemperature,   // -0.5-0.5: warm/cool color shift
    float bloomStrength,      // 0.0-0.4: soft glow from bright areas
    float brightnessBoost,    // 0.5-2.0: overall brightness multiplier
    float swirlAmount,        // 0.0-2.0: rotational distortion around origin
    float fadeExponent         // 0.5-3.0: controls fade curve shape
) {
    float2 uv = position / size;

    // Remap UV relative to focal origin (creates radial field from origin point)
    float2 origin = float2(originX, originY);
    float distFromOrigin = distance(uv, origin);

    // Aspect-correct noise coordinates, offset by origin
    float aspect = size.x / max(size.y, 1.0);
    float2 noiseCoord = float2((uv.x - origin.x * 0.3) * aspect, uv.y - origin.y * 0.3) * noiseScale;

    // 0. Swirl — rotational distortion around origin for vortex effects
    if (swirlAmount > 0.01) {
        float2 delta = uv - origin;
        float dist = length(delta);
        float angle = swirlAmount * exp(-dist * 3.0); // stronger near origin, fades outward
        float s = sin(angle + time * 0.1);
        float c = cos(angle + time * 0.1);
        float2 rotated = float2(delta.x * c - delta.y * s, delta.x * s + delta.y * c);
        noiseCoord = float2((rotated.x + origin.x - origin.x * 0.3) * aspect,
                            rotated.y + origin.y - origin.y * 0.3) * noiseScale;
    }

    // 1. Domain-warped noise pattern — this is what makes it "liquid"
    float pattern = fa_fluidPattern(noiseCoord * warpIntensity, time);

    // 1b. Ripple modulation — concentric waves from origin that breathe through the noise
    if (rippleIntensity > 0.001) {
        float rippleDist = distance(float2(uv.x * aspect, uv.y), float2(origin.x * aspect, origin.y));
        // Multiple expanding wavefronts with slight phase offsets
        float wave1 = sin(rippleDist * rippleFrequency - time * rippleSpeed);
        float wave2 = sin(rippleDist * rippleFrequency * 0.7 - time * rippleSpeed * 0.8 + 1.5) * 0.5;
        float wave3 = sin(rippleDist * rippleFrequency * 1.3 - time * rippleSpeed * 1.2 + 3.0) * 0.3;
        float ripple = (wave1 + wave2 + wave3) / 1.8;

        // Fade with distance from origin
        float rippleEnvelope = exp(-rippleDist * 2.0);

        // Modulate the pattern — ripple bends the noise field
        pattern += ripple * rippleEnvelope * rippleIntensity * 3.0;
    }

    // 2. Create five influence zones using warped noise
    //    Each color gets its own spatial domain driven by noise
    float primaryInfluence = smoothstep(0.3, 0.7,
        1.0 - uv.y + noiseAmplitude * pattern
        - distFromOrigin * 0.3);  // primary radiates from origin

    float secondaryInfluenceVal = smoothstep(0.3, 0.7,
        fa_fbm(noiseCoord * 1.2 + float2(3.1, 7.4) + time * 0.015, 4))
        * secondarySpread;

    float accentInfluenceVal = smoothstep(0.4, 0.8,
        fa_fbm(noiseCoord * 0.8 + float2(8.7, 2.1) + time * 0.02, 4))
        * accentInfluence;

    // Background color influence — pools at edges and bottom
    float bgInfluence = smoothstep(0.2, 0.6,
        distFromOrigin * 1.5 +
        fa_fbm(noiseCoord * 0.6 + float2(2.3, 5.9) + time * 0.01, 3) * 0.3)
        * backgroundBlend;

    // Complementary color — weaves through as accent threads
    float compInfluence = smoothstep(0.5, 0.9,
        fa_fbm(noiseCoord * 1.5 + float2(11.7, 4.3) + time * 0.018, 4))
        * complementaryMix;

    // 3. Blend colors based on influence zones
    half3 colorMix = primaryColor.rgb * half(primaryInfluence);
    colorMix = mix(colorMix, secondaryColor.rgb, half(secondaryInfluenceVal));
    colorMix = mix(colorMix, accentColor.rgb, half(accentInfluenceVal));
    colorMix = mix(colorMix, backgroundColor.rgb, half(bgInfluence));
    colorMix = mix(colorMix, complementaryColor.rgb, half(compInfluence));
    colorMix *= half(colorIntensity);

    // 3b. Color temperature — shift warm (positive) or cool (negative)
    if (abs(colorTemperature) > 0.01) {
        half temp = half(colorTemperature);
        colorMix.r += temp * 0.15h;
        colorMix.g -= abs(temp) * 0.03h;
        colorMix.b -= temp * 0.15h;
    }

    // 4. Vertical fade: rich color at top → near-black at bottom
    //    Noise warps the fade boundary for organic edge
    float verticalFade = smoothstep(darkFadeStart, 0.85, uv.y);
    verticalFade += 0.08 * (pattern - 0.5);
    verticalFade = saturate(verticalFade);

    // Apply fade exponent for curve control
    verticalFade = pow(verticalFade, fadeExponent);

    half3 nearBlack = half3(0.04h, 0.035h, 0.04h);
    half3 result = mix(colorMix, nearBlack, half(verticalFade));

    // 5. Hard floor — ensures text legibility at bottom
    float hardFloor = smoothstep(0.82, 1.0, uv.y);
    result = mix(result, nearBlack, half(hardFloor));

    // 6. Vignette — darkens edges for cinematic depth
    if (vignetteStrength > 0.01) {
        float2 vigUV = uv - 0.5;
        float vignette = 1.0 - dot(vigUV, vigUV) * vignetteStrength * 2.0;
        vignette = saturate(vignette);
        result *= half(vignette);
    }

    // 7. Brightness boost — overall multiplier
    if (abs(brightnessBoost - 1.0) > 0.01) {
        result *= half(brightnessBoost);
    }

    // 8. Contrast curve — power function for punch
    if (abs(contrast - 1.0) > 0.01) {
        result = pow(max(result, half3(0.0h)), half3(half(contrast)));
    }

    // 9. Saturation boost — post-process vibrancy
    if (abs(saturationBoost - 1.0) > 0.01) {
        result = fa_adjustSaturation(result, saturationBoost);
    }

    // 10. Bloom — soft glow from bright areas
    if (bloomStrength > 0.01) {
        half luma = dot(result, half3(0.2126h, 0.7152h, 0.0722h));
        half bloomMask = smoothstep(0.4h, 0.9h, luma);
        // Add a warm glow from bright regions
        half3 bloom = result * bloomMask * half(bloomStrength) * 2.0h;
        result += bloom;
    }

    // 11. Film grain — eliminates banding in gradient transitions
    float grain = fa_hash(position + fract(time) * 100.0);
    result += half3((grain - 0.5h) * half(grainAmount));

    return half4(saturate(result), 1.0h);
}
