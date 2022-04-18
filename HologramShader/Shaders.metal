//
//  Shaders.metal
//  HologramShader
//
//  Created by qe on 4/14/22.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 worldNormal;
    float2 texCoords;
};

struct VertexUniforms {
    float4x4 modelMatrix;
    float4x4 viewProjectionMatrix;
    float3x3 normalMatrix;
};

struct Light {
    float3 worldPosition;
    float3 color;
};

#define LightCount 3
struct FragmentUniforms {
    float3 cameraWorldPosition;
    float3 ambientLightColor;
    float3 specularColor;
    float specularPower;
    Light lights[LightCount];
};

vertex VertexOut vertex_main(VertexIn vertexIn [[stage_in]], constant VertexUniforms &uniforms [[buffer(1)]]) {
    VertexOut vertexOut;
    float4 worldPosition = uniforms.modelMatrix * float4(vertexIn.position, 1);
    vertexOut.position = uniforms.viewProjectionMatrix * worldPosition; // clip-space position
    vertexOut.worldPosition = worldPosition.xyz;
    vertexOut.worldNormal = uniforms.normalMatrix * vertexIn.normal;
    vertexOut.texCoords = vertexIn.texCoords;
    return vertexOut;
}

//constant float3 ambientIntensity = 0.3;
//constant float3 lightPosition(2, 2, 2); // Light position in world space
//constant float3 lightColor(1, 1, 1);
//constant float3 worldCameraPosition(0, 0, 2);
//constant float3 baseColor(1.0, 0, 0);
//constant float specularPower = 200;

fragment float4 fragment_main(VertexOut fragmentIn [[stage_in]],
                              constant FragmentUniforms &uniforms [[buffer(0)]],
                              texture2d<float, access::sample> baseColorTexture [[texture(0)]],
                              sampler baseColorSampler [[sampler(0)]]) {
    float3 baseColor = baseColorTexture.sample(baseColorSampler, fragmentIn.texCoords).rgb;
    float3 specularColor = uniforms.specularColor;
    float3 N = normalize(fragmentIn.worldNormal);
    float3 V = normalize(uniforms.cameraWorldPosition - fragmentIn.worldPosition);
    float3 finalColor(0, 0, 0);
    for (int i = 0; i < LightCount; i++) {
        float3 L = normalize(uniforms.lights[i].worldPosition - fragmentIn.worldPosition);
        float3 diffuseIntensity = saturate(dot(N, L));
        float3 H = normalize(L + V);
        float specularBase = saturate(dot(N, H));
        float specularIntensity = powr(specularBase, uniforms.specularPower);
        float3 lightColor = uniforms.lights[i].color;
        finalColor += uniforms.ambientLightColor * baseColor +
                      diffuseIntensity * lightColor * baseColor +
                      specularIntensity * lightColor * specularColor;
    }
//    float3 L = normalize(lightPosition - fragmentIn.worldPosition);
//    float3 diffuseIntensity = saturate(dot(N, L));
//    float3 H = normalize(L + V);
//    float specularBase = saturate(dot(N, H));
//    float specularIntensity = powr(specularBase, specularPower);
//    float3 finalColor = saturate(ambientIntensity + diffuseIntensity) * baseColor * lightColor + specularIntensity * lightColor;
    return float4(finalColor, 1);
}
