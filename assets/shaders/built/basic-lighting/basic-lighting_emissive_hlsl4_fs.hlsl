cbuffer fs_params : register(b0)
{
    float4 _81_u_cameraPos : packoffset(c0);
    float4 _81_u_color_override : packoffset(c1);
    float _81_u_alpha_cutoff : packoffset(c2);
    float4 _81_u_ambient_light : packoffset(c3);
    float4 _81_u_dir_light_dir : packoffset(c4);
    float4 _81_u_dir_light_color : packoffset(c5);
    float _81_u_num_point_lights : packoffset(c6);
    float4 _81_u_point_light_data[32] : packoffset(c7);
};

Texture2D<float4> tex : register(t0);
SamplerState smp : register(s0);
Texture2D<float4> tex_emissive : register(t1);

static float2 uv;
static float4 color;
static float4 position;
static float3 normal;
static float4 frag_color;
static float4 tangent;

struct SPIRV_Cross_Input
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float3 normal : TEXCOORD2;
    float4 tangent : TEXCOORD3;
    float4 position : TEXCOORD4;
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
    float _27 = _distance / radius;
    if (_27 >= 1.0f)
    {
        return 0.0f;
    }
    float param = _27;
    float param_1 = 1.0f - sqr(param);
    return (max_intensity * sqr(param_1)) / mad(falloff, _27, 1.0f);
}

void frag_main()
{
    float4 _74 = tex.Sample(smp, uv) * color;
    float4 c = _74;
    float4 lit_color = _81_u_ambient_light;
    if (_74.w <= _81_u_alpha_cutoff)
    {
        discard;
    }
    for (int i = 0; i < int(_81_u_num_point_lights); i++)
    {
        int _115 = i * 2;
        float3 _138 = _81_u_point_light_data[_115].xyz - position.xyz;
        float param = length(_138);
        float param_1 = _81_u_point_light_data[_115].w;
        float param_2 = 1.0f;
        float param_3 = 1.0f;
        float4 _168 = lit_color;
        float3 _170 = _168.xyz + ((_81_u_point_light_data[_115 + 1].xyz * max(dot(normalize(_138), normal), 0.0f)) * attenuate_light(param, param_1, param_2, param_3));
        float4 _282 = _168;
        _282.x = _170.x;
        _282.y = _170.y;
        _282.z = _170.z;
        lit_color = _282;
    }
    float4 _211 = lit_color;
    float3 _213 = _211.xyz + (_81_u_dir_light_color.xyz * (max(dot(float4(_81_u_dir_light_dir.x, _81_u_dir_light_dir.y, _81_u_dir_light_dir.z, 0.0f), float4(normal, 0.0f)), 0.0f) * _81_u_dir_light_dir.w));
    float4 _288 = _211;
    _288.x = _213.x;
    _288.y = _213.y;
    _288.z = _213.z;
    lit_color = _288;
    float4 _222 = c * _288;
    float4 _229 = tex_emissive.Sample(smp, uv);
    float3 _247 = (_222.xyz * (1.0f - min((_229.x + _229.y) + _229.z, 1.0f))) + _229.xyz;
    float4 _297 = _222;
    _297.x = _247.x;
    _297.y = _247.y;
    _297.z = _247.z;
    float3 _268 = (_297.xyz * (1.0f - _81_u_color_override.w)) + (_81_u_color_override.xyz * _81_u_color_override.w);
    float4 _303 = _297;
    _303.x = _268.x;
    _303.y = _268.y;
    _303.z = _268.z;
    c = _303;
    frag_color = _303;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    uv = stage_input.uv;
    color = stage_input.color;
    position = stage_input.position;
    normal = stage_input.normal;
    tangent = stage_input.tangent;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.frag_color = frag_color;
    return stage_output;
}
