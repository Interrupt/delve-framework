#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct vs_params
{
    float4x4 u_projViewMatrix;
    float4x4 u_modelMatrix;
    float4 u_color;
    float4x4 u_joints[64];
    float4 u_tex_pan;
};

struct main0_out
{
    float4 color [[user(locn0)]];
    float2 uv [[user(locn1)]];
    float3 normal [[user(locn2)]];
    float4 tangent [[user(locn3)]];
    float4 position [[user(locn4)]];
    float4 baseDiffuse [[user(locn5)]];
    float4 gl_Position [[position]];
};

struct main0_in
{
    float4 pos [[attribute(0)]];
    float4 color0 [[attribute(1)]];
    float2 texcoord0 [[attribute(2)]];
    float3 normals [[attribute(3)]];
    float4 tangents [[attribute(4)]];
    float4 joints [[attribute(5)]];
    float4 weights [[attribute(6)]];
};

vertex main0_out main0(main0_in in [[stage_in]], constant vs_params& _22 [[buffer(0)]])
{
    main0_out out = {};
    float4x4 _32 = _22.u_joints[int(in.joints.x)] * in.weights.x;
    float4x4 _41 = _22.u_joints[int(in.joints.y)] * in.weights.y;
    float4x4 _63 = _22.u_joints[int(in.joints.z)] * in.weights.z;
    float4x4 _85 = _22.u_joints[int(in.joints.w)] * in.weights.w;
    float4x4 _104 = _22.u_modelMatrix * float4x4(((_32[0] + _41[0]) + _63[0]) + _85[0], ((_32[1] + _41[1]) + _63[1]) + _85[1], ((_32[2] + _41[2]) + _63[2]) + _85[2], ((_32[3] + _41[3]) + _63[3]) + _85[3]);
    out.color = float4(0.0, 0.0, 0.0, 1.0);
    out.uv = in.texcoord0 + _22.u_tex_pan.xy;
    out.normal = fast::normalize(_104 * float4(in.normals, 0.0)).xyz;
    out.tangent = in.tangents;
    out.position = _104 * in.pos;
    out.baseDiffuse = in.color0 * _22.u_color;
    out.gl_Position = _22.u_projViewMatrix * out.position;
    return out;
}

