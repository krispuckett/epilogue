#include <metal_stdlib>
using namespace metal;

// MARK: - Dynamic Water Ripple Effect
// Creates realistic water ripples with multiple waves, distortion, and spring physics

[[ stitchable ]] half4 waterRipple(
    float2 position,
    half4 color,
    float progress,      // 0.0 to 1.0 - expansion progress
    float ringRadius     // Current ring radius in normalized coords
) {
    // Calculate distance from center
    float2 center = float2(0.5, 0.5);
    float2 delta = position - center;
    float distance = length(delta);
    float angle = atan2(delta.y, delta.x);

    // Normalize ring radius (convert to 0-1 range based on view bounds)
    float normalizedRing = ringRadius / 200.0; // Assuming ~200pt max radius

    // Calculate if this pixel is on the ring (with some thickness)
    float ringThickness = 0.08;
    float distFromRing = abs(distance - normalizedRing);

    // Base ring visibility
    float ringAlpha = smoothstep(ringThickness, 0.0, distFromRing);

    // Create multiple water waves traveling along the ring
    // Wave 1: Primary wave (fast, high frequency)
    float wave1Freq = 25.0;
    float wave1 = sin(angle * wave1Freq - progress * 40.0) * 0.15;

    // Wave 2: Secondary wave (medium speed)
    float wave2Freq = 15.0;
    float wave2 = sin(angle * wave2Freq + progress * 30.0) * 0.1;

    // Wave 3: Tertiary wave (slow, low frequency)
    float wave3Freq = 8.0;
    float wave3 = cos(angle * wave3Freq - progress * 20.0) * 0.08;

    // Combine waves for complex water motion
    float combinedWave = wave1 + wave2 + wave3;

    // Apply wave distortion to ring edge
    float waveEffect = combinedWave * (1.0 - progress); // Waves dampen as ripple expands

    // Modify the ring distance check with wave distortion
    float distortedDistFromRing = abs(distance - (normalizedRing + waveEffect));
    ringAlpha = smoothstep(ringThickness * (1.0 + abs(waveEffect) * 2.0), 0.0, distortedDistFromRing);

    // Add radial wave pattern (creates concentric sub-ripples)
    float radialWave = sin((distance - normalizedRing) * 40.0 + progress * 30.0) * 0.5 + 0.5;
    radialWave *= smoothstep(ringThickness * 2.0, 0.0, distFromRing); // Only near ring

    // Spring physics - rings "bounce" as they expand
    float springBounce = sin(progress * 3.14159 * 4.0) * exp(-progress * 3.0) * 0.2;
    ringAlpha *= (1.0 + springBounce);

    // Add bubble/splash effect at very start
    if (progress < 0.2) {
        float bubbleEffect = exp(-distance * 8.0) * (1.0 - progress * 5.0);
        ringAlpha += bubbleEffect * 0.3;
    }

    // Combine all effects
    float finalAlpha = color.a * ringAlpha * (1.0 + radialWave * 0.3);
    finalAlpha = clamp(finalAlpha, 0.0f, float(color.a));

    // Brighten the ring where waves peak (creates shimmering effect)
    float shimmer = 1.0 + abs(combinedWave) * 0.4;
    half3 finalColor = color.rgb * half(shimmer);

    return half4(finalColor, half(finalAlpha));
}
