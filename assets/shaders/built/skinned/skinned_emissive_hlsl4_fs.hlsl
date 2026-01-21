cbuffer fs_params : register(b0)
{
    float4 _36_u_color_override : packoffset(c0);
    float _36_u_alpha_cutoff : packoffset(c1);
};

Texture2D<float4> tex : register(t0);
SamplerState smp : register(s0);
Texture2D<float4> tex_emissive : register(t1);

static float2 uv;
static float4 color;
static float4 frag_color;
static float3 normal;
static float4 tangent;
static float4 joint;
static float4 weight;

struct SPIRV_Cross_Input
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float3 normal : TEXCOORD2;
    float4 tangent : TEXCOORD3;
    float4 joint : TEXCOORD4;
    float4 weight : TEXCOORD5;
};

struct SPIRV_Cross_Output
{
    float4 frag_color : SV_Target0;
};

void frag_main()
{
    float4 _28 = tex.Sample(smp, uv) * color;
    float4 c = _28;
    if (_28.w <= _36_u_alpha_cutoff)
    {
        discard;
    }
    float4 _53 = tex_emissive.Sample(smp, uv);
    float4 _69 = c;
    float3 _76 = (_69.xyz * (1.0f - min((_53.x + _53.y) + _53.z, 1.0f))) + _53.xyz;
    float4 _119 = _69;
    _119.x = _76.x;
    _119.y = _76.y;
    _119.z = _76.z;
    float3 _99 = (_119.xyz * (1.0f - _36_u_color_override.w)) + (_36_u_color_override.xyz * _36_u_color_override.w);
    float4 _125 = _119;
    _125.x = _99.x;
    _125.y = _99.y;
    _125.z = _99.z;
    c = _125;
    frag_color = _125;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    uv = stage_input.uv;
    color = stage_input.color;
    normal = stage_input.normal;
    tangent = stage_input.tangent;
    joint = stage_input.joint;
    weight = stage_input.weight;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.frag_color = frag_color;
    return stage_output;
}
