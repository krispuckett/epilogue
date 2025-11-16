#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// MARK: - Thin Film Interference Helper
// Creates iridescent coating colors based on viewing angle
float3 thinFilmInterference(float cosTheta, float filmThickness) {
    // Optical path difference through thin film
    float opticalPath = 2.0 * filmThickness * cosTheta;

    // Calculate interference for RGB wavelengths (in nanometers)
    float r = 650.0; // Red wavelength
    float g = 550.0; // Green wavelength
    float b = 450.0; // Blue wavelength

    // Interference pattern - constructive/destructive based on phase
    float red = 0.5 + 0.5 * cos(opticalPath / r * 2.0 * M_PI_F);
    float green = 0.5 + 0.5 * cos(opticalPath / g * 2.0 * M_PI_F);
    float blue = 0.5 + 0.5 * cos(opticalPath / b * 2.0 * M_PI_F);

    return float3(red, green, blue);
}

// MARK: - Specular Position Lens
// Creates liquid glass effect with specular highlights and thin film coating
[[ stitchable ]] half4 specular_position_lens(
    float2 position,
    SwiftUI::Layer layer,
    float4 boundingRect,
    float2 dragp,
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

    // Light position from dragp (touch position)
    float2 lightPos2D = (dragp - lensCenter) / maxRadius * 2.0;
    float3 lightPos = float3(lightPos2D, 0.8);
    float3 lightDir = normalize(lightPos - surfacePos);

    // Calculate specular intensity using Blinn-Phong
    float3 halfVector = normalize(lightDir + viewDir);
    float specular = pow(max(dot(normal, halfVector), 0.0), 3.0);
    float totalSpecular = specular * intensity;

    // Use specular intensity to offset sample position
    // Direction is from light toward pixel (creates radial distortion from highlight)
    float2 specularDirection = normalize(position - dragp);
    float2 sampleOffset = specularDirection * totalSpecular * maxRadius;

    // Sample layer at offset position
    float2 samplePos = position + sampleOffset;
    half3 finalColor = layer.sample(samplePos).rgb;

    // Apply coating color using thin film interference
    float cosTheta = dot(viewDir, normal);
    float3 coatingColor = thinFilmInterference(cosTheta, 550.0);
    finalColor *= half3(coatingColor);

    return half4(finalColor, 1.0);
}
