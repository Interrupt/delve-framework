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
    float4 u_fog_data;
    float4 u_fog_color;
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
    float _30 = _distance / radius;
    if (_30 >= 1.0)
    {
        return 0.0;
    }
    float param = _30;
    float param_1 = 1.0 - sqr(param);
    return (max_intensity * sqr(param_1)) / fma(falloff, _30, 1.0);
}

static inline __attribute__((always_inline))
float calcFogFactor(thread const float& distance_to_eye, constant fs_params& _63)
{
    return fast::clamp(((distance_to_eye - _63.u_fog_data.x) / (_63.u_fog_data.y - _63.u_fog_data.x)) * _63.u_fog_color.w, 0.0, 1.0);
}

fragment main0_out main0(main0_in in [[stage_in]], constant fs_params& _63 [[buffer(0)]], texture2d<float> tex [[texture(0)]], texture2d<float> tex_emissive [[texture(1)]], sampler smp [[sampler(0)]])
{
    main0_out out = {};
    float4 _113 = tex.sample(smp, in.uv) * in.color;
    float4 c = _113;
    float4 lit_color = _63.u_ambient_light;
    if (_113.w <= _63.u_alpha_cutoff)
    {
        discard_fragment();
    }
    for (int i = 0; i < int(_63.u_num_point_lights); i++)
    {
        int _145 = i * 2;
        float3 _168 = _63.u_point_light_data[_145].xyz - in.position.xyz;
        float param = length(_168);
        float param_1 = _63.u_point_light_data[_145].w;
        float param_2 = 1.0;
        float param_3 = 1.0;
        float4 _198 = lit_color;
        float3 _200 = _198.xyz + ((_63.u_point_light_data[_145 + 1].xyz * fast::max(dot(fast::normalize(_168), in.normal), 0.0)) * attenuate_light(param, param_1, param_2, param_3));
        float4 _329 = _198;
        _329.x = _200.x;
        _329.y = _200.y;
        _329.z = _200.z;
        lit_color = _329;
    }
    float4 _239 = lit_color;
    float3 _241 = _239.xyz + (_63.u_dir_light_color.xyz * (fast::max(dot(float4(_63.u_dir_light_dir.x, _63.u_dir_light_dir.y, _63.u_dir_light_dir.z, 0.0), float4(in.normal, 0.0)), 0.0) * _63.u_dir_light_dir.w));
    float4 _335 = _239;
    _335.x = _241.x;
    _335.y = _241.y;
    _335.z = _241.z;
    lit_color = _335;
    float4 _250 = c * _335;
    float4 _257 = tex_emissive.sample(smp, in.uv);
    float3 _275 = (_250.xyz * (1.0 - fast::min((_257.x + _257.y) + _257.z, 1.0))) + _257.xyz;
    float4 _344 = _250;
    _344.x = _275.x;
    _344.y = _275.y;
    _344.z = _275.z;
    float3 _296 = (_344.xyz * (1.0 - _63.u_color_override.w)) + (_63.u_color_override.xyz * _63.u_color_override.w);
    float4 _350 = _344;
    _350.x = _296.x;
    _350.y = _296.y;
    _350.z = _296.z;
    c = _350;
    float param_4 = length(_63.u_cameraPos - in.position);
    out.frag_color = float4(mix(c.xyz, _63.u_fog_color.xyz, float3(calcFogFactor(param_4, _63))), 1.0);
    return out;
}

