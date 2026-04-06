#ifndef Shader_h
#define Shader_h

#include <metal_stdlib>

struct VertexIn {
    metal::packed_float3 position;
    metal::packed_float3 normal;
    metal::packed_float2 texCoord;
    metal::packed_float4 boneWeights;
    metal::packed_short4 boneIndices;
};

struct Uniforms {
    metal::float4x4 modelMatrix;
    metal::float4x4 modelViewMatrix;
    metal::float4x4 projectionMatrix;
    metal::float4x4 shadowMatrix;
    metal::float4x4 shadowMatrixGB;
    metal::float3x3 normalMatrix;
};

struct FragOutput {
    metal::float4 albedo [[color(0)]];
    metal::float4 normal [[color(1)]];
           float  depth  [[color(2)]];
    metal::float4 light  [[color(3)]];
};

#endif
