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

struct PointLight {
    float3 worldPosition;
    float3 color;
};

struct SunLight {
    float3 worldPosition;
    float3 color;
    float3 normal;
};

struct VertexUniforms {
    float4x4 viewProjectionMatrix;
    float4x4 modelMatrix;
    float3x3 normalMatrix;
};

#define LightCount 3

struct SceneUniforms {
    int numPointLights;
    int numSunLights;
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
                              constant PointLight* lights [[buffer(2)]],
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

float3 hsv2rgb(float3 hsv) {
    float c = hsv[2] * hsv[1];
    float h_prime = hsv[0] / (M_PI_F/3);
    float x = c * (1 - abs(fmod(h_prime, 2) - 1));
    float3 rgb = float3(0);
    if (h_prime >= 0 and h_prime < 1) {
        rgb = float3(c, x, 0);
    } else if (h_prime >= 1 and h_prime < 2) {
        rgb = float3(x, c, 0);
    } else if (h_prime >= 2 and h_prime < 3) {
        rgb = float3(0, c, x);
    } else if (h_prime >= 3 and h_prime < 4) {
        rgb = float3(0, x, c);
    } else if (h_prime >= 4 and h_prime < 5) {
        rgb = float3(x, 0, c);
    } else if (h_prime >= 5 and h_prime < 6) {
        rgb = float3(c, 0, x);
    }
    
    float m = hsv[2] - c;
    return rgb + float3(m);
}

float distanceFromPointToPlane(float3 point, float3 normal, float3 planePos) {
    return dot(point - planePos, normalize(normal));
}

fragment float4 fragment_hologram_expose(VertexOut fragmentIn [[stage_in]],
                                  constant SceneUniforms &sceneUniforms [[buffer(0)]],
                                  constant NodeUniforms &nodeUniforms [[buffer(1)]],
                                  constant PointLight* point_lights [[buffer(2)]],
                                  constant SunLight* sun_lights [[buffer(3)]],
                                  texture2d<float, access::sample> baseColorTexture [[texture(0)]],
                                  sampler baseColorSampler [[sampler(0)]]) {
    float2 phases = float2(0, 0);
    
    // Run through point lights
    for (int i = 0; i < sceneUniforms.numPointLights; i++) {
        float dist = distance(fragmentIn.worldPosition, point_lights[i].worldPosition) * sceneUniforms.frequency;
//        float distance_sq = distance * distance;
        phases += float2(cos(dist), sin(dist));
    }
    
    // Run through sun lights
    for (int i = 0; i < sceneUniforms.numSunLights; i++) {
        SunLight l = sun_lights[i];
        float dist = distanceFromPointToPlane(fragmentIn.worldPosition, l.worldPosition, l.normal);
        phases += float2(cos(dist), sin(dist));
    }
    
    float angle = atan2(phases.y, phases.x);
    if (angle < 0) {
        angle += 2*M_PI_F;
    }
    // Saturation = 0 means just amplitude, saturation = 1 means also display phase as hue
    float3 hsv = float3(angle, 1, length(phases)/(sceneUniforms.numPointLights + sceneUniforms.numSunLights));
    float3 finalColor = hsv2rgb(hsv);
    return float4(finalColor, 1);
}

fragment float4 fragment_hologram_view(VertexOut fragmentIn [[stage_in]],
                                  constant SceneUniforms &sceneUniforms [[buffer(0)]],
                                  constant NodeUniforms &nodeUniforms [[buffer(1)]],
                                  constant PointLight* point_lights [[buffer(2)]],
                                  texture2d<float, access::sample> baseColorTexture [[texture(0)]],
                                  sampler baseColorSampler [[sampler(0)]]) {
    float2 phases = float2(0, 0);
    
    // Run through point lights
    for (int i = 0; i < sceneUniforms.numPointLights; i++) {
        float dist = distance(fragmentIn.worldPosition, point_lights[i].worldPosition) * sceneUniforms.frequency;
//        float distance_sq = distance * distance;
        phases += float2(cos(dist), sin(dist));
    }
    
    float angle = atan2(phases.y, phases.x);
    if (angle < 0) {
        angle += 2*M_PI_F;
    }
    // Saturation = 0 means just amplitude, saturation = 1 means also display phase as hue
    float3 hsv = float3(angle, 0, length(phases)/sceneUniforms.numPointLights);
    float3 finalColor = hsv2rgb(hsv);
    return float4(finalColor, 1);
}
