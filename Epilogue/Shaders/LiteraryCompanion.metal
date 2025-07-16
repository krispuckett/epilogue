#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

// Vertex shader for full-screen quad
vertex float4 ambientVertex(uint vid [[vertex_id]]) {
    float2 positions[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(1, -1), float2(1, 1), float2(-1, 1)
    };
    return float4(positions[vid], 0, 1);
}

// Calm, focused fragment shader - cosmic orb meets fireplace
fragment float4 ambientFragment(float4 position [[position]],
                               constant float& time [[buffer(0)]]) {
    float2 uv = position.xy / float2(position.w);
    uv = uv * 0.5 + 0.5; // Convert to 0-1 range
    
    // Center of our calm orb
    float2 center = float2(0.5, 0.4);
    float dist = length(uv - center);
    
    // Base orb with soft edges
    float orb = 1.0 - smoothstep(0.0, 0.3, dist);
    orb = pow(orb, 1.5); // Softer falloff
    
    // Gentle breathing pulse
    float breathe = sin(time * 0.3) * 0.1 + 0.9;
    orb *= breathe;
    
    // Subtle inner movement - like flames or plasma
    float innerGlow = 0.0;
    for(int i = 0; i < 3; i++) {
        float speed = 0.2 + float(i) * 0.1;
        float offset = float(i) * 2.094; // Golden angle
        
        float2 polarUV = uv - center;
        float angle = atan2(polarUV.y, polarUV.x);
        float radius = length(polarUV);
        
        // Gentle wavering motion
        float wave = sin(angle * 3.0 + time * speed + offset) * 0.02;
        float glow = 1.0 - smoothstep(0.0, 0.2 + wave, radius);
        glow *= sin(time * speed * 0.7 + offset) * 0.3 + 0.7;
        
        innerGlow += glow * (1.0 / 3.0);
    }
    
    // Color palette - warm literary amber
    float3 innerColor = float3(1.0, 0.55, 0.26); // Warm amber
    float3 outerColor = float3(0.9, 0.35, 0.1);  // Deep orange
    float3 coreColor = float3(1.0, 0.9, 0.7);    // Almost white
    
    // Mix colors based on distance and glow
    float3 color = mix(outerColor, innerColor, orb);
    color = mix(color, coreColor, innerGlow * orb * 0.5);
    
    // Very subtle noise for organic feel
    float noise = fract(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
    color += noise * 0.02 * orb;
    
    // Final composition with dark background
    float3 backgroundColor = float3(0.08, 0.07, 0.07);
    float alpha = orb * 0.8 + innerGlow * orb * 0.2;
    
    float3 finalColor = mix(backgroundColor, color, alpha);
    
    // Subtle vignette
    float vignette = 1.0 - length(uv - 0.5) * 0.7;
    finalColor *= vignette;
    
    return float4(finalColor, 1.0);
}

// Alternative: Abstract fireplace shader
fragment float4 fireplaceFragment(float4 position [[position]],
                                 constant float& time [[buffer(0)]]) {
    float2 uv = position.xy / float2(position.w);
    uv = uv * 0.5 + 0.5;
    
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