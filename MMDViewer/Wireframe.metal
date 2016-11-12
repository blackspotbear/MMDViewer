#include <metal_stdlib>
#include "ShaderCommon.h"

using namespace metal;

struct WireframeModelMatrices {
    float4x4 mvpMatrix;
};

struct VertexOutput {
    float4 position [[position]];
};

vertex VertexOutput wireframeVert(constant float4 *posData [[buffer(0)]],
                                  constant WireframeModelMatrices *matrices [[buffer(1)]],
                                  uint vid [[vertex_id]]) {
    VertexOutput output;

    float4 tempPosition = float4(posData[vid].xyz, 1.0);
    output.position = matrices->mvpMatrix * tempPosition;

    return output;
}

fragment float4 wireframeFrag(VertexOutput in [[ stage_in ]]) {
    return float4(1, 0, 0, 1);
}
