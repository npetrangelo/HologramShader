//
//  Shaders.metal
//  HologramShader
//
//  Created by qe on 4/14/22.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position  [[attribute(0)]];
    float3 normal    [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldNormal;
    float3 worldPosition;
    float2 texCoords;
};

struct Light {
    float3 worldPosition;
    float3 color;
};

struct VertexUniforms {
    float4x4 viewProjectionMatrix;
    float4x4 modelMatrix;
    float3x3 normalMatrix;
};

#define LightCount 3

struct SceneUniforms {
    int numLights;
    float frequency;
    float3 cameraWorldPosition;
    float3 ambientLightColor;
};

struct NodeUniforms {
    float3 specularColor;
    float specularPower;
};

vertex VertexOut vertex_main(VertexIn vertexIn [[stage_in]],
                             constant VertexUniforms &uniforms [[buffer(1)]]) {
    VertexOut vertexOut;
    float4 worldPosition = uniforms.modelMatrix * float4(vertexIn.position, 1);
    vertexOut.position = uniforms.viewProjectionMatrix * worldPosition;
    vertexOut.worldPosition = worldPosition.xyz;
    vertexOut.worldNormal = uniforms.normalMatrix * vertexIn.normal;
    vertexOut.texCoords = vertexIn.texCoords;
    return vertexOut;
}

fragment float4 fragment_main(VertexOut fragmentIn [[stage_in]],
                              constant SceneUniforms &sceneUniforms [[buffer(0)]],
                              constant NodeUniforms &nodeUniforms [[buffer(1)]],
                              constant Light* lights [[buffer(2)]],
                              texture2d<float, access::sample> baseColorTexture [[texture(0)]],
                              sampler baseColorSampler [[sampler(0)]]) {
    float3 baseColor = baseColorTexture.sample(baseColorSampler, fragmentIn.texCoords).rgb;
    float3 specularColor = nodeUniforms.specularColor;
    
    float3 N = normalize(fragmentIn.worldNormal);
    float3 V = normalize(sceneUniforms.cameraWorldPosition - fragmentIn.worldPosition);

    float3 finalColor(0, 0, 0);
    for (int i = 0; i < LightCount; ++i) {
        float3 L = normalize(lights[i].worldPosition - fragmentIn.worldPosition.xyz);
        float3 diffuseIntensity = saturate(dot(N, L));
        float3 H = normalize(L + V);
        float specularBase = saturate(dot(N, H));
        float specularIntensity = powr(specularBase, nodeUniforms.specularPower);
        float3 lightColor = lights[i].color;
        finalColor += sceneUniforms.ambientLightColor * baseColor +
                      diffuseIntensity * lightColor * baseColor +
                      specularIntensity * lightColor * specularColor;
    }
    return float4(finalColor, 1);
}

float3 hue_from_angle(float angle) {
    // Convert angle to degrees for convenience
    angle *= 180.0/M_PI_F;
    angle = fmod(angle, 360.0);
    if (angle >= 0.0 and angle < 60.0) {
        return float3(1, angle/60, 0);
    } else if (angle >= 60.0 and angle < 120.0) {
        
    } else if (angle >= 120.0 and angle < 180.0) {
        
    } else if (angle >= 180.0 and angle < 240.0) {
        
    } else if (angle >= 240.0 and angle < 300.0) {
        
    } else if (angle >= 300.0 and angle <= 360.0) {
        
    }
    return float3(0, 0, 0);
}

fragment float4 fragment_hologram(VertexOut fragmentIn [[stage_in]],
                                  constant SceneUniforms &sceneUniforms [[buffer(0)]],
                                  constant NodeUniforms &nodeUniforms [[buffer(1)]],
                                  constant Light* lights [[buffer(2)]],
                                  texture2d<float, access::sample> baseColorTexture [[texture(0)]],
                                  sampler baseColorSampler [[sampler(0)]]) {
    float3 finalColor = float3(0, 0, 0);
    for (int i = 0; i < sceneUniforms.numLights; i++) {
        float distance = length(fragmentIn.worldPosition - lights[i].worldPosition) * sceneUniforms.frequency;
//        float distance_sq = distance * distance;
        finalColor += (float3(cos(distance), sin(distance), 0) + float3(1, 1, 0))/2;
    }
    
    return float4(finalColor/sceneUniforms.numLights, 1);
}
