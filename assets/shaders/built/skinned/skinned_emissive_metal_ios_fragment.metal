#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct fs_params
{
    float4 u_color_override;
    float u_alpha_cutoff;
};

struct main0_out
{
    float4 frag_color [[color(0)]];
};

struct main0_in
{
    float4 color [[user(locn0)]];
    float2 uv [[user(locn1)]];
};

fragment main0_out main0(main0_in in [[stage_in]], constant fs_params& _36 [[buffer(1)]], texture2d<float> tex [[texture(0)]], texture2d<float> tex_emissive [[texture(1)]], sampler smp [[sampler(0)]])
{
    main0_out out = {};
    float4 _28 = tex.sample(smp, in.uv) * in.color;
    float4 c = _28;
    if (_28.w <= _36.u_alpha_cutoff)
    {
        discard_fragment();
    }
    float4 _53 = tex_emissive.sample(smp, in.uv);
    float4 _69 = c;
    float3 _76 = (_69.xyz * (1.0 - fast::min((_53.x + _53.y) + _53.z, 1.0))) + _53.xyz;
    float4 _119 = _69;
    _119.x = _76.x;
    _119.y = _76.y;
    _119.z = _76.z;
    float3 _99 = (_119.xyz * (1.0 - _36.u_color_override.w)) + (_36.u_color_override.xyz * _36.u_color_override.w);
    float4 _125 = _119;
    _125.x = _99.x;
    _125.y = _99.y;
    _125.z = _99.z;
    c = _125;
    out.frag_color = _125;
    return out;
}

