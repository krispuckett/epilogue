#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// MARK: - Simplex Noise Implementation
// Fast, high-quality 3D simplex noise for organic liquid motion
// Note: Functions prefixed with lg_ to avoid symbol collision with other shaders

static float3 lg_mod289_3(float3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

static float4 lg_mod289_4(float4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

static float4 lg_permute(float4 x) {
    return lg_mod289_4(((x * 34.0) + 1.0) * x);
}

static float4 lg_taylorInvSqrt(float4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

// 3D Simplex noise - returns value in range [-1, 1]
static float lg_snoise3D(float3 v) {
    const float2 C = float2(1.0/6.0, 1.0/3.0);
    const float4 D = float4(0.0, 0.5, 1.0, 2.0);

    // First corner
    float3 i = floor(v + dot(v, float3(C.y)));
    float3 x0 = v - i + dot(i, float3(C.x));

    // Other corners
    float3 g = step(x0.yzx, x0.xyz);
    float3 l = 1.0 - g;
    float3 i1 = min(g.xyz, l.zxy);
    float3 i2 = max(g.xyz, l.zxy);

    float3 x1 = x0 - i1 + C.x;
    float3 x2 = x0 - i2 + C.y;
    float3 x3 = x0 - D.yyy;

    // Permutations
    i = lg_mod289_3(i);
    float4 p = lg_permute(lg_permute(lg_permute(
        i.z + float4(0.0, i1.z, i2.z, 1.0))
        + i.y + float4(0.0, i1.y, i2.y, 1.0))
        + i.x + float4(0.0, i1.x, i2.x, 1.0));

    // Gradients
    float n_ = 0.142857142857;
    float3 ns = n_ * D.wyz - D.xzx;

    float4 j = p - 49.0 * floor(p * ns.z * ns.z);

    float4 x_ = floor(j * ns.z);
    float4 y_ = floor(j - 7.0 * x_);

    float4 x = x_ * ns.x + ns.yyyy;
    float4 y = y_ * ns.x + ns.yyyy;
    float4 h = 1.0 - abs(x) - abs(y);

    float4 b0 = float4(x.xy, y.xy);
    float4 b1 = float4(x.zw, y.zw);

    float4 s0 = floor(b0) * 2.0 + 1.0;
    float4 s1 = floor(b1) * 2.0 + 1.0;
    float4 sh = -step(h, float4(0.0));

    float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    float3 p0 = float3(a0.xy, h.x);
    float3 p1 = float3(a0.zw, h.y);
    float3 p2 = float3(a1.xy, h.z);
    float3 p3 = float3(a1.zw, h.w);

    // Normalise gradients
    float4 norm = lg_taylorInvSqrt(float4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    // Mix final noise value
    float4 m = max(0.6 - float4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m*m, float4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

// Fractal Brownian Motion - layered noise for organic complexity
static float lg_fbm3D(float3 p, int octaves, float persistence) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    float maxValue = 0.0;

    for (int i = 0; i < octaves; i++) {
        value += amplitude * lg_snoise3D(p * frequency);
        maxValue += amplitude;
        amplitude *= persistence;
        frequency *= 2.0;
    }

    return value / maxValue;
}

// MARK: - Liquid Glass Wave Shader (ULTRA Edition)
// Creates real pixel displacement with chromatic aberration, vortex, and turbulence

[[ stitchable ]] half4 liquidGlassWaveUltra(
    float2 position,
    SwiftUI::Layer layer,
    float2 touchOrigin,
    float elapsedTime,
    float waveSpeed,
    float displacementAmount,
    float refractionStrength,
    float noiseScale,
    float2 layerSize,
    // ULTRA parameters
    float chromaticAberration,  // 0-1: RGB channel separation
    float vortexStrength,       // 0-1: spiral swirl amount
    float waveRingCount,        // 1-10: number of wave rings
    float turbulence            // 0-1: chaos factor
) {
    // Vector from touch to current pixel
    float2 delta = position - touchOrigin;
    float dist = length(delta);

    // No effect at touch point itself
    if (dist < 1.0) {
        return layer.sample(position);
    }

    // Radial direction (outward from touch)
    float2 radialDir = delta / dist;

    // Angle from touch point (for vortex)
    float angle = atan2(delta.y, delta.x);

    // === EXPANDING WAVE RING ===
    float waveRadius = elapsedTime * waveSpeed * 200.0;
    float distFromWaveFront = dist - waveRadius;

    // Gaussian envelope - wave is strongest at the wavefront
    float waveWidth = 60.0 + elapsedTime * 30.0;
    float waveEnvelope = exp(-(distFromWaveFront * distFromWaveFront) / (2.0 * waveWidth * waveWidth));

    // Fade out over time
    float timeFade = exp(-elapsedTime * 0.4);

    // Distance fade
    float distFade = 1.0 / (1.0 + dist * 0.003);

    float intensity = waveEnvelope * timeFade * distFade;

    // Skip if negligible
    if (intensity < 0.001) {
        return layer.sample(position);
    }

    // === MULTI-RING WAVE DISPLACEMENT ===
    float combinedWave = 0.0;
    float ringSpacing = 0.08 / max(1.0, waveRingCount * 0.3);
    for (int ring = 0; ring < int(waveRingCount); ring++) {
        float freq = ringSpacing * (1.0 + float(ring) * 0.5);
        float ringWeight = 1.0 / (1.0 + float(ring) * 0.3);
        combinedWave += sin(distFromWaveFront * freq) * ringWeight;
    }
    combinedWave /= waveRingCount;

    // Radial displacement
    float radialDisplacement = combinedWave * displacementAmount * intensity;

    // === VORTEX SWIRL ===
    float vortexAngle = vortexStrength * intensity * 3.14159 * 2.0;
    // Swirl increases closer to center
    float vortexFalloff = exp(-dist * 0.005);
    vortexAngle *= vortexFalloff;

    // Rotate the radial direction by vortex angle
    float cosV = cos(vortexAngle);
    float sinV = sin(vortexAngle);
    float2 vortexDir = float2(
        radialDir.x * cosV - radialDir.y * sinV,
        radialDir.x * sinV + radialDir.y * cosV
    );

    // === ORGANIC NOISE + TURBULENCE ===
    float2 uv = position / layerSize;
    float3 noiseCoord = float3(
        uv.x * noiseScale + elapsedTime * 0.2,
        uv.y * noiseScale + elapsedTime * 0.15,
        elapsedTime * 0.3
    );

    // Base noise
    float noiseX = lg_fbm3D(noiseCoord, 2, 0.5);
    float noiseY = lg_fbm3D(noiseCoord + float3(50.0, 50.0, 0.0), 2, 0.5);

    // Turbulence adds high-frequency chaos
    float3 turbCoord = noiseCoord * 3.0 + float3(elapsedTime * 0.5, 0, 0);
    float turbX = lg_snoise3D(turbCoord) * turbulence;
    float turbY = lg_snoise3D(turbCoord + float3(100.0, 0, 0)) * turbulence;

    // Tangent direction for perpendicular displacement
    float2 tangentDir = float2(-vortexDir.y, vortexDir.x);
    float2 noiseDisplacement = tangentDir * (noiseX + turbX) * displacementAmount * 0.4 * intensity;
    noiseDisplacement += vortexDir * (noiseY + turbY) * displacementAmount * 0.2 * intensity;

    // === REFRACTION OFFSET ===
    float waveSlope = cos(distFromWaveFront * ringSpacing) * intensity;
    float2 refractionOffset = vortexDir * waveSlope * refractionStrength * 25.0;

    // === TOTAL DISPLACEMENT ===
    float2 totalDisplacement = vortexDir * radialDisplacement + noiseDisplacement + refractionOffset;

    // === CHROMATIC ABERRATION ===
    if (chromaticAberration > 0.001) {
        // Separate RGB channels with different offsets
        float chromaSpread = chromaticAberration * intensity * 15.0;

        float2 redOffset = totalDisplacement + vortexDir * chromaSpread;
        float2 greenOffset = totalDisplacement;
        float2 blueOffset = totalDisplacement - vortexDir * chromaSpread;

        float2 redPos = clamp(position + redOffset, float2(0.0), layerSize);
        float2 greenPos = clamp(position + greenOffset, float2(0.0), layerSize);
        float2 bluePos = clamp(position + blueOffset, float2(0.0), layerSize);

        half4 redSample = layer.sample(redPos);
        half4 greenSample = layer.sample(greenPos);
        half4 blueSample = layer.sample(bluePos);

        return half4(redSample.r, greenSample.g, blueSample.b,
                     (redSample.a + greenSample.a + blueSample.a) / 3.0h);
    }

    // No chromatic - single sample
    float2 samplePos = clamp(position + totalDisplacement, float2(0.0), layerSize);
    return layer.sample(samplePos);
}

// MARK: - Original Liquid Glass Wave Shader (kept for compatibility)
// Creates real pixel displacement - the gradient MOVES, not overlays

[[ stitchable ]] half4 liquidGlassWave(
    float2 position,
    SwiftUI::Layer layer,
    float2 touchOrigin,
    float elapsedTime,
    float waveSpeed,
    float displacementAmount,
    float refractionStrength,
    float noiseScale,
    float2 layerSize
) {
    // Vector from touch to current pixel
    float2 delta = position - touchOrigin;
    float dist = length(delta);

    // No effect at touch point itself
    if (dist < 1.0) {
        return layer.sample(position);
    }

    // Radial direction (outward from touch)
    float2 radialDir = delta / dist;

    // === EXPANDING WAVE RING ===
    // Wave expands outward from touch point
    float waveRadius = elapsedTime * waveSpeed * 200.0;
    float distFromWaveFront = dist - waveRadius;

    // Gaussian envelope - wave is strongest at the wavefront
    float waveWidth = 60.0 + elapsedTime * 30.0; // Gets wider as it expands
    float waveEnvelope = exp(-(distFromWaveFront * distFromWaveFront) / (2.0 * waveWidth * waveWidth));

    // Fade out over time
    float timeFade = exp(-elapsedTime * 0.4);

    // Distance fade (waves weaken as they spread)
    float distFade = 1.0 / (1.0 + dist * 0.003);

    float intensity = waveEnvelope * timeFade * distFade;

    // Skip if negligible
    if (intensity < 0.001) {
        return layer.sample(position);
    }

    // === SINUSOIDAL WAVE DISPLACEMENT ===
    // Multiple wave frequencies for richness
    float wave1 = sin(distFromWaveFront * 0.08);
    float wave2 = sin(distFromWaveFront * 0.12) * 0.5;
    float wave3 = sin(distFromWaveFront * 0.05) * 0.3;
    float combinedWave = (wave1 + wave2 + wave3) / 1.8;

    // Radial displacement - pushes pixels along the radial direction
    float radialDisplacement = combinedWave * displacementAmount * intensity;

    // === ORGANIC NOISE FOR LIQUID FEEL ===
    float2 uv = position / layerSize;
    float3 noiseCoord = float3(
        uv.x * noiseScale + elapsedTime * 0.2,
        uv.y * noiseScale + elapsedTime * 0.15,
        elapsedTime * 0.3
    );

    float noiseX = lg_fbm3D(noiseCoord, 2, 0.5);
    float noiseY = lg_fbm3D(noiseCoord + float3(50.0, 50.0, 0.0), 2, 0.5);

    // Add noise-based displacement perpendicular to wave direction
    float2 tangentDir = float2(-radialDir.y, radialDir.x);
    float2 noiseDisplacement = tangentDir * (noiseX * 0.5 + noiseY * 0.5) * displacementAmount * 0.3 * intensity;

    // === REFRACTION OFFSET ===
    // Simple refraction based on wave slope
    float waveSlope = cos(distFromWaveFront * 0.08) * intensity;
    float2 refractionOffset = radialDir * waveSlope * refractionStrength * 20.0;

    // === TOTAL DISPLACEMENT ===
    float2 totalDisplacement = radialDir * radialDisplacement + noiseDisplacement + refractionOffset;

    // Sample at displaced position
    float2 samplePos = position + totalDisplacement;

    // Keep in bounds
    samplePos = clamp(samplePos, float2(0.0), layerSize);

    return layer.sample(samplePos);
}

// MARK: - Multi-Touch Liquid Glass Wave
// Supports up to 3 simultaneous touch points

[[ stitchable ]] half4 multiTouchLiquidGlass(
    float2 position,
    SwiftUI::Layer layer,
    float2 layerSize,
    float elapsedTime,
    // Touch 1
    float2 touch1Origin,
    float touch1StartTime,
    float touch1Active,
    // Touch 2
    float2 touch2Origin,
    float touch2StartTime,
    float touch2Active,
    // Touch 3
    float2 touch3Origin,
    float touch3StartTime,
    float touch3Active,
    // Global parameters
    float waveSpeed,
    float displacementAmount,
    float refractionStrength,
    float noiseScale
) {
    float2 uv = position / layerSize;
    float2 totalDisplacement = float2(0.0);
    float2 totalRefraction = float2(0.0);
    float totalIntensity = 0.0;

    // Process each active touch
    for (int touchIdx = 0; touchIdx < 3; touchIdx++) {
        float2 touchOrigin;
        float touchStart;
        float active;

        if (touchIdx == 0) {
            touchOrigin = touch1Origin;
            touchStart = touch1StartTime;
            active = touch1Active;
        } else if (touchIdx == 1) {
            touchOrigin = touch2Origin;
            touchStart = touch2StartTime;
            active = touch2Active;
        } else {
            touchOrigin = touch3Origin;
            touchStart = touch3StartTime;
            active = touch3Active;
        }

        if (active < 0.5) continue;

        float touchAge = elapsedTime - touchStart;
        if (touchAge < 0.0) continue;

        float2 touchUV = touchOrigin / layerSize;
        float2 toTouch = uv - touchUV;
        float dist = length(toTouch) * layerSize.x;
        float2 direction = dist > 0.001 ? normalize(toTouch) : float2(0.0);

        // Wave propagation
        float waveRadius = touchAge * waveSpeed * 150.0;
        float distFromWave = dist - waveRadius;

        // Falloffs
        float waveWidth = 80.0 + touchAge * 40.0;
        float waveFalloff = exp(-distFromWave * distFromWave / (waveWidth * waveWidth));
        float distanceFalloff = exp(-dist * 0.003);
        float timeFalloff = exp(-touchAge * 0.5); // Waves fade over time

        float intensity = waveFalloff * distanceFalloff * timeFalloff;

        if (intensity < 0.001) continue;

        // Animated noise for this touch
        float3 noiseCoord = float3(
            uv.x * noiseScale + touchAge * 0.4 + float(touchIdx) * 50.0,
            uv.y * noiseScale + touchAge * 0.3,
            touchAge * waveSpeed * 0.6
        );

        float noiseX = lg_fbm3D(noiseCoord, 3, 0.5);
        float noiseY = lg_fbm3D(noiseCoord + float3(100.0, 100.0, 0.0), 3, 0.5);

        // Displacement
        float2 displacement = float2(noiseX, noiseY) * intensity;
        float radialPush = sin(distFromWave * 0.06) * intensity;
        displacement += direction * radialPush * 0.5;

        totalDisplacement += displacement;

        // Refraction normal
        float epsilon = 0.01;
        float heightCenter = lg_fbm3D(noiseCoord, 2, 0.5);
        float heightDx = lg_fbm3D(noiseCoord + float3(epsilon, 0, 0), 2, 0.5);
        float heightDy = lg_fbm3D(noiseCoord + float3(0, epsilon, 0), 2, 0.5);

        float3 normal = normalize(float3(
            (heightCenter - heightDx) / epsilon,
            (heightCenter - heightDy) / epsilon,
            1.0
        ));

        // Refraction
        float eta = 1.0 / 1.33;
        float3 viewDir = float3(0, 0, 1);
        float cosI = dot(normal, viewDir);
        float sinT2 = eta * eta * (1.0 - cosI * cosI);
        float cosT = sqrt(max(0.0, 1.0 - sinT2));
        float3 refracted = eta * (-viewDir) + (eta * cosI - cosT) * normal;

        totalRefraction += refracted.xy * intensity;
        totalIntensity += intensity;
    }

    // Apply combined offsets
    float2 finalOffset = totalDisplacement * displacementAmount + totalRefraction * refractionStrength * 50.0;
    float2 samplePos = clamp(position + finalOffset, float2(0.0), layerSize);

    half4 color = layer.sample(samplePos);

    // No overlays - pure displacement only
    return color;
}

// MARK: - Continuous Liquid Glass (Always Active)
// For ambient liquid effect without touch requirement

[[ stitchable ]] half4 ambientLiquidGlass(
    float2 position,
    SwiftUI::Layer layer,
    float2 layerSize,
    float elapsedTime,
    float flowSpeed,
    float displacementAmount,
    float refractionStrength,
    float noiseScale
) {
    float2 uv = position / layerSize;

    // Flowing noise coordinates
    float3 noiseCoord = float3(
        uv.x * noiseScale + elapsedTime * flowSpeed * 0.2,
        uv.y * noiseScale + elapsedTime * flowSpeed * 0.15,
        elapsedTime * flowSpeed * 0.1
    );

    // Organic displacement
    float noiseX = lg_fbm3D(noiseCoord, 4, 0.5);
    float noiseY = lg_fbm3D(noiseCoord + float3(50.0, 50.0, 0.0), 4, 0.5);
    float2 displacement = float2(noiseX, noiseY) * displacementAmount;

    // Surface normal for refraction
    float epsilon = 0.01;
    float h0 = lg_fbm3D(noiseCoord, 3, 0.5);
    float hx = lg_fbm3D(noiseCoord + float3(epsilon, 0, 0), 3, 0.5);
    float hy = lg_fbm3D(noiseCoord + float3(0, epsilon, 0), 3, 0.5);

    float3 normal = normalize(float3((h0 - hx) / epsilon, (h0 - hy) / epsilon, 1.0));

    // Refraction
    float eta = 1.0 / 1.4;
    float cosI = normal.z;
    float sinT2 = eta * eta * (1.0 - cosI * cosI);
    float cosT = sqrt(max(0.0, 1.0 - sinT2));
    float2 refractionOffset = normal.xy * (eta * cosI - cosT) * refractionStrength * 30.0;

    // Combined offset
    float2 totalOffset = displacement + refractionOffset;
    float2 samplePos = clamp(position + totalOffset, float2(0.0), layerSize);

    return layer.sample(samplePos);
}
