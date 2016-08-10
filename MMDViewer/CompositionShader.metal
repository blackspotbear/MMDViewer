#include "ShaderCommon.h"
#include <metal_stdlib>
#include <metal_graphics>
#include <metal_geometric>

using namespace metal;

struct VertexOutput {
    float4 position [[position]];
};

struct MaterialSunData {
    float3 sunDirection;
    float4 sunColor;
};

constant MaterialSunData gSunData = {
//  .sunDirection = { 0.13, 0.72, 0.68     },
    .sunDirection = { -1 ,  0,    0        },
    .sunColor     = { 0.5,  0.5,  0.5, 1.0 }
};

vertex VertexOutput compositionVertex(constant float2 *posData [[buffer(0)]],
                                      uint vid                 [[vertex_id]] ) {
    VertexOutput output;
    output.position = float4(posData[vid], 0.0f, 1.0f);
    return output;
}

fragment float4 compositionFrag(VertexOutput in [[stage_in]],
                                FragOutput gBuffers) {
    float4 light    = gBuffers.light;
    float3 diffuse  = light.rgb;
    float3 specular = light.aaa;
    float3 n_s      = gBuffers.normal.rgb;
    float sun_atten = gBuffers.albedo.a; // zero or one
    float sun_diffuse = fmax(dot(n_s * 2.0 - 1.0, gSunData.sunDirection.xyz), 0.0) * sun_atten;
    
    diffuse += gSunData.sunColor.rgb * sun_diffuse;
    diffuse *= gBuffers.albedo.rgb;
    
    specular *= gBuffers.normal.w; // specular lighting mask is stored in w
    
    diffuse += diffuse;
    specular += specular;
    
    return float4(diffuse.xyz + specular.xyz, 1.0);
}
