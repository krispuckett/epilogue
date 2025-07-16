#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

// Vertex output structure
struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// Vertex shader for full-screen quad
vertex VertexOut ambientVertex(uint vid [[vertex_id]]) {
    float2 positions[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(1, -1), float2(1, 1), float2(-1, 1)
    };
    
    VertexOut out;
    out.position = float4(positions[vid], 0, 1);
    // Convert from clip space (-1,1) to UV space (0,1)
    out.uv = positions[vid] * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y; // Flip Y for Metal coordinate system
    
    return out;
}

// Calm, focused fragment shader - cosmic orb meets fireplace
fragment float4 ambientFragment(VertexOut in [[stage_in]],
                               constant float& time [[buffer(0)]]) {
    float2 uv = in.uv;
    
    // DEBUG: Simple gradient to verify shader is working
    // return float4(uv.x, uv.y, 0.5, 1.0);
    
    // Center of our calm orb
    float2 center = float2(0.5, 0.45);
    float dist = length(uv - center);
    
    // Create a multi-layered orb
    float orb = 1.0 - smoothstep(0.0, 0.25, dist);
    float glow = 1.0 - smoothstep(0.0, 0.4, dist);
    float outerGlow = 1.0 - smoothstep(0.2, 0.6, dist);
    
    // Gentle breathing animation
    float breathe = sin(time * 1.5) * 0.05 + 0.95;
    orb *= breathe;
    
    // Color palette - warm literary amber
    float3 coreColor = float3(1.0, 0.9, 0.7);      // Almost white core
    float3 innerColor = float3(1.0, 0.6, 0.3);     // Warm amber
    float3 outerColor = float3(0.8, 0.3, 0.1);     // Deep orange
    float3 backgroundColor = float3(0.08, 0.07, 0.07); // Dark background
    
    // Create the orb with multiple layers
    float3 color = backgroundColor;
    color = mix(color, outerColor, outerGlow * 0.3);
    color = mix(color, innerColor, glow * 0.6);
    color = mix(color, coreColor, orb * 0.9);
    
    // Add subtle vignette
    float vignette = 1.0 - length(uv - 0.5) * 0.8;
    color *= vignette;
    
    return float4(color, 1.0);
}

// Alternative: Abstract fireplace shader
fragment float4 fireplaceFragment(VertexOut in [[stage_in]],
                                 constant float& time [[buffer(0)]]) {
    float2 uv = in.uv;
    
    // Focus on bottom center - like a fireplace
    float2 flameOrigin = float2(0.5, 0.1);
    float2 toFlame = uv - flameOrigin;
    
    float flameShape = 0.0;
    
    // Create layered flame shapes
    for(int i = 0; i < 5; i++) {
        float scale = 1.0 + float(i) * 0.3;
        float speed = 0.5 + float(i) * 0.2;
        
        // Vertical movement and flicker
        float2 offset = float2(
            sin(time * speed * 1.3) * 0.02,
            time * speed * 0.1
        );
        
        float2 flameUV = (toFlame + offset) * scale;
        
        // Teardrop flame shape
        float flame = 1.0 - length(flameUV * float2(1.0, 0.5));
        flame *= 1.0 - smoothstep(0.0, 0.5, flameUV.y);
        flame = smoothstep(0.0, 0.3, flame);
        
        flameShape += flame * (1.0 / 5.0);
    }
    
    // Warm fireplace colors
    float3 emberColor = float3(1.0, 0.3, 0.05);
    float3 flameColor = float3(1.0, 0.6, 0.2);
    float3 hotColor = float3(1.0, 0.95, 0.8);
    
    float3 color = mix(emberColor, flameColor, flameShape);
    color = mix(color, hotColor, pow(flameShape, 3.0));
    
    // Soft glow around flames
    float glow = exp(-length(toFlame) * 2.0) * 0.5;
    color += flameColor * glow;
    
    // Dark, cozy background
    float3 backgroundColor = float3(0.06, 0.05, 0.05);
    float3 finalColor = mix(backgroundColor, color, flameShape + glow * 0.3);
    
    return float4(finalColor, 1.0);
}