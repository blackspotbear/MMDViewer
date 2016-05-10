#include <metal_stdlib>

using namespace metal;

/*
 * Type Definitions
 */

struct VertexIn {
    packed_float3 position    [[attribute(0)]];
    packed_float3 normal      [[attribute(1)]];
    packed_float2 texCoord    [[attribute(2)]];
    packed_float4 boneWeights [[attribute(3)]];
    packed_short4 boneIndices [[attribute(4)]];
};

struct VertexOut {
    float4 position           [[position]];
    float3 eye;
    float3 normal;
    float2 texCoord;
};

struct Light {
    float3 direction;
    float3 ambientColor;
    float3 diffuseColor;
    float3 specularColor;
};

struct Material {
    float3 ambientColor;
    float3 diffuseColor;
    float3 specularColor;
    float  specularPower;
};

struct Uniforms {
    float4x4 modelViewMatrix;
    float4x4 projectionMatrix;
    float3x3 normalMatrix;
};

/*
 * Global Variables
 */

#if 1

constant Light g_light = {
    .direction     = { 0.13, 0.72, 0.68 },
    .ambientColor  = { 0.75, 0.75, 0.75 },
    .diffuseColor  = { 0.9,  0.9,  0.9  },
    .specularColor = { 1.0,  1.0,  1.0  }
};

#else // when checking if normal is correct or not.

constant Light g_light = {
    .direction     = { 0.00, 0.00, 1.00 },
    .ambientColor  = { 0.00, 0.00, 0.00 },
    .diffuseColor  = { 0.90, 0.90, 0.90 },
    .specularColor = { 1.0,  1.0,  1.0  }
};

constant Material g_material = {
    .ambientColor  = { 0.9, 0.9, 0.9 },
    .diffuseColor  = { 0.9, 0.9, 0.9 },
    .specularColor = { 1.0, 1.0, 1.0 },
    .specularPower = 100
};

#endif

/*
 * Vertex Shader
 */
vertex VertexOut basic_vertex(const device VertexIn* vertex_array [[ buffer(0) ]],
                              const device Uniforms& uniforms     [[ buffer(1) ]],
                              const device float4x4* matrices     [[ buffer(2) ]],
                              unsigned int vid                    [[ vertex_id ]]) {
    VertexIn in = vertex_array[vid];
    
    float4 positions[4];
    const float4 v = float4(in.position, 1);
    for (int i = 0; i < 4; i++) {
        positions[i] = uniforms.modelViewMatrix * matrices[in.boneIndices[i]] * v;
    }
    float4 position = positions[0] * in.boneWeights[0];
    for (int i = 1; i < 4; i++) {
        position += positions[i] * in.boneWeights[i];
    }
    
    float3 normals[4];
    const float4 n = float4(in.normal, 0); // w must be zero.
    for (int i = 0; i < 4; i++) {
        normals[i] = (matrices[in.boneIndices[i]] * n).xyz;
    }
    float3 normal = normals[0].xyz * in.boneWeights[0];
    for (int i = 1; i < 4; i++) {
        normal += normals[i].xyz * in.boneWeights[i];
    }
    normal = normalize(normal);
    
    VertexOut out;
    out.position = uniforms.projectionMatrix * position;
    out.eye      = -position.xyz;
    out.normal   = uniforms.normalMatrix * normal;
    out.texCoord = in.texCoord;
    
    return out;
}

/*
 * Fragment Shader
 *
 * > If the depth value is not output by the fragment function,
 * > the depth value generated by the rasterizer is output to the depth attachment
 */
fragment float4 basic_fragment(VertexOut interpolated      [[ stage_in   ]],
                               constant Uniforms &uniforms [[ buffer(0)  ]],
                               constant Material & material [[ buffer(1) ]],
                               texture2d<float>  tex2D     [[ texture(0) ]],
                               sampler           sampler2D [[ sampler(0) ]]) {
    float3 ambientTerm        = g_light.ambientColor * material.ambientColor;
    
    float3 normal             = normalize(interpolated.normal);
    float  diffuseIntensity   = saturate(dot(normal, g_light.direction));
    float3 diffuseTerm        = g_light.diffuseColor * material.diffuseColor * diffuseIntensity;
    
    float3 specularTerm(0);
    if (diffuseIntensity > 0) {
        float3 eyeDirection   = normalize(interpolated.eye);
        float3 halfway        = normalize(g_light.direction + eyeDirection);
        float  specularFactor = pow(saturate(dot(normal, halfway)), material.specularPower);
        specularTerm          = g_light.specularColor * material.specularColor * specularFactor;
    }
    
    float4 texColor           = tex2D.sample(sampler2D, interpolated.texCoord);
    
    return float4(ambientTerm + diffuseTerm + specularTerm, 1) * texColor;
}
