#include "ShaderCommon.h"
#include <metal_stdlib>
#include <metal_graphics>
#include <metal_geometric>

using namespace metal;

struct VertexOutput {
    float4 position [[position]];
};

vertex VertexOutput depthVertex(constant VertexIn* vertex_array [[ buffer(0) ]],
                                constant Uniforms& uniforms     [[ buffer(1) ]],
                                constant float4x4* matrices     [[ buffer(2) ]],
                                unsigned int vid                [[ vertex_id ]]) {
    const VertexIn in = vertex_array[vid];
    const float4 v = float4(in.position, 1);
    
    float4 positions[4];
    for (int i = 0; i < 4; i++) {
        positions[i] =  matrices[in.boneIndices[i]] * v;
    }
    float4 position = positions[0] * in.boneWeights[0];
    for (int i = 1; i < 4; i++) {
        position += positions[i] * in.boneWeights[i];
    }
    
    VertexOutput out;
    out.position = uniforms.shadowMatrix * uniforms.modelMatrix * position;
    
    return out;
}
