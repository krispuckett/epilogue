#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

// Book cover lighting shader
fragment float4 bookCoverLighting(
    VertexOut in [[stage_in]],
    constant float &lightX [[buffer(0)]],
    constant float &lightY [[buffer(1)]],
    constant float &glossiness [[buffer(2)]],
    constant float &time [[buffer(3)]]
) {
    float2 uv = in.textureCoordinate;
    float2 lightPos = float2(lightX, 1.0 - lightY);
    
    // Distance from light position
    float dist = distance(uv, lightPos);
    
    // Create glossy highlight
    float highlight = 1.0 - smoothstep(0.0, 0.5, dist);
    highlight = pow(highlight, 2.0) * glossiness;
    
    // Add subtle animated shimmer
    float shimmer = sin(time * 2.0 + uv.x * 10.0) * 0.05 + 0.95;
    highlight *= shimmer;
    
    // Create edge lighting effect
    float edgeGlow = 0.0;
    float edgeDist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    if (edgeDist < 0.1) {
        edgeGlow = (0.1 - edgeDist) * 10.0 * glossiness * 0.3;
    }
    
    // Combine effects
    float intensity = highlight + edgeGlow;
    
    return float4(1.0, 1.0, 1.0, intensity);
}

// Environment reflection shader for book covers
fragment float4 bookCoverReflection(
    VertexOut in [[stage_in]],
    texture2d<float> coverTexture [[texture(0)]],
    constant float &tiltX [[buffer(0)]],
    constant float &tiltY [[buffer(1)]],
    sampler textureSampler [[sampler(0)]]
) {
    float2 uv = in.textureCoordinate;
    float4 baseColor = coverTexture.sample(textureSampler, uv);
    
    // Calculate pseudo-3D normal based on tilt
    float3 normal = normalize(float3(tiltX * 0.3, tiltY * 0.3, 1.0));
    float3 viewDir = float3(0, 0, -1);
    
    // Calculate Fresnel effect
    float fresnel = pow(1.0 - dot(normal, -viewDir), 2.0);
    
    // Create environment reflection gradient
    float2 reflectUV = uv + float2(tiltX, -tiltY) * 0.1;
    float reflectionIntensity = smoothstep(0.3, 0.7, reflectUV.y) * fresnel;
    
    // Add subtle color shift for realism
    float3 reflectionColor = float3(0.9, 0.95, 1.0);
    float3 finalColor = mix(baseColor.rgb, reflectionColor, reflectionIntensity * 0.2);
    
    return float4(finalColor, baseColor.a);
}

// Animated specular highlight shader
fragment float4 bookSpecularHighlight(
    VertexOut in [[stage_in]],
    constant float &time [[buffer(0)]],
    constant float &intensity [[buffer(1)]]
) {
    float2 uv = in.textureCoordinate;
    
    // Animated light sweep
    float sweep = fract(time * 0.1);
    float sweepPos = mix(-0.3, 1.3, sweep);
    
    // Create diagonal sweep line
    float diagonal = (uv.x + uv.y) * 0.5;
    float sweepIntensity = 1.0 - abs(diagonal - sweepPos) * 5.0;
    sweepIntensity = max(0.0, sweepIntensity);
    sweepIntensity = pow(sweepIntensity, 3.0);
    
    // Fade in and out at edges
    float edgeFade = smoothstep(0.0, 0.2, sweep) * smoothstep(1.0, 0.8, sweep);
    sweepIntensity *= edgeFade * intensity;
    
    return float4(1.0, 1.0, 1.0, sweepIntensity);
}