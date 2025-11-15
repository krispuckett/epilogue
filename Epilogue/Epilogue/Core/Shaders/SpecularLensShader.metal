#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// MARK: - Thin Film Interference Helper
// Creates iridescent coating effect based on viewing angle
float3 thinFilmInterference(float cosTheta, float thickness) {
    // Simplified thin film interference calculation
    // Creates rainbow-like color shifts based on viewing angle
    float phase = thickness * cosTheta * 10.0;

    float r = 0.5 + 0.5 * cos(phase);
    float g = 0.5 + 0.5 * cos(phase + 2.094); // 120 degrees
    float b = 0.5 + 0.5 * cos(phase + 4.189); // 240 degrees

    return float3(r, g, b);
}

// MARK: - Specular Position Lens Shader
// Creates a glass-like lens effect with specular highlights that follow a position
[[ stitchable ]] half4 specular_position_lens(
    float2 position,
    SwiftUI::Layer layer,
    float4 boundingRect,
    float2 dragPosition,
    float intensity
) {
    float2 size = boundingRect.zw;
    float2 lensCenter = size * 0.5;
    float2 centered = position - lensCenter;
    float maxRadius = min(size.x, size.y) * 0.3;
    float radius = length(centered) / maxRadius;
    float2 normalizedPos = centered / maxRadius;

    // Calculate curved glass surface normal
    float curvature = 1.0 - radius;
    curvature = pow(curvature, 1.2);
    float3 surfacePos = float3(normalizedPos, -curvature * 0.3);
    float3 normal = normalize(float3(normalizedPos * (1.0 - curvature), curvature));
    float3 viewDir = normalize(float3(0, 0, 1) - surfacePos);

    // Light position from dragPosition
    float2 lightPos2D = (dragPosition - lensCenter) / maxRadius * 2.0;
    float3 lightPos = float3(lightPos2D, 0.8);
    float3 lightDir = normalize(lightPos - surfacePos);

    // Calculate specular intensity
    float3 halfVector = normalize(lightDir + viewDir);
    float specular = pow(max(dot(normal, halfVector), 0.0), 3.0);
    float totalSpecular = specular * intensity;

    // Use specular intensity to offset sample position
    // Direction is from light toward pixel (creates radial distortion from highlight)
    float2 specularDirection = normalize(position - dragPosition);
    float2 sampleOffset = specularDirection * totalSpecular * maxRadius;

    // Sample layer at offset position
    float2 samplePos = position + sampleOffset;
    half3 finalColor = layer.sample(samplePos).rgb;

    // Apply coating color
    float cosTheta = dot(viewDir, normal);
    float3 coatingColor = thinFilmInterference(cosTheta, 550.0);
    finalColor *= half3(coatingColor);

    return half4(finalColor, 1.0);
}
