#include <metal_stdlib>
using namespace metal;

struct StellarAuroraVertexUniforms {
    float4x4 modelViewMatrix;
    float4x4 projectionMatrix;
    float4x4 textureMatrix;
};

struct StellarAuroraFragmentUniforms {
    float2 position;      // corresponds to uPos
    float  time;          // corresponds to uTime
    float  pressed;       // corresponds to tap press state
    float2 mousePosition; // corresponds to uMousePos
    float2 resolution;    // corresponds to uResolution
    float3 themeColor;    // tinting color
    float  intensity;     // brightness scaling
    float  speed;         // animation rate multiplier
    float  padding;       // explicit alignment padding
};

struct StellarAuroraVertexIn {
    float3 position [[attribute(0)]];
    float2 texcoord [[attribute(1)]];
};

struct StellarAuroraVertexOut {
    float4 clipPosition [[position]];
    float2 texcoord;
};

//------------------------------------------------------------------------------
// Utility helpers
//------------------------------------------------------------------------------
inline float3 blendAdd(float3 src, float3 dst) {
    return src + dst;
}

inline uint2 pcg2d(uint2 v) {
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.y * 1664525u + 1013904223u;
    v.y += v.x * v.x * 1664525u + 1013904223u;
    v ^= (v >> 16);
    v.x += v.y * v.y * 1664525u + 1013904223u;
    v.y += v.x * v.x * 1664525u + 1013904223u;
    return v;
}

inline float randFibo(float2 p) {
    uint2 v = as_type<uint2>(p);
    v = pcg2d(v);
    uint r = v.x ^ v.y;
    return float(r) / float(0xffffffffu);
}

inline float3 palette(float t, float3 a, float3 b, float3 c, float3 d) {
    constexpr float tau = 6.28318530718f;
    return a + b * cos(tau * (c * t + d));
}

inline float3 tonemapReinhard(float3 x) {
    x *= 4.0f;
    return x / (1.0f + x);
}

inline float sdCircle(float2 st, float r) {
    return length(st) - r;
}

inline float getSdf(float2 st, float iter, float md) {
    (void)iter;
    (void)md;
    return sdCircle(st, 0.05f);
}

float2 turb(float2 pos, float t, float iteration, float md, float2 mousePos) {
    (void)md; // retained for parity with original shader, currently unused
    float2x2 rot = float2x2(0.6f, -0.8f,
                            0.8f,  0.6f);

    float freq = 2.0f + (15.0f - 2.0f) * 0.45f;
    float amp = 0.27f * md;
    const float xp = 1.4f;
    float time = t * 0.1f + 0.04f;

    for (float i = 0.0f; i < 4.0f; i += 1.0f) {
        float2 offset = pos - mousePos;
        float2 rotated = float2(dot(offset, rot[0]), dot(offset, rot[1]));
        float2 s = sin(freq * rotated + (i * time + iteration));

        pos += (amp / freq) * rot[0] * s;

        float mixFactor = max(s.y, s.x);
        amp *= mixFactor;

        rot = rot * float2x2(0.6f, -0.8f,
                             0.8f,  0.6f);
        freq *= xp;
    }

    return pos;
}

inline float luma(float3 color) {
    return dot(color, float3(0.299f, 0.587f, 0.114f));
}

//------------------------------------------------------------------------------
// Vertex stage
//------------------------------------------------------------------------------
vertex StellarAuroraVertexOut stellarAuroraVertex(
    StellarAuroraVertexIn in                 [[stage_in]],
    constant StellarAuroraVertexUniforms &u  [[buffer(2)]]) {

    float4 world = u.modelViewMatrix * float4(in.position, 1.0f);

    StellarAuroraVertexOut out;
    out.clipPosition = u.projectionMatrix * world;

    float4 tex = u.textureMatrix * float4(in.texcoord, 0.0f, 1.0f);
    out.texcoord = tex.xy;
    return out;
}

//------------------------------------------------------------------------------
// Fragment stage
//------------------------------------------------------------------------------
fragment float4 stellarAuroraFragment(
    StellarAuroraVertexOut in                             [[stage_in]],
    constant StellarAuroraFragmentUniforms &u             [[buffer(0)]],
    texture2d<float> backgroundTexture                    [[texture(0)]],
    texture2d<float> customTexture                        [[texture(1)]],
    sampler backgroundSampler                             [[sampler(0)]],
    sampler customSampler                                 [[sampler(1)]]) {
    (void)customTexture;
    (void)customSampler;

    constexpr float pi = 3.14159265359f;
    constexpr int iterations = 36;

    float2 uv = in.texcoord;
    float4 bg = backgroundTexture.sample(backgroundSampler, uv);

    float3 pp = float3(0.0f);
    float3 bloom = float3(0.0f);
    float speed = max(u.speed, 0.0f);
    float t = u.time * (0.5f * speed) + 0.04f;
    float2 aspect = float2(u.resolution.x / max(u.resolution.y, 1e-4f), 1.0f);
    float2 mousePos = float2(0.0f);

    float2 pos = uv * aspect - u.position * aspect;
    float mDist = length(uv * aspect - u.mousePosition * aspect);
    float md = 1.0f;

    float rotation = 0.3105f * -2.0f * pi;
    float c = cos(rotation);
    float s = sin(rotation);
    float2x2 rotMatrix = float2x2(c, -s,
                                  s,  c);
    pos = rotMatrix * pos;

    float bm = 0.05f;
    float2 prevPos = turb(pos, t, -1.0f / float(iterations), md, mousePos);
    float spacing = 6.28318530718f;
    float smoothing = 0.0f;

    for (int i = 1; i <= iterations; ++i) {
        float iter = float(i) / float(iterations);
        float2 st = turb(pos, t, iter * spacing, md, mousePos);
        float d = fabs(getSdf(st, iter, md));
        float pd = distance(st, prevPos);
        prevPos = st;

        float dynamicBlur = exp2(pd * 2.0f * 1.4426950408889634f) - 1.0f;
        float ds = smoothstep(0.0f, bm + max(dynamicBlur * smoothing, 0.001f), d);

        float3 color = palette(iter * 0.28f + 0.95f,
                               float3(0.5f),
                               float3(0.5f),
                               float3(1.0f),
                               float3(0.0f, 0.243137255f, 0.23137255f));

        float invd = 1.0f / max(d + dynamicBlur, 0.001f);
        pp += (ds - 1.0f) * color;
        bloom += clamp(invd, 0.0f, 250.0f) * color;
    }

    pp *= 1.0f / float(iterations);
    bloom = bloom / (bloom + 20000.0f);

    float3 color = (-pp + bloom * 3.0f * 0.69f);
    color *= 1.2f;
    color += (randFibo(in.clipPosition.xy) - 0.5f) / 255.0f;
    color = tonemapReinhard(color);

    float3 auroraColor = color;

    float3 themeTint = clamp(u.themeColor, float3(0.0f), float3(1.0f));
    float3 tintedColor = auroraColor * (themeTint * 0.75f + float3(0.25f));
    auroraColor = mix(auroraColor, tintedColor, 0.6f);

    float intensity = clamp(u.intensity, 0.0f, 3.0f);
    auroraColor *= intensity;

    float pressBoost = mix(1.0f, 1.3f, clamp(u.pressed, 0.0f, 1.0f));
    auroraColor *= pressBoost;

    auroraColor = blendAdd(auroraColor, bg.rgb);

    float alpha = max(bg.a, luma(auroraColor));
    return float4(auroraColor, alpha);
}
