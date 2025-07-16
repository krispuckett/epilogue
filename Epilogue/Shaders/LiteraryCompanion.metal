#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

struct Particle {
    float2 position;
    float2 velocity;
    float life;
    float size;
    float heat;
    float turbulence;
};

// Fast pseudo-random function
float random(float seed) {
    return fract(sin(seed * 12.9898) * 43758.5453);
}

// 2D noise function for organic movement
float noise2D(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    
    float a = random(i.x + i.y * 57.0);
    float b = random(i.x + 1.0 + i.y * 57.0);
    float c = random(i.x + (i.y + 1.0) * 57.0);
    float d = random(i.x + 1.0 + (i.y + 1.0) * 57.0);
    
    float2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Advanced particle compute shader with fluid dynamics
kernel void updateParticles(device Particle* particles [[buffer(0)]],
                           constant float& time [[buffer(1)]],
                           uint id [[thread_position_in_grid]]) {
    if (id >= 5000) return;
    
    Particle p = particles[id];
    
    // Turbulent flow field using noise
    float2 flowField;
    float noiseScale = 3.0;
    float noiseSpeed = 0.5;
    flowField.x = noise2D(p.position * noiseScale + float2(time * noiseSpeed, 0)) - 0.5;
    flowField.y = noise2D(p.position * noiseScale + float2(0, time * noiseSpeed)) - 0.5;
    
    // Curl noise for organic movement
    float curlStrength = 0.5 * p.turbulence;
    float2 curl;
    curl.x = flowField.y * curlStrength;
    curl.y = -flowField.x * curlStrength;
    
    // Book metaphor: pages fluttering
    float pageFlutter = sin(time * 2.0 + p.position.x * 10.0) * 0.05;
    p.velocity += curl * 0.01 + float2(0, pageFlutter);
    
    // Gravity wells (like books pulling knowledge)
    float2 center1 = float2(0.3, 0.5);
    float2 center2 = float2(0.7, 0.5);
    float2 toCenter1 = center1 - p.position;
    float2 toCenter2 = center2 - p.position;
    float dist1 = length(toCenter1);
    float dist2 = length(toCenter2);
    
    // Attraction to gravity wells
    if (dist1 < 0.4) {
        float attraction = (0.4 - dist1) * 0.002;
        p.velocity += normalize(toCenter1) * attraction;
        p.heat = min(p.heat + 0.02, 1.0);
    }
    if (dist2 < 0.4) {
        float attraction = (0.4 - dist2) * 0.002;
        p.velocity += normalize(toCenter2) * attraction;
        p.heat = min(p.heat + 0.02, 1.0);
    }
    
    // Literary wind - gentle upward drift
    p.velocity.y += 0.0001;
    
    // Damping and constraints
    p.velocity *= 0.98;
    p.position += p.velocity;
    
    // Wrap around edges with smooth transition
    if (p.position.x < -0.1) p.position.x = 1.1;
    if (p.position.x > 1.1) p.position.x = -0.1;
    if (p.position.y < -0.1) {
        p.position.y = 1.1;
        p.heat = 0.0;
    }
    if (p.position.y > 1.1) {
        p.position.y = -0.1;
        p.velocity.y = 0.001; // Reset upward velocity
    }
    
    // Life and heat dissipation
    p.life -= 0.001;
    p.heat *= 0.99;
    
    if (p.life <= 0) {
        // Respawn particle
        p.life = 1.0;
        p.position = float2(random(float(id) + time), -0.1);
        p.velocity = float2(random(float(id) * 2.0 + time) * 0.002 - 0.001, 0.001);
        p.heat = 0.0;
        p.size = random(float(id) * 3.0 + time) * 0.5 + 0.5;
    }
    
    particles[id] = p;
}

// Vertex shader output structure
struct VertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float heat;
    float life;
};

// Advanced vertex shader with size variation
vertex VertexOut particleVertex(const device Particle* particles [[buffer(0)]],
                               constant float& time [[buffer(1)]],
                               constant float2& viewportSize [[buffer(2)]],
                               uint vid [[vertex_id]]) {
    Particle p = particles[vid];
    
    VertexOut out;
    out.position = float4(p.position * 2.0 - 1.0, 0.0, 1.0);
    out.position.y = -out.position.y; // Flip Y for Metal coordinate system
    
    // Dynamic point size based on heat and life
    float baseSize = 3.0 * p.size;
    float heatSize = p.heat * 15.0;
    float lifeSize = p.life * 2.0;
    float pulseSize = sin(time * 3.0 + float(vid) * 0.1) * 0.5 + 1.0;
    
    out.pointSize = (baseSize + heatSize + lifeSize) * pulseSize;
    out.heat = p.heat;
    out.life = p.life;
    
    return out;
}

// Advanced fragment shader with dynamic coloring
fragment float4 particleFragment(VertexOut in [[stage_in]],
                               float2 pointCoord [[point_coord]]) {
    float dist = length(pointCoord - 0.5);
    if (dist > 0.5) discard_fragment();
    
    // Soft particle edges
    float alpha = 1.0 - smoothstep(0.0, 0.5, dist);
    alpha *= alpha; // Quadratic falloff
    
    // Literary warm colors
    float3 warmAmber = float3(1.0, 0.55, 0.26);
    float3 deepGold = float3(0.9, 0.45, 0.1);
    float3 parchment = float3(0.95, 0.9, 0.7);
    float3 inkBlue = float3(0.1, 0.2, 0.4);
    
    // Mix colors based on particle properties
    float3 color = mix(warmAmber, deepGold, in.heat);
    color = mix(color, parchment, dist * 0.3);
    
    // Add ink hints at the core
    if (dist < 0.2) {
        color = mix(color, inkBlue, (0.2 - dist) * 2.0 * (1.0 - in.heat));
    }
    
    // Glow effect
    float glow = exp(-dist * 4.0);
    color += warmAmber * glow * 0.5 * in.heat;
    
    // Life-based opacity
    alpha *= in.life;
    
    return float4(color, alpha * 0.7);
}

// Fluid simulation kernel for background effects
kernel void simulateFluid(texture2d<float, access::read> velocityIn [[texture(0)]],
                         texture2d<float, access::write> velocityOut [[texture(1)]],
                         texture2d<float, access::read> densityIn [[texture(2)]],
                         texture2d<float, access::write> densityOut [[texture(3)]],
                         constant float& time [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= velocityIn.get_width() || gid.y >= velocityIn.get_height()) return;
    
    // Simple advection for demonstration
    float4 velocity = velocityIn.read(gid);
    float4 density = densityIn.read(gid);
    
    // Add some swirl
    float2 center = float2(velocityIn.get_width(), velocityIn.get_height()) * 0.5;
    float2 toCenter = float2(gid) - center;
    float angle = atan2(toCenter.y, toCenter.x);
    float dist = length(toCenter) / length(center);
    
    velocity.xy += float2(cos(angle + time * 0.1), sin(angle + time * 0.1)) * 0.001 * (1.0 - dist);
    velocity.xy *= 0.99; // Damping
    
    velocityOut.write(velocity, gid);
    densityOut.write(density * 0.99, gid); // Fade density
}