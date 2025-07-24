#include <metal_stdlib>
using namespace metal;

// Smooth noise functions
float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    
    for(int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

vertex float4 ambientVertex(uint vid [[vertex_id]]) {
    const float2 positions[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(1, -1), float2(1, 1), float2(-1, 1)
    };
    return float4(positions[vid], 0, 1);
}

fragment float4 ambientFragment(float4 in [[position]],
                               constant float &time [[buffer(0)]],
                               constant float2 &resolution [[buffer(1)]]) {
    float2 uv = (in.xy - 0.5 * resolution) / resolution.y;
    float2 originalUV = uv;
    
    // Dark warm background
    float3 backgroundColor = float3(0.05, 0.04, 0.035);
    
    // Faster, more dynamic motion
    float flowTime = time * 0.35;
    
    // Create tightly contained orb-like distortion
    float dist = length(uv);
    float orbMask = exp(-dist * 3.5); // Much tighter orb containment
    float orbBoundary = smoothstep(0.6, 0.3, dist); // Hard boundary for orb shape
    
    // Create flowing silk-like distortion within the orb
    float2 flow = float2(
        fbm(uv * 2.5 + float2(flowTime * 1.0, 0.0)),
        fbm(uv * 2.5 + float2(0.0, flowTime * 0.8))
    ) * orbMask * orbBoundary;
    
    // Add secondary flow layer
    flow += float2(
        fbm(uv * 1.8 - float2(flowTime * 0.5, flowTime * 0.4)),
        fbm(uv * 1.8 + float2(flowTime * 0.4, -flowTime * 0.5))
    ) * 0.4 * orbMask * orbBoundary;
    
    // Apply flow distortion - very contained for tight orb
    uv += flow * 0.05;
    
    // Create silk bands using sine waves - focused on radial patterns
    float silk1 = sin(uv.x * 5.0 + uv.y * 4.0 + flowTime * 1.4) * 0.5 + 0.5;
    float silk2 = sin(uv.x * -4.0 + uv.y * 5.0 + flowTime * 1.2) * 0.5 + 0.5;
    float silk3 = sin(length(uv) * 10.0 - flowTime * 1.8) * 0.5 + 0.5;
    
    // Combine silk layers with tight orb containment
    float silkPattern = silk1 * silk2 + silk3 * 0.5;
    silkPattern = smoothstep(0.2, 0.8, silkPattern);
    silkPattern *= orbMask * orbBoundary; // Apply both masks for tight orb
    
    // Add fine detail
    float detail = fbm(uv * 12.0 + flowTime * 0.9) * 0.3;
    silkPattern += detail * silkPattern * orbBoundary;
    
    // Warm amber color palette
    float3 deepAmber = float3(0.25, 0.1, 0.05);
    float3 richAmber = float3(0.6, 0.25, 0.1);
    float3 brightAmber = float3(0.9, 0.45, 0.2);
    float3 goldenGlow = float3(1.0, 0.6, 0.3);
    
    // Create color gradients based on pattern
    float3 color = backgroundColor;
    
    // Base layer
    color = mix(color, deepAmber, smoothstep(0.0, 0.3, silkPattern));
    
    // Mid tones
    color = mix(color, richAmber, smoothstep(0.3, 0.6, silkPattern));
    
    // Bright areas
    color = mix(color, brightAmber, smoothstep(0.6, 0.8, silkPattern));
    
    // Highlights
    float highlights = pow(silkPattern, 3.0);
    color = mix(color, goldenGlow, highlights * 0.7);
    
    // Add color variation based on position
    float colorShift = fbm(originalUV * 2.0 + flowTime * 0.3);
    color *= 0.8 + colorShift * 0.4;
    
    // Strong radial glow from center for defined orb
    float centerGlow = exp(-length(originalUV) * 1.2);
    color += richAmber * centerGlow * 0.4;
    
    // Very strong orb-like vignette for tight containment
    float vignette = 1.0 - pow(length(originalUV), 1.2) * 1.2;
    vignette = max(vignette, 0.0);
    color *= vignette;
    
    // Apply hard orb boundary to final color
    color *= orbBoundary;
    
    // Faster, more noticeable brightness variation
    float brightness = 0.85 + sin(flowTime * 1.0) * 0.2;
    color *= brightness;
    
    return float4(color, 1.0);
}