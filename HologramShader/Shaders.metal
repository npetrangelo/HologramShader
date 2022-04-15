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

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewProjectionMatrix;
    float3x3 normalMatrix;
};

vertex VertexOut vertex_main(VertexIn vertexIn [[stage_in]], constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut vertexOut;
    float4 worldPosition = uniforms.modelMatrix * float4(vertexIn.position, 1);
    vertexOut.position = uniforms.viewProjectionMatrix * worldPosition; // clip-space position
    vertexOut.worldPosition = worldPosition.xyz;
    vertexOut.worldNormal = uniforms.normalMatrix * vertexIn.normal;
    vertexOut.texCoords = vertexIn.texCoords;
    return vertexOut;
}

constant float3 ambientIntensity = 0.3;
constant float3 lightPosition(2, 2, 2); // Light position in world space
constant float3 lightColor(1, 1, 1);
constant float3 baseColor(1.0, 0, 0);

fragment float4 fragment_main(VertexOut fragmentIn [[stage_in]]) {
    float3 N = normalize(fragmentIn.worldNormal);
    float3 L = normalize(lightPosition - fragmentIn.worldPosition);
    float3 diffuseIntensity = saturate(dot(N, L));
    float3 finalColor = saturate(ambientIntensity + diffuseIntensity) * lightColor * baseColor;
    return float4(finalColor, 1);
}
