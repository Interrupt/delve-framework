cbuffer fs_params : register(b0)
{
    float4 _36_u_color_override : packoffset(c0);
    float _36_u_alpha_cutoff : packoffset(c1);
};

Texture2D<float4> tex : register(t0);
SamplerState smp : register(s0);

static float2 uv;
static float4 color;
static float4 frag_color;

struct SPIRV_Cross_Input
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
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
    float4 _54 = c;
    float3 _65 = (_54.xyz * (1.0f - _36_u_color_override.w)) + (_36_u_color_override.xyz * _36_u_color_override.w);
    float4 _80 = _54;
    _80.x = _65.x;
    _80.y = _65.y;
    _80.z = _65.z;
    c = _80;
    frag_color = _80;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    uv = stage_input.uv;
    color = stage_input.color;
    frag_main();
    SPIRV_Cross_Output stage_output;
    stage_output.frag_color = frag_color;
    return stage_output;
}
