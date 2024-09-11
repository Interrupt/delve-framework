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

struct SPIRV_Cross_Input
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float3 normal : TEXCOORD2;
    float4 tangent : TEXCOORD3;
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
    float4 _117 = _69;
    _117.x = _76.x;
    _117.y = _76.y;
    _117.z = _76.z;
    float3 _99 = (_117.xyz * (1.0f - _36_u_color_override.w)) + (_36_u_color_override.xyz * _36_u_color_override.w);
    float4 _123 = _117;
    _123.x = _99.x;
    _123.y = _99.y;
    _123.z = _99.z;
    c = _123;
    frag_color = _123;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    uv = stage_input.uv;
    color = stage_input.color;
    normal = stage_input.normal;
    tangent = stage_input.tangent;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.frag_color = frag_color;
    return stage_output;
}
