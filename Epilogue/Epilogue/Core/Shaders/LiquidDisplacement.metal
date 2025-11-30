#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// MARK: - Liquid Displacement Shader
// Creates organic, flowing displacement like liquid metal or mercury
// Inspired by ferrofluid and magnetic field interactions

// Simplex noise helper for organic movement
float3 mod289(float3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float4 mod289(float4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float4 permute(float4 x) {
    return mod289(((x * 34.0) + 1.0) * x);
}

float4 taylorInvSqrt(float4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

// 3D Simplex noise
float snoise(float3 v) {
    const float2 C = float2(1.0/6.0, 1.0/3.0);
    const float4 D = float4(0.0, 0.5, 1.0, 2.0);

    float3 i = floor(v + dot(v, float3(C.y)));
    float3 x0 = v - i + dot(i, float3(C.x));

    float3 g = step(x0.yzx, x0.xyz);
    float3 l = 1.0 - g;
    float3 i1 = min(g.xyz, l.zxy);
    float3 i2 = max(g.xyz, l.zxy);

    float3 x1 = x0 - i1 + C.x;
    float3 x2 = x0 - i2 + C.y;
    float3 x3 = x0 - D.yyy;

    i = mod289(i);
    float4 p = permute(permute(permute(
        i.z + float4(0.0, i1.z, i2.z, 1.0))
        + i.y + float4(0.0, i1.y, i2.y, 1.0))
        + i.x + float4(0.0, i1.x, i2.x, 1.0));

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

    float4 norm = taylorInvSqrt(float4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    float4 m = max(0.6 - float4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m*m, float4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

// Fractal Brownian Motion for layered organic movement
float fbm(float3 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amplitude * snoise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

// MARK: - Main Liquid Displacement Effect
// Creates flowing, organic displacement like liquid metal
[[ stitchable ]] half4 liquid_displacement(
    float2 position,
    SwiftUI::Layer layer,
    float4 boundingRect,
    float time,
    float intensity,
    float scale,
    float speed
) {
    float2 size = boundingRect.zw;
    float2 uv = position / size;

    // Multi-layered organic displacement
    float3 noiseCoord = float3(uv * scale, time * speed * 0.3);

    // Primary displacement wave
    float displacement1 = fbm(noiseCoord, 4);

    // Secondary displacement (different frequency)
    float3 noiseCoord2 = float3(uv * scale * 1.5 + 0.5, time * speed * 0.4 + 100.0);
    float displacement2 = fbm(noiseCoord2, 3);

    // Tertiary micro-detail
    float3 noiseCoord3 = float3(uv * scale * 3.0, time * speed * 0.5 + 200.0);
    float displacement3 = snoise(noiseCoord3) * 0.3;

    // Combine displacements with falloff from edges
    float edgeFalloff = smoothstep(0.0, 0.3, 0.5 - abs(uv.x - 0.5)) *
                        smoothstep(0.0, 0.3, 0.5 - abs(uv.y - 0.5));

    float totalDisplacement = (displacement1 * 0.6 + displacement2 * 0.3 + displacement3 * 0.1);
    totalDisplacement *= edgeFalloff * intensity;

    // Calculate displacement direction (perpendicular to gradient)
    float dx = fbm(noiseCoord + float3(0.01, 0, 0), 3) - fbm(noiseCoord - float3(0.01, 0, 0), 3);
    float dy = fbm(noiseCoord + float3(0, 0.01, 0), 3) - fbm(noiseCoord - float3(0, 0.01, 0), 3);
    float2 gradient = normalize(float2(dx, dy) + 0.001);

    // Apply displacement
    float2 displacedUV = uv + gradient * totalDisplacement * 0.1;
    float2 samplePos = displacedUV * size;

    // Sample with displacement
    half4 color = layer.sample(samplePos);

    // Add subtle specular highlight based on displacement
    float specular = pow(max(0.0, totalDisplacement + 0.5), 3.0) * 0.15;
    color.rgb += half3(specular);

    return color;
}

// MARK: - Chromatic Liquid Displacement
// Adds RGB channel separation for prismatic liquid effect
[[ stitchable ]] half4 chromatic_liquid(
    float2 position,
    SwiftUI::Layer layer,
    float4 boundingRect,
    float time,
    float intensity,
    float chromaticSpread
) {
    float2 size = boundingRect.zw;
    float2 uv = position / size;
    float2 center = float2(0.5, 0.5);
    float2 toCenter = uv - center;

    // Organic displacement field
    float3 noiseCoord = float3(uv * 2.5, time * 0.2);
    float displacement = fbm(noiseCoord, 4) * intensity;

    // Direction of displacement
    float angle = atan2(toCenter.y, toCenter.x) + displacement * 2.0;
    float2 direction = float2(cos(angle), sin(angle));

    // Chromatic aberration offsets
    float spread = chromaticSpread * displacement;
    float2 redOffset = direction * spread;
    float2 greenOffset = float2(0.0);
    float2 blueOffset = -direction * spread;

    // Sample each channel separately
    half4 redSample = layer.sample(position + redOffset * size * 0.1);
    half4 greenSample = layer.sample(position + greenOffset * size * 0.1);
    half4 blueSample = layer.sample(position + blueOffset * size * 0.1);

    // Combine channels
    half4 result;
    result.r = redSample.r;
    result.g = greenSample.g;
    result.b = blueSample.b;
    result.a = (redSample.a + greenSample.a + blueSample.a) / 3.0;

    return result;
}

// MARK: - Magnetic Field Displacement
// Creates ferrofluid-like spiky displacement patterns
[[ stitchable ]] half4 magnetic_displacement(
    float2 position,
    SwiftUI::Layer layer,
    float4 boundingRect,
    float2 fieldCenter,
    float time,
    float fieldStrength
) {
    float2 size = boundingRect.zw;
    float2 uv = position / size;
    float2 fieldUV = fieldCenter / size;

    // Vector from field center
    float2 toField = uv - fieldUV;
    float dist = length(toField);

    // Magnetic field falloff
    float fieldIntensity = 1.0 / (1.0 + dist * 4.0);
    fieldIntensity = pow(fieldIntensity, 1.5) * fieldStrength;

    // Spiky displacement pattern (ferrofluid-like)
    float angle = atan2(toField.y, toField.x);
    float spikes = sin(angle * 12.0 + time * 2.0) * 0.5 + 0.5;
    spikes = pow(spikes, 2.0);

    // Add organic variation
    float3 noiseCoord = float3(uv * 5.0, time * 0.3);
    float organic = fbm(noiseCoord, 3) * 0.5 + 0.5;

    // Combined displacement
    float displacement = fieldIntensity * (spikes * 0.7 + organic * 0.3);

    // Displacement direction (radial from field center)
    float2 direction = dist > 0.001 ? normalize(toField) : float2(0.0);
    float2 displacedPos = position + direction * displacement * size.x * 0.1;

    // Sample with displacement
    half4 color = layer.sample(displacedPos);

    // Add metallic sheen at spike peaks
    float sheen = spikes * fieldIntensity * 0.3;
    color.rgb += half3(sheen * 0.8, sheen * 0.9, sheen);

    return color;
}

// MARK: - Ripple Displacement
// Clean concentric ripple effect like liquid surface
[[ stitchable ]] half4 ripple_displacement(
    float2 position,
    SwiftUI::Layer layer,
    float4 boundingRect,
    float2 rippleCenter,
    float time,
    float frequency,
    float amplitude,
    float decay
) {
    float2 centerPos = rippleCenter;

    // Distance from ripple center
    float2 delta = position - centerPos;
    float dist = length(delta);

    // Ripple wave with decay
    float wave = sin(dist * frequency - time * 8.0);
    float envelope = exp(-dist * decay) * amplitude;
    float displacement = wave * envelope;

    // Displace along radial direction
    float2 direction = dist > 0.001 ? normalize(delta) : float2(0.0);
    float2 displacedPos = position + direction * displacement;

    // Sample with displacement
    half4 color = layer.sample(displacedPos);

    // Add subtle caustic-like brightness variation
    float caustic = pow(abs(wave) * envelope, 2.0) * 0.2;
    color.rgb += half3(caustic);

    return color;
}

// MARK: - Touch Interactive Ripple (Distortion Effect)
// Simple, clean water ripple - just like dropping a stone in water
[[ stitchable ]] float2 touch_ripple_distortion(
    float2 position,
    float currentTime,
    float2 ripple1Pos,
    float ripple1Birth,
    float ripple1Intensity,
    float2 ripple2Pos,
    float ripple2Birth,
    float ripple2Intensity,
    float2 ripple3Pos,
    float ripple3Birth,
    float ripple3Intensity,
    float waveSpeed,
    float waveFrequency,
    float maxAmplitude,
    float lifetime
) {
    float2 offset = float2(0.0);

    // Ripple 1
    if (ripple1Intensity > 0.0) {
        float t = currentTime - ripple1Birth;
        if (t > 0.0 && t < lifetime) {
            float2 dir = position - ripple1Pos;
            float dist = length(dir);
            if (dist > 0.0) {
                dir /= dist;
                // Expanding wave: the key is (dist - speed*time)
                float rippleAge = t * waveSpeed * 400.0;
                float x = dist - rippleAge;
                // Gaussian envelope centered on the wave front
                float envelope = exp(-x * x / 5000.0);
                // Fade out over lifetime
                float fade = 1.0 - t / lifetime;
                // Sinusoidal displacement
                float wave = sin(x * waveFrequency * 0.15) * envelope * fade * ripple1Intensity;
                offset += dir * wave * maxAmplitude;
            }
        }
    }

    // Ripple 2
    if (ripple2Intensity > 0.0) {
        float t = currentTime - ripple2Birth;
        if (t > 0.0 && t < lifetime) {
            float2 dir = position - ripple2Pos;
            float dist = length(dir);
            if (dist > 0.0) {
                dir /= dist;
                float rippleAge = t * waveSpeed * 400.0;
                float x = dist - rippleAge;
                float envelope = exp(-x * x / 5000.0);
                float fade = 1.0 - t / lifetime;
                float wave = sin(x * waveFrequency * 0.15) * envelope * fade * ripple2Intensity;
                offset += dir * wave * maxAmplitude;
            }
        }
    }

    // Ripple 3
    if (ripple3Intensity > 0.0) {
        float t = currentTime - ripple3Birth;
        if (t > 0.0 && t < lifetime) {
            float2 dir = position - ripple3Pos;
            float dist = length(dir);
            if (dist > 0.0) {
                dir /= dist;
                float rippleAge = t * waveSpeed * 400.0;
                float x = dist - rippleAge;
                float envelope = exp(-x * x / 5000.0);
                float fade = 1.0 - t / lifetime;
                float wave = sin(x * waveFrequency * 0.15) * envelope * fade * ripple3Intensity;
                offset += dir * wave * maxAmplitude;
            }
        }
    }

    return offset;
}

// MARK: - Single Touch Ripple Distortion
[[ stitchable ]] float2 single_touch_ripple_distortion(
    float2 position,
    float2 touchPos,
    float touchAge,
    float intensity,
    float speed,
    float frequency,
    float amplitude
) {
    if (intensity <= 0.0 || touchAge <= 0.0 || touchAge > 2.5) {
        return float2(0.0);
    }

    float2 dir = position - touchPos;
    float dist = length(dir);

    if (dist < 1.0) {
        return float2(0.0);
    }

    dir /= dist;

    // The magic formula: wave front expands outward
    float rippleRadius = touchAge * speed * 400.0;
    float x = dist - rippleRadius;

    // Gaussian packet traveling outward
    float envelope = exp(-x * x / 6000.0);

    // Temporal fade
    float fade = 1.0 - touchAge / 2.5;

    // The wave itself
    float wave = sin(x * frequency * 0.12) * envelope * fade * intensity;

    return dir * wave * amplitude;
}
