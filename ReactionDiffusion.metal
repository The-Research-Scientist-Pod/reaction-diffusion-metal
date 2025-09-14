//
//  ReactionDiffusion.metal - CORRECTED VERSION
//  reaction-diffusion-metal
//

#include <metal_stdlib>
using namespace metal;

// Parameters structure - must match Swift ReactionDiffusionParameters
struct ReactionDiffusionParameters {
    float feedRate;
    float killRate;
    float diffusionA;
    float diffusionB;
    float deltaTime;
    float brushRadius;
    float2 brushPosition;
    float brushStrength;
    float time;
    int width;
    int height;
    float diffusionRadius;  // Changed padding to diffusionRadius
};

// Color scheme structure
struct RDColorScheme {
    float3 colorA;
    float3 colorB;
    float3 colorC;
    int mode;
    float intensity;
    float contrast;
};

// Correct diffusion calculation using weighted radial sampling
float2 calculateDiffusion(texture2d<float, access::read> tex, uint2 gid, int radius) {
    int width = tex.get_width();
    int height = tex.get_height();
    
    float2 currentValues = tex.read(gid).xy;
    float2 sum = float2(0.0);
    float weightSum = 0.0;
    
    // Sample in a circular radius with distance-based weighting
    for (int offsetY = -radius; offsetY <= radius; offsetY++) {
        for (int offsetX = -radius; offsetX <= radius; offsetX++) {
            if (offsetX == 0 && offsetY == 0) {
                continue;
            }
            
            // Calculate sample position with boundary clamping
            int2 samplePos = int2(gid) + int2(offsetX, offsetY);
            samplePos = clamp(samplePos, int2(0), int2(width - 1, height - 1));
            
            float sqrDst = float(offsetX * offsetX + offsetY * offsetY);
            
            // Only sample within circular radius
            if (sqrDst <= float(radius * radius)) {
                float weight = 1.0 / sqrt(sqrDst);
                sum += tex.read(uint2(samplePos)).xy * weight;
                weightSum += weight;
            }
        }
    }
    
    // Return diffusion strength (weighted average - current)
    if (weightSum > 0.0) {
        return (sum / weightSum) - currentValues;
    }
    return float2(0.0);
}

// Simple 9-point Laplacian for comparison (more stable than 5-point)
float2 laplacian9(texture2d<float, access::read> tex, uint2 gid) {
    int width = tex.get_width();
    int height = tex.get_height();
    
    // Clamp coordinates
    int x = gid.x;
    int y = gid.y;
    int xm = max(0, x - 1);
    int xp = min(width - 1, x + 1);
    int ym = max(0, y - 1);
    int yp = min(height - 1, y + 1);
    
    // 9-point stencil weights
    float2 sum = float2(0.0);
    
    // Center weight: -20/6
    sum += tex.read(gid).xy * (-20.0 / 6.0);
    
    // Direct neighbors weight: 4/6 each
    sum += tex.read(uint2(xm, y)).xy * (4.0 / 6.0);
    sum += tex.read(uint2(xp, y)).xy * (4.0 / 6.0);
    sum += tex.read(uint2(x, ym)).xy * (4.0 / 6.0);
    sum += tex.read(uint2(x, yp)).xy * (4.0 / 6.0);
    
    // Diagonal neighbors weight: 1/6 each
    sum += tex.read(uint2(xm, ym)).xy * (1.0 / 6.0);
    sum += tex.read(uint2(xp, ym)).xy * (1.0 / 6.0);
    sum += tex.read(uint2(xm, yp)).xy * (1.0 / 6.0);
    sum += tex.read(uint2(xp, yp)).xy * (1.0 / 6.0);
    
    return sum;
}

// Initialize reaction-diffusion system
kernel void initializeReactionDiffusion(
    texture2d<float, access::write> outTexture [[texture(0)]],
    constant ReactionDiffusionParameters& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (int(gid.x) >= params.width || int(gid.y) >= params.height) return;
    
    float width = float(params.width);
    float height = float(params.height);
    float2 center = float2(width * 0.5, height * 0.5);
    float2 pos = float2(gid);
    
    // Initialize with A=1, B=0 everywhere (equilibrium state)
    float a = 1.0;
    float b = 0.0;
    
    // Create multiple seed points for better initialization
    float minDim = min(width, height);
    
    // Central square
    float2 offset = abs(pos - center);
    float boxSize = minDim * 0.1;
    if (offset.x < boxSize && offset.y < boxSize) {
        a = 0.5;
        b = 0.25;
    }
    
    // Add some random seed points
    float noise = fract(sin(dot(pos, float2(12.9898, 78.233))) * 43758.5453);
    if (noise > 0.995) {
        a = 0.5;
        b = 0.25;
    }
    
    // Store only a and b (2 channels)
    outTexture.write(float4(a, b, 0.0, 1.0), gid);
}

// Main reaction-diffusion simulation step - CORRECTED
kernel void reactionDiffusionStep(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant ReactionDiffusionParameters& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (int(gid.x) >= params.width || int(gid.y) >= params.height) return;
    
    // Read current chemical concentrations
    float2 current = inTexture.read(gid).xy;
    float a = current.x;
    float b = current.y;
    
    // Calculate diffusion using weighted radial sampling (matching C# approach)
    int diffRadius = int(params.diffusionRadius);
    if (diffRadius < 2) diffRadius = 3;  // Default radius
    
    float2 diffusionStrength = calculateDiffusion(inTexture, gid, diffRadius);
    
    // Alternative: Use 9-point Laplacian (uncomment to test)
    // float2 lap = laplacian9(inTexture, gid);
    // float2 diffusionStrength = lap;
    
    // Gray-Scott reaction-diffusion equations
    float abb = a * b * b;
    
    // Calculate deltas (matching C# implementation)
    float deltaA = params.diffusionA * diffusionStrength.x - abb + params.feedRate * (1.0 - a);
    float deltaB = params.diffusionB * diffusionStrength.y + abb - (params.killRate + params.feedRate) * b;
    
    // Update concentrations
    float newA = a + deltaA * params.deltaTime;
    float newB = b + deltaB * params.deltaTime;
    
    // Apply brush if active
    float2 pos = float2(gid);
    float dist = length(pos - params.brushPosition);
    
    if (dist < params.brushRadius && params.brushStrength > 0.0) {
        float influence = exp(-dist * dist / (params.brushRadius * params.brushRadius * 0.5));
        newB = mix(newB, 1.0, influence * params.brushStrength);
    }
    
    // Clamp to valid range
    newA = clamp(newA, 0.0, 1.0);
    newB = clamp(newB, 0.0, 1.0);
    
    // Store a, b, deltaA, deltaB (for visualization modes)
    outTexture.write(float4(newA, newB, deltaA, deltaB), gid);
}

// Color mapping functions
float3 hsvToRgb(float3 hsv) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(hsv.xxx + K.xyz) * 6.0 - K.www);
    return hsv.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), hsv.y);
}

// Enhanced render function with multiple display modes
kernel void renderReactionDiffusion(
    texture2d<float, access::read> chemicalTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant ReactionDiffusionParameters& params [[buffer(0)]],
    constant RDColorScheme& colorScheme [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (int(gid.x) >= params.width || int(gid.y) >= params.height) return;
    
    // Read all values
    float4 data = chemicalTexture.read(gid);
    float a = data.x;
    float b = data.y;
    float deltaA = data.z;
    float deltaB = data.w;
    
    float3 color;
    
    // Different display modes (matching C# implementation)
    if (colorScheme.mode == 0) {
        // Grayscale based on B concentration
        color = float3(b);
    }
    else if (colorScheme.mode == 1) {
        // A - B difference
        float diff = clamp(a - b, 0.0, 1.0);
        color = mix(colorScheme.colorA, colorScheme.colorB, diff);
    }
    else if (colorScheme.mode == 2) {
        // Delta visualization (matching C# display mode 2)
        float deltaAThreshold = 0.0005;
        deltaA = max(0.0, deltaA - deltaAThreshold);
        
        color = float3(0.0, deltaB * 250.0, deltaA * 350.0);
        color.g = pow(color.g, 2.0) * 6.0;
        color = color.gbr + float3(0.0, 0.0, b);
        color = clamp(color, 0.0, 1.0);
    }
    else {
        // Default organic look
        float value = b;
        
        // Apply contrast
        value = clamp((value - 0.5) * colorScheme.contrast + 0.5, 0.0, 1.0);
        
        // Tri-color gradient
        if (value < 0.5) {
            color = mix(colorScheme.colorA, colorScheme.colorB, value * 2.0);
        } else {
            color = mix(colorScheme.colorB, colorScheme.colorC, (value - 0.5) * 2.0);
        }
        
        color *= colorScheme.intensity;
    }
    
    outputTexture.write(float4(color, 1.0), gid);
}

// MARK: - Vertex/Fragment shaders remain the same

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertex_main(uint vertexID [[vertex_id]],
                           constant float4* vertices [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(vertices[vertexID].xy, 0.0, 1.0);
    out.texCoord = vertices[vertexID].zw;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                            texture2d<float> simulationTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    return simulationTexture.sample(textureSampler, in.texCoord);
}
