//
//  ReactionDiffusion.metal - Enhanced with 3D Lighting
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
    float diffusionRadius;
};

// Enhanced color scheme structure with lighting parameters
struct RDColorScheme {
    float3 colorA;
    float3 colorB;
    float3 colorC;
    int mode;
    float intensity;
    float contrast;
    // New lighting parameters
    float3 lightPosition;
    float3 viewPosition;
    float heightScale;
    float shininess;
    float ambientStrength;
    float diffuseStrength;
    float specularStrength;
};

// Correct diffusion calculation using weighted radial sampling
float2 calculateDiffusion(texture2d<float, access::read> tex, uint2 gid, int radius) {
    int width = tex.get_width();
    int height = tex.get_height();
    
    float2 currentValues = tex.read(gid).xy;
    float2 sum = float2(0.0);
    float weightSum = 0.0;
    
    for (int offsetY = -radius; offsetY <= radius; offsetY++) {
        for (int offsetX = -radius; offsetX <= radius; offsetX++) {
            if (offsetX == 0 && offsetY == 0) {
                continue;
            }
            
            int2 samplePos = int2(gid) + int2(offsetX, offsetY);
            samplePos = clamp(samplePos, int2(0), int2(width - 1, height - 1));
            
            float sqrDst = float(offsetX * offsetX + offsetY * offsetY);
            
            if (sqrDst <= float(radius * radius)) {
                float weight = 1.0 / sqrt(sqrDst);
                sum += tex.read(uint2(samplePos)).xy * weight;
                weightSum += weight;
            }
        }
    }
    
    if (weightSum > 0.0) {
        return (sum / weightSum) - currentValues;
    }
    return float2(0.0);
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
    
    float a = 1.0;
    float b = 0.0;
    
    float minDim = min(width, height);
    
    float2 offset = abs(pos - center);
    float boxSize = minDim * 0.1;
    if (offset.x < boxSize && offset.y < boxSize) {
        a = 0.5;
        b = 0.25;
    }
    
    float noise = fract(sin(dot(pos, float2(12.9898, 78.233))) * 43758.5453);
    if (noise > 0.995) {
        a = 0.5;
        b = 0.25;
    }
    
    outTexture.write(float4(a, b, 0.0, 1.0), gid);
}

// Main reaction-diffusion simulation step
kernel void reactionDiffusionStep(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant ReactionDiffusionParameters& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (int(gid.x) >= params.width || int(gid.y) >= params.height) return;
    
    float2 current = inTexture.read(gid).xy;
    float a = current.x;
    float b = current.y;
    
    int diffRadius = int(params.diffusionRadius);
    if (diffRadius < 2) diffRadius = 3;
    
    float2 diffusionStrength = calculateDiffusion(inTexture, gid, diffRadius);
    
    float abb = a * b * b;
    
    float deltaA = params.diffusionA * diffusionStrength.x - abb + params.feedRate * (1.0 - a);
    float deltaB = params.diffusionB * diffusionStrength.y + abb - (params.killRate + params.feedRate) * b;
    
    float newA = a + deltaA * params.deltaTime;
    float newB = b + deltaB * params.deltaTime;
    
    float2 pos = float2(gid);
    float dist = length(pos - params.brushPosition);
    
    if (dist < params.brushRadius && params.brushStrength > 0.0) {
        float influence = exp(-dist * dist / (params.brushRadius * params.brushRadius * 0.5));
        newB = mix(newB, 1.0, influence * params.brushStrength);
    }
    
    newA = clamp(newA, 0.0, 1.0);
    newB = clamp(newB, 0.0, 1.0);
    
    outTexture.write(float4(newA, newB, deltaA, deltaB), gid);
}

// Calculate normal from height map using Sobel operator
float3 calculateNormal(texture2d<float, access::read> tex, uint2 gid, float heightScale) {
    int width = tex.get_width();
    int height = tex.get_height();
    
    // Sample neighboring pixels for Sobel operator
    float tl = tex.read(clamp(gid + uint2(-1, -1), uint2(0), uint2(width-1, height-1))).y;
    float tm = tex.read(clamp(gid + uint2( 0, -1), uint2(0), uint2(width-1, height-1))).y;
    float tr = tex.read(clamp(gid + uint2( 1, -1), uint2(0), uint2(width-1, height-1))).y;
    float ml = tex.read(clamp(gid + uint2(-1,  0), uint2(0), uint2(width-1, height-1))).y;
    float mr = tex.read(clamp(gid + uint2( 1,  0), uint2(0), uint2(width-1, height-1))).y;
    float bl = tex.read(clamp(gid + uint2(-1,  1), uint2(0), uint2(width-1, height-1))).y;
    float bm = tex.read(clamp(gid + uint2( 0,  1), uint2(0), uint2(width-1, height-1))).y;
    float br = tex.read(clamp(gid + uint2( 1,  1), uint2(0), uint2(width-1, height-1))).y;
    
    // Sobel X: [-1 0 1; -2 0 2; -1 0 1]
    float sobelX = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
    
    // Sobel Y: [-1 -2 -1; 0 0 0; 1 2 1]
    float sobelY = (bl + 2.0 * bm + br) - (tl + 2.0 * tm + tr);
    
    // Construct normal
    float3 normal = normalize(float3(-sobelX * heightScale, -sobelY * heightScale, 1.0));
    
    return normal;
}

// Calculate ambient occlusion approximation
float calculateAO(texture2d<float, access::read> tex, uint2 gid, int samples) {
    float center = tex.read(gid).y;
    float ao = 0.0;
    
    for (int i = 1; i <= samples; i++) {
        float radius = float(i);
        float sampleCount = 0.0;
        float occluded = 0.0;
        
        // Sample in a circle
        for (int j = 0; j < 8; j++) {
            float angle = float(j) * 3.14159 * 0.25;
            int2 offset = int2(cos(angle) * radius, sin(angle) * radius);
            int2 samplePos = clamp(int2(gid) + offset, int2(0), int2(tex.get_width()-1, tex.get_height()-1));
            
            float sample = tex.read(uint2(samplePos)).y;
            if (sample > center) {
                occluded += 1.0;
            }
            sampleCount += 1.0;
        }
        
        ao += (1.0 - occluded / sampleCount) / float(samples);
    }
    
    return ao;
}

// Enhanced render function with 3D lighting
kernel void renderReactionDiffusion(
    texture2d<float, access::read> chemicalTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant ReactionDiffusionParameters& params [[buffer(0)]],
    constant RDColorScheme& colorScheme [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (int(gid.x) >= params.width || int(gid.y) >= params.height) return;
    
    float4 data = chemicalTexture.read(gid);
    float a = data.x;
    float b = data.y;
    
    // Calculate base color
    float3 baseColor;
    
    if (colorScheme.mode == 0) {
        baseColor = float3(b);
    }
    else if (colorScheme.mode == 1) {
        float diff = clamp(a - b, 0.0, 1.0);
        baseColor = mix(colorScheme.colorA, colorScheme.colorB, diff);
    }
    else if (colorScheme.mode == 2) {
        float deltaA = data.z;
        float deltaB = data.w;
        float deltaAThreshold = 0.0005;
        deltaA = max(0.0, deltaA - deltaAThreshold);
        
        baseColor = float3(0.0, deltaB * 250.0, deltaA * 350.0);
        baseColor.g = pow(baseColor.g, 2.0) * 6.0;
        baseColor = baseColor.gbr + float3(0.0, 0.0, b);
        baseColor = clamp(baseColor, 0.0, 1.0);
    }
    else {
        // Default organic look with tri-color gradient
        float value = b;
        value = clamp((value - 0.5) * colorScheme.contrast + 0.5, 0.0, 1.0);
        
        if (value < 0.5) {
            baseColor = mix(colorScheme.colorA, colorScheme.colorB, value * 2.0);
        } else {
            baseColor = mix(colorScheme.colorB, colorScheme.colorC, (value - 0.5) * 2.0);
        }
        
        baseColor *= colorScheme.intensity;
    }
    
    // Apply 3D lighting effect
    // Use B concentration as height map
    float heightValue = b;
    
    // Calculate normal from height map
    float3 normal = calculateNormal(chemicalTexture, gid, colorScheme.heightScale);
    
    // Calculate lighting vectors
    float3 fragPos = float3(float(gid.x) / float(params.width),
                           float(gid.y) / float(params.height),
                           heightValue * colorScheme.heightScale);
    
    // Multiple light sources for better definition
    float3 lightPos1 = colorScheme.lightPosition;
    float3 lightPos2 = float3(0.8, 0.2, 1.0);
    float3 viewPos = colorScheme.viewPosition;
    
    // Light 1 calculations
    float3 lightDir1 = normalize(lightPos1 - fragPos);
    float3 viewDir = normalize(viewPos - fragPos);
    float3 halfwayDir1 = normalize(lightDir1 + viewDir);
    
    // Light 2 calculations
    float3 lightDir2 = normalize(lightPos2 - fragPos);
    float3 halfwayDir2 = normalize(lightDir2 + viewDir);
    
    // Diffuse shading
    float diff1 = max(dot(normal, lightDir1), 0.0);
    float diff2 = max(dot(normal, lightDir2), 0.0) * 0.5; // Secondary light is dimmer
    
    // Specular shading (Blinn-Phong)
    float spec1 = pow(max(dot(normal, halfwayDir1), 0.0), colorScheme.shininess);
    float spec2 = pow(max(dot(normal, halfwayDir2), 0.0), colorScheme.shininess) * 0.3;
    
    // Calculate ambient occlusion
    float ao = calculateAO(chemicalTexture, gid, 3);
    ao = mix(0.7, 1.0, ao); // Soften the AO effect
    
    // Combine lighting components
    float3 ambient = colorScheme.ambientStrength * baseColor * ao;
    float3 diffuse = colorScheme.diffuseStrength * (diff1 + diff2) * baseColor;
    float3 specular = colorScheme.specularStrength * (spec1 + spec2) * float3(1.0);
    
    // Edge detection for enhanced definition
    float edge = length(float2(normal.x, normal.y));
    edge = smoothstep(0.1, 0.3, edge);
    
    // Final color with lighting
    float3 finalColor = ambient + diffuse + specular;
    
    // Add subtle edge darkening
    finalColor = mix(finalColor * 0.7, finalColor, 1.0 - edge * 0.3);
    
    // Tone mapping for better contrast
    finalColor = finalColor / (finalColor + float3(1.0));
    finalColor = pow(finalColor, float3(1.0/2.2)); // Gamma correction
    
    outputTexture.write(float4(finalColor, 1.0), gid);
}

// Vertex/Fragment shaders remain the same
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
