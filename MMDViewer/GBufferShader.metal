#include "ShaderCommon.h"
#include <metal_stdlib>
#include <metal_graphics>
#include <metal_geometric>
#include <metal_math>

using namespace metal;

struct VertexOutput {
    float4 position [[position]];
    float3 eye;
    float3 normal;
    float2 texCoord;
    float4 v_shadowcoord;
    float  v_lineardepth;
};

namespace {

    FragOutput fsh(VertexOutput      in,
                   constant Uniforms &uniforms,
                   texture2d<float>  tex2D,
                   depth2d<float>    shadow_texture,
                   sampler           sampler2D,
                   float4             texColor) {

        const float3 normal   = normalize(in.normal);
        constexpr sampler shadow_sampler(coord::normalized,
                                         filter::linear,
                                         address::clamp_to_edge,
                                         compare_func::less);

        // 1.0 if the comparison passes, 0.0 if it fails
        float r = shadow_texture.sample_compare(shadow_sampler,
                                                in.v_shadowcoord.xy,
                                                in.v_shadowcoord.z);
        float specular_mask = 1.0;
        float4 clear_color = float4(0.1, 0.1, 0.125, 0.0); // diffuse color in rgb & specular in a

        FragOutput out;
        out.albedo.rgb = texColor.rgb;
        out.albedo.a   = r;
        out.normal.xyz = normal.xyz * 0.5 + 0.5; // map into [0 ~ 1]
        out.normal.w   = specular_mask;
        out.depth      = in.v_lineardepth;
        out.light      = clear_color;

        return out;
    }

} // anonymous namespace

vertex VertexOutput gBufferVert(const device VertexIn* vertex_array [[ buffer(0) ]],
                                        const device Uniforms& uniforms     [[ buffer(1) ]],
                                        const device float4x4* matrices     [[ buffer(2) ]],
                                        unsigned int vid                    [[ vertex_id ]]) {
    VertexIn in = vertex_array[vid];

    // position
    const float4 v = float4(in.position, 1);
    float4 positions[4];
    for (int i = 0; i < 4; i++) {
        positions[i] =  matrices[in.boneIndices[i]] * v;
    }
    float4 position = positions[0] * in.boneWeights[0];
    for (int i = 1; i < 4; i++) {
        position += positions[i] * in.boneWeights[i];
    }
    
    // normal
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
    
    // out
    VertexOutput out;
    out.position      = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.eye           = -position.xyz;
    out.normal        = uniforms.normalMatrix * normal;
    out.texCoord      = in.texCoord;
    out.v_lineardepth = (uniforms.modelViewMatrix * position).z;
    out.v_shadowcoord = uniforms.shadowMatrixGB * uniforms.modelMatrix * position;
    
    return out;
}

fragment FragOutput gBufferFrag(VertexOutput         in             [[ stage_in   ]],
                                constant Uniforms    &uniforms      [[ buffer(0)  ]],
                                texture2d<float>     tex2D          [[ texture(0) ]],
                                depth2d<float>       shadow_texture [[ texture(1) ]],
                                sampler              sampler2D      [[ sampler(0) ]]) {
    const float4 texColor = tex2D.sample(sampler2D, in.texCoord);
    return fsh(in, uniforms, tex2D, shadow_texture, sampler2D, texColor);
}

// Stipple(Screen-door) Transparency version
// see: https://ocias.com/blog/unity-stipple-transparency-shader/
fragment FragOutput gBufferFragStipple(VertexOutput         in             [[ stage_in   ]],
                                       constant Uniforms    &uniforms      [[ buffer(0)  ]],
                                       texture2d<float>     tex2D          [[ texture(0) ]],
                                       depth2d<float>       shadow_texture [[ texture(1) ]],
                                       sampler              sampler2D      [[ sampler(0) ]]) {

    const float4x4 thresholdMatrix = float4x4(float4( 1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0),
                                              float4(13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0),
                                              float4( 4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0),
                                              float4(16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0));
    const float4x4 rowAccess = float4x4(1); // Identity Matrix

    // TODO: apply actual screen size
    const float2 screenPos = (in.position.xy * 0.5 + float2(0.5, 0.5)) * float2(750, 1206/*1166*//*1334*/);
    const int ix = fmod(screenPos.x, 4);
    const int iy = fmod(screenPos.y, 4);
    const float threshold = dot(thresholdMatrix[ix], rowAccess[iy]);

    const float4 texColor = tex2D.sample(sampler2D, in.texCoord);
    if (texColor.a < threshold) {
        discard_fragment();
    }

    return fsh(in, uniforms, tex2D, shadow_texture, sampler2D, texColor);
}
