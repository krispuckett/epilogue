#include <metal_stdlib>
using namespace metal;

// Iteration count — set at pipeline creation via MTLFunctionConstantValues.
constant int ITERATIONS [[function_constant(0)]];

// Runtime-tweakable parameters — must match OrbShaderConfig in Swift.
struct OrbParams {
    // Original 16
    float speed;
    float circleSize;
    float freqMix;
    float bloomIntensity;
    float smoothing;
    float rotationBase;
    float turbAmplitude;
    float brightness;
    float tonemapGain;
    float colorTint;
    float maskInner;
    float maskOuter;
    float paletteSweep;
    float bloomClamp;
    float bloomMix;
    float rotationSpeed;

    // Palette coefficients (4 × RGB)
    float palAR, palAG, palAB;
    float palBR, palBG, palBB;
    float palCR, palCG, palCB;
    float palDR, palDG, palDB;

    // Press
    float pressBoost;
    float pressSmoothing; // unused in shader (handled Swift-side)

    // Secondary color
    float secondaryBlend;
    float secondaryR, secondaryG, secondaryB;

    // Parallax
    float parallaxAmount;
    float parallaxX;
    float parallaxY;

    // Audio
    float audioReactivity;
    float audioLevel;

    // Depth layer
    float depthLayerScale;
    float depthLayerBlend;
    float depthLayerSpeed;
};

// MARK: - Vertex

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut ambientOrbVertex(uint vertexID [[vertex_id]]) {
    float2 positions[6] = {
        float2(-1.0, -1.0), float2( 1.0, -1.0), float2(-1.0,  1.0),
        float2( 1.0, -1.0), float2( 1.0,  1.0), float2(-1.0,  1.0)
    };

    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = (positions[vertexID] + 1.0) * 0.5;
    out.texCoord.y = 1.0 - out.texCoord.y;
    return out;
}

// MARK: - Half-precision helpers

constant half PI_H  = 3.14159265h;
constant half TAU_H = 6.28318530h;

half3 orbPal(half t, half3 a, half3 b, half3 c, half3 d) {
    return a + b * cos(TAU_H * (c * t + d));
}

half3 orbTonemap(half3 x, half gain) {
    x *= gain;
    return x / (1.0h + x);
}

half orbSdCircle(half2 st, half r) {
    return length(st) - r;
}

half2 orbTurb(half2 pos, half t, half it, half freqMix, half amp) {
    half2x2 rot = half2x2(0.6h, -0.8h, 0.8h, 0.6h);
    half freq = 2.0h + (15.0h - 2.0h) * freqMix;
    half xp   = 1.4h;
    half time  = t * 0.4h;

    for (int i = 0; i < 4; i++) {
        half2 s = sin(freq * (pos * rot) + (half(i) * time + it));
        pos += amp * rot[0] * s / freq;
        rot  = rot * half2x2(0.6h, -0.8h, 0.8h, 0.6h);
        amp *= max(s.y, s.x);
        freq *= xp;
    }
    return pos;
}

half orbLuma(half3 color) {
    return dot(color, half3(0.299h, 0.587h, 0.114h));
}

uint2 orbPcg2d(uint2 v) {
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.y * 1664525u + 1013904223u;
    v.y += v.x * v.x * 1664525u + 1013904223u;
    v ^= v >> 16u;
    v.x += v.y * v.y * 1664525u + 1013904223u;
    v.y += v.x * v.x * 1664525u + 1013904223u;
    return v;
}

half orbDither(float2 p) {
    uint2 v = as_type<uint2>(p);
    v = orbPcg2d(v);
    uint r = v.x ^ v.y;
    return half(float(r) / float(0xffffffffu));
}

// MARK: - Turbulence pass (reusable for main + depth layer)

struct TurbResult {
    half3 pp;
    half3 bloom;
};

TurbResult orbTurbPass(half2 pos, half t, int iters, half freqMix, half turbAmp,
                       half circleSize, half smoothVal, half bloomInt,
                       half bloomClampVal, half palSweep, half bm,
                       half3 palA, half3 palB, half3 palC, half3 palD) {
    half fIter = half(iters);
    half3 pp    = half3(0.0h);
    half3 bloom = half3(0.0h);
    half spacing = TAU_H;

    half2 prevPos = orbTurb(pos, t, -1.0h / fIter, freqMix, turbAmp);

    for (int i = 1; i <= iters; i++) {
        half iter = half(i) / fIter;
        half2 st  = orbTurb(pos, t, iter * spacing, freqMix, turbAmp);

        half d  = abs(orbSdCircle(st, circleSize));
        half pd = distance(st, prevPos);
        prevPos = st;

        half dynamicBlur = exp2(pd * 2.0h * 1.442695h) - 1.0h;
        half ds = smoothstep(0.0h,
                             0.02h * bm + max(dynamicBlur * smoothVal, 0.001h),
                             d);

        half3 color = orbPal(iter * palSweep + 1.0h, palA, palB, palC, palD);

        half invd = 1.0h / max(d + dynamicBlur, 0.001h);
        pp    += (ds - 1.0h) * color;
        bloom += clamp(invd * bloomInt, 0.0h, bloomClampVal) * color;
    }

    pp   *= 1.0h / fIter;
    bloom = bloom / (bloom + 2e4h);

    TurbResult result;
    result.pp = pp;
    result.bloom = bloom;
    return result;
}

// MARK: - Fragment

fragment half4 ambientOrbFragment(VertexOut in [[stage_in]],
                                  constant float     &time       [[buffer(0)]],
                                  constant float2    &resolution [[buffer(1)]],
                                  constant float     &pressed    [[buffer(2)]],
                                  constant float3    &themeColor [[buffer(3)]],
                                  constant OrbParams &params     [[buffer(4)]]) {
    half2 uv = half2(in.texCoord);
    half  t  = half(time) * half(params.speed);

    // Audio reactivity: boost turbulence + bloom dynamically
    half audioBoost = 1.0h + half(params.audioLevel) * half(params.audioReactivity);

    // Parallax: offset UV origin based on gyro tilt
    half2 uPos = half2(0.5h + half(params.parallaxX) * half(params.parallaxAmount),
                        0.5h + half(params.parallaxY) * half(params.parallaxAmount));

    half2 aspect = half2(half(resolution.x) / half(resolution.y), 1.0h);
    half2 pos    = uv * aspect - uPos * aspect;

    half rotAngle = (half(params.rotationBase) + t * half(params.rotationSpeed)) * -2.0h * PI_H;
    half cosR = cos(rotAngle);
    half sinR = sin(rotAngle);
    half2x2 rotMatrix = half2x2(cosR, -sinR, sinR, cosR);
    pos = rotMatrix * pos;

    // Unpack palette vectors
    half3 palA = half3(half(params.palAR), half(params.palAG), half(params.palAB));
    half3 palB = half3(half(params.palBR), half(params.palBG), half(params.palBB));
    half3 palC = half3(half(params.palCR), half(params.palCG), half(params.palCB));
    half3 palD = half3(half(params.palDR), half(params.palDG), half(params.palDB));

    half freqMix  = half(params.freqMix);
    half turbAmp  = half(params.turbAmplitude) * audioBoost;
    half circSize = half(params.circleSize);
    half smoothV  = half(params.smoothing);
    half bloomInt = half(params.bloomIntensity) * audioBoost;
    half bloomCl  = half(params.bloomClamp);
    half palSweep = half(params.paletteSweep);
    half bm       = 0.05h;

    // Main turbulence pass
    TurbResult main = orbTurbPass(pos, t, ITERATIONS, freqMix, turbAmp,
                                   circSize, smoothV, bloomInt, bloomCl, palSweep, bm,
                                   palA, palB, palC, palD);

    half3 color = (-main.pp + main.bloom * half(params.bloomMix) * bloomInt);

    // Depth layer: second pass at different scale/speed, blended underneath
    if (params.depthLayerBlend > 0.001) {
        half depthT = half(time) * half(params.depthLayerSpeed) * half(params.speed);
        half2 depthPos = pos * half(params.depthLayerScale);
        int depthIters = max(ITERATIONS / 2, 6);

        TurbResult depth = orbTurbPass(depthPos, depthT, depthIters, freqMix, turbAmp * 0.6h,
                                        circSize * 1.5h, smoothV, bloomInt * 0.5h, bloomCl, palSweep, bm,
                                        palA, palB, palC, palD);

        half3 depthColor = (-depth.pp + depth.bloom * half(params.bloomMix) * bloomInt * 0.5h);
        color = mix(depthColor, color, 1.0h - half(params.depthLayerBlend));
    }

    color *= half(params.brightness);
    color += (orbDither(in.position.xy) - 0.5h) / 255.0h;
    color  = orbTonemap(color, half(params.tonemapGain));

    // Theme color tint
    half3 tint = half3(themeColor);

    // Secondary color blend
    if (params.secondaryBlend > 0.001) {
        half3 secondary = half3(half(params.secondaryR), half(params.secondaryG), half(params.secondaryB));
        tint = mix(tint, secondary, half(params.secondaryBlend));
    }

    color *= tint * half(params.colorTint);

    // Smooth press boost (interpolation handled Swift-side, `pressed` arrives pre-smoothed)
    half pressBoost = mix(1.0h, half(params.pressBoost), half(pressed));
    color *= pressBoost;

    // Circle mask
    half2 center = uv - 0.5h;
    half dist = length(center);
    half circleMask = 1.0h - smoothstep(half(params.maskInner), half(params.maskOuter), dist);

    half luminance = orbLuma(color);
    half alpha = circleMask * smoothstep(0.0h, 0.2h, luminance);

    return half4(color, alpha);
}
