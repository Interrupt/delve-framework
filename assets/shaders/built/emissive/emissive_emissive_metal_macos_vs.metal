#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct vs_params
{
    float4x4 u_projViewMatrix;
    float4x4 u_modelMatrix;
    float4 u_color;
    float4 u_tex_pan;
};

struct main0_out
{
    float4 color [[user(locn0)]];
    float2 uv [[user(locn1)]];
    float3 normal [[user(locn2)]];
    float4 tangent [[user(locn3)]];
    float4 gl_Position [[position]];
};

struct main0_in
{
    float4 pos [[attribute(0)]];
    float4 color0 [[attribute(1)]];
    float2 texcoord0 [[attribute(2)]];
    float3 normals [[attribute(3)]];
    float4 tangents [[attribute(4)]];
};

vertex main0_out main0(main0_in in [[stage_in]], constant vs_params& _19 [[buffer(0)]])
{
    main0_out out = {};
    out.gl_Position = (_19.u_projViewMatrix * _19.u_modelMatrix) * in.pos;
    out.color = in.color0 * _19.u_color;
    out.uv = in.texcoord0 + _19.u_tex_pan.xy;
    out.normal = in.normals;
    out.tangent = in.tangents;
    return out;
}

