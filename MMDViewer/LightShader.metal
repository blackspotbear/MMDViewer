#include <metal_stdlib>
#include "ShaderCommon.h"

using namespace metal;

struct LightModelMatrices {
    float4x4 mvpMatrix;
    float4x4 mvMatrix;
};

struct LightFragmentInputs {
    float4   light_position;
    float4   view_light_position;
    float4   light_color_radius;
};

struct VertexOutput {
    float4 position [[position]];
    float3 v_view;
};

vertex VertexOutput lightVert(constant float4 *posData [[buffer(0)]],
                              constant LightModelMatrices *matrices [[buffer(1)]],
                              uint vid [[vertex_id]]) {
    VertexOutput output;
    
    float4 tempPosition = float4(posData[vid].xyz, 1.0);
    output.position = matrices->mvpMatrix * tempPosition;
    output.v_view = (matrices->mvMatrix * tempPosition).xyz;
    
    return output;
}

fragment FragOutput lightFrag(VertexOutput in [[stage_in]],
                              constant LightFragmentInputs *lightData [[buffer(0)]],
                              FragOutput gBuffers) {
    float3 n_s = gBuffers.normal.rgb;
    float scene_z = gBuffers.depth;
    float3 n = n_s * 2.0 - 1.0;
    float3 v = in.v_view * (scene_z / in.v_view.z);
    float3 l = (lightData->view_light_position.xyz - v);
    float n_ls = dot(n, n);
    float v_ls = dot(v, v);
    float l_ls = dot(l, l);
    float3 h = (l * rsqrt(l_ls / v_ls) - v);
    float h_ls = dot(h, h);
    float nl = dot(n, l) * rsqrt(n_ls * l_ls);
    float nh = dot(n, h) * rsqrt(n_ls * h_ls);
    float d_atten = sqrt(l_ls);
    float atten = fmax(1.0 - d_atten / lightData->light_color_radius.w, 0.0);
    float diffuse = fmax(nl, 0.0) * atten;
    float4 light = gBuffers.light;
    
    light.rgb += lightData->light_color_radius.xyz * diffuse;
    light.a += pow(fmax(nh, 0.0), 32.0) * step(0.0, nl) * atten * 1.0001;
    
    FragOutput output;
    output.albedo = gBuffers.albedo;
    output.normal = gBuffers.normal;
    output.depth = gBuffers.depth;
    output.light = light;
    
    return output;
}
