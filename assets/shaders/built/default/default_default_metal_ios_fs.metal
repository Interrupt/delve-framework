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

fragment main0_out main0(main0_in in [[stage_in]], constant fs_params& _36 [[buffer(0)]], texture2d<float> tex [[texture(0)]], sampler smp [[sampler(0)]])
{
    main0_out out = {};
    float4 _28 = tex.sample(smp, in.uv) * in.color;
    float4 c = _28;
    if (_28.w <= _36.u_alpha_cutoff)
    {
        discard_fragment();
    }
    float4 _54 = c;
    float3 _65 = (_54.xyz * (1.0 - _36.u_color_override.w)) + (_36.u_color_override.xyz * _36.u_color_override.w);
    float4 _80 = _54;
    _80.x = _65.x;
    _80.y = _65.y;
    _80.z = _65.z;
    c = _80;
    out.frag_color = _80;
    return out;
}

