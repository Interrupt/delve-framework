cbuffer fs_params : register(b1)
{
    float4 _63_u_cameraPos : packoffset(c0);
    float4 _63_u_color_override : packoffset(c1);
    float _63_u_alpha_cutoff : packoffset(c2);
    float4 _63_u_ambient_light : packoffset(c3);
    float4 _63_u_dir_light_dir : packoffset(c4);
    float4 _63_u_dir_light_color : packoffset(c5);
    float _63_u_num_point_lights : packoffset(c6);
    float4 _63_u_point_light_data[32] : packoffset(c7);
    float4 _63_u_fog_data : packoffset(c39);
    float4 _63_u_fog_color : packoffset(c40);
};

Texture2D<float4> tex : register(t0);
SamplerState smp : register(s0);
Texture2D<float4> tex_emissive : register(t1);

static float2 uv;
static float4 baseDiffuse;
static float4 position;
static float3 normal;
static float4 frag_color;
static float4 color;
static float4 tangent;

struct SPIRV_Cross_Input
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float3 normal : TEXCOORD2;
    float4 tangent : TEXCOORD3;
    float4 position : TEXCOORD4;
    float4 baseDiffuse : TEXCOORD5;
};

struct SPIRV_Cross_Output
{
    float4 frag_color : SV_Target0;
};

float sqr(float x)
{
    return x * x;
}

float attenuate_light(float _distance, float radius, float max_intensity, float falloff)
{
    float _30 = _distance / radius;
    if (_30 >= 1.0f)
    {
        return 0.0f;
    }
    float param = _30;
    float param_1 = 1.0f - sqr(param);
    return (max_intensity * sqr(param_1)) / (1.0f + (falloff * _30));
}

float calcFogFactor(float distance_to_eye)
{
    return clamp(((distance_to_eye - _63_u_fog_data.x) / (_63_u_fog_data.y - _63_u_fog_data.x)) * _63_u_fog_color.w, 0.0f, 1.0f);
}

void frag_main()
{
    float4 _113 = tex.Sample(smp, uv) * baseDiffuse;
    float4 c = _113;
    float4 lit_color = _63_u_ambient_light;
    if (_113.w <= _63_u_alpha_cutoff)
    {
        discard;
    }
    for (int i = 0; i < int(_63_u_num_point_lights); i++)
    {
        int _145 = i * 2;
        float3 _168 = _63_u_point_light_data[_145].xyz - position.xyz;
        float param = length(_168);
        float param_1 = _63_u_point_light_data[_145].w;
        float param_2 = 1.0f;
        float param_3 = 1.0f;
        float4 _198 = lit_color;
        float3 _200 = _198.xyz + ((_63_u_point_light_data[_145 + 1].xyz * max(dot(normalize(_168), normal), 0.0f)) * attenuate_light(param, param_1, param_2, param_3));
        float4 _330 = _198;
        _330.x = _200.x;
        _330.y = _200.y;
        _330.z = _200.z;
        lit_color = _330;
    }
    float4 _239 = lit_color;
    float3 _241 = _239.xyz + (_63_u_dir_light_color.xyz * (max(dot(float4(_63_u_dir_light_dir.x, _63_u_dir_light_dir.y, _63_u_dir_light_dir.z, 0.0f), float4(normal, 0.0f)), 0.0f) * _63_u_dir_light_dir.w));
    float4 _336 = _239;
    _336.x = _241.x;
    _336.y = _241.y;
    _336.z = _241.z;
    lit_color = _336;
    float4 _250 = c * _336;
    float4 _257 = tex_emissive.Sample(smp, uv);
    float3 _275 = (_250.xyz * (1.0f - min((_257.x + _257.y) + _257.z, 1.0f))) + _257.xyz;
    float4 _345 = _250;
    _345.x = _275.x;
    _345.y = _275.y;
    _345.z = _275.z;
    float3 _296 = (_345.xyz * (1.0f - _63_u_color_override.w)) + (_63_u_color_override.xyz * _63_u_color_override.w);
    float4 _351 = _345;
    _351.x = _296.x;
    _351.y = _296.y;
    _351.z = _296.z;
    c = _351;
    float param_4 = length(_63_u_cameraPos - position);
    frag_color = float4(lerp(c.xyz, _63_u_fog_color.xyz, calcFogFactor(param_4).xxx), 1.0f);
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    uv = stage_input.uv;
    baseDiffuse = stage_input.baseDiffuse;
    position = stage_input.position;
    normal = stage_input.normal;
    color = stage_input.color;
    tangent = stage_input.tangent;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.frag_color = frag_color;
    return stage_output;
}
