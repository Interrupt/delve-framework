#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct fs_params
{
    float4 u_cameraPos;
    float4 u_color_override;
    float u_alpha_cutoff;
    float4 u_ambient_light;
    float4 u_dir_light_dir;
    float4 u_dir_light_color;
    float u_num_point_lights;
    float4 u_point_light_data[32];
};

struct main0_out
{
    float4 frag_color [[color(0)]];
};

struct main0_in
{
    float4 color [[user(locn0)]];
    float2 uv [[user(locn1)]];
    float3 normal [[user(locn2)]];
    float4 position [[user(locn4)]];
};

static inline __attribute__((always_inline))
float sqr(thread const float& x)
{
    return x * x;
}

static inline __attribute__((always_inline))
float attenuate_light(thread const float& _distance, thread const float& radius, thread const float& max_intensity, thread const float& falloff)
{
    float _27 = _distance / radius;
    if (_27 >= 1.0)
    {
        return 0.0;
    }
    float param = _27;
    float param_1 = 1.0 - sqr(param);
    return (max_intensity * sqr(param_1)) / fma(falloff, _27, 1.0);
}

fragment main0_out main0(main0_in in [[stage_in]], constant fs_params& _81 [[buffer(0)]], texture2d<float> tex [[texture(0)]], texture2d<float> tex_emissive [[texture(1)]], sampler smp [[sampler(0)]])
{
    main0_out out = {};
    float4 _74 = tex.sample(smp, in.uv) * in.color;
    float4 c = _74;
    float4 lit_color = _81.u_ambient_light;
    if (_74.w <= _81.u_alpha_cutoff)
    {
        discard_fragment();
    }
    for (int i = 0; i < int(_81.u_num_point_lights); i++)
    {
        int _115 = i * 2;
        float3 _138 = _81.u_point_light_data[_115].xyz - in.position.xyz;
        float param = length(_138);
        float param_1 = _81.u_point_light_data[_115].w;
        float param_2 = 1.0;
        float param_3 = 1.0;
        float4 _168 = lit_color;
        float3 _170 = _168.xyz + ((_81.u_point_light_data[_115 + 1].xyz * fast::max(dot(fast::normalize(_138), in.normal), 0.0)) * attenuate_light(param, param_1, param_2, param_3));
        float4 _282 = _168;
        _282.x = _170.x;
        _282.y = _170.y;
        _282.z = _170.z;
        lit_color = _282;
    }
    float4 _211 = lit_color;
    float3 _213 = _211.xyz + (_81.u_dir_light_color.xyz * (fast::max(dot(float4(_81.u_dir_light_dir.x, _81.u_dir_light_dir.y, _81.u_dir_light_dir.z, 0.0), float4(in.normal, 0.0)), 0.0) * _81.u_dir_light_dir.w));
    float4 _288 = _211;
    _288.x = _213.x;
    _288.y = _213.y;
    _288.z = _213.z;
    lit_color = _288;
    float4 _222 = c * _288;
    float4 _229 = tex_emissive.sample(smp, in.uv);
    float3 _247 = (_222.xyz * (1.0 - fast::min((_229.x + _229.y) + _229.z, 1.0))) + _229.xyz;
    float4 _297 = _222;
    _297.x = _247.x;
    _297.y = _247.y;
    _297.z = _247.z;
    float3 _268 = (_297.xyz * (1.0 - _81.u_color_override.w)) + (_81.u_color_override.xyz * _81.u_color_override.w);
    float4 _303 = _297;
    _303.x = _268.x;
    _303.y = _268.y;
    _303.z = _268.z;
    c = _303;
    out.frag_color = _303;
    return out;
}

