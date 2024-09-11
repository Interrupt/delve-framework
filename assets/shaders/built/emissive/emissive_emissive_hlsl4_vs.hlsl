cbuffer vs_params : register(b0)
{
    row_major float4x4 _19_u_projViewMatrix : packoffset(c0);
    row_major float4x4 _19_u_modelMatrix : packoffset(c4);
    float4 _19_u_color : packoffset(c8);
};


static float4 gl_Position;
static float4 pos;
static float4 color;
static float4 color0;
static float2 uv;
static float2 texcoord0;
static float3 normal;
static float3 normals;
static float4 tangent;
static float4 tangents;

struct SPIRV_Cross_Input
{
    float4 pos : TEXCOORD0;
    float4 color0 : TEXCOORD1;
    float2 texcoord0 : TEXCOORD2;
    float3 normals : TEXCOORD3;
    float4 tangents : TEXCOORD4;
};

struct SPIRV_Cross_Output
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float3 normal : TEXCOORD2;
    float4 tangent : TEXCOORD3;
    float4 gl_Position : SV_Position;
};

void vert_main()
{
    gl_Position = mul(pos, mul(_19_u_modelMatrix, _19_u_projViewMatrix));
    color = color0 * _19_u_color;
    uv = texcoord0;
    normal = normals;
    tangent = tangents;
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    pos = stage_input.pos;
    color0 = stage_input.color0;
    texcoord0 = stage_input.texcoord0;
    normals = stage_input.normals;
    tangents = stage_input.tangents;
    vert_main();
    SPIRV_Cross_Output stage_output;
    stage_output.gl_Position = gl_Position;
    stage_output.color = color;
    stage_output.uv = uv;
    stage_output.normal = normal;
    stage_output.tangent = tangent;
    return stage_output;
}
