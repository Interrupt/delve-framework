cbuffer vs_params : register(b0)
{
    row_major float4x4 _22_u_projViewMatrix : packoffset(c0);
    row_major float4x4 _22_u_modelMatrix : packoffset(c4);
    float4 _22_u_color : packoffset(c8);
    row_major float4x4 _22_u_joints[64] : packoffset(c9);
};


static float4 gl_Position;
static float4 weights;
static float4 joints;
static float4 color;
static float2 uv;
static float2 texcoord0;
static float3 normal;
static float3 normals;
static float4 tangent;
static float4 tangents;
static float4 position;
static float4 pos;
static float4 baseDiffuse;
static float4 color0;

struct SPIRV_Cross_Input
{
    float4 pos : TEXCOORD0;
    float4 color0 : TEXCOORD1;
    float2 texcoord0 : TEXCOORD2;
    float3 normals : TEXCOORD3;
    float4 tangents : TEXCOORD4;
    float4 joints : TEXCOORD5;
    float4 weights : TEXCOORD6;
};

struct SPIRV_Cross_Output
{
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    float3 normal : TEXCOORD2;
    float4 tangent : TEXCOORD3;
    float4 position : TEXCOORD4;
    float4 baseDiffuse : TEXCOORD5;
    float4 gl_Position : SV_Position;
};

void vert_main()
{
    float4x4 _32 = _22_u_joints[int(joints.x)] * weights.x;
    float4x4 _41 = _22_u_joints[int(joints.y)] * weights.y;
    float4x4 _63 = _22_u_joints[int(joints.z)] * weights.z;
    float4x4 _85 = _22_u_joints[int(joints.w)] * weights.w;
    float4x4 _104 = mul(float4x4(((_32[0] + _41[0]) + _63[0]) + _85[0], ((_32[1] + _41[1]) + _63[1]) + _85[1], ((_32[2] + _41[2]) + _63[2]) + _85[2], ((_32[3] + _41[3]) + _63[3]) + _85[3]), _22_u_modelMatrix);
    color = float4(0.0f, 0.0f, 0.0f, 1.0f);
    uv = texcoord0;
    normal = normalize(mul(float4(normals, 0.0f), _104)).xyz;
    tangent = tangents;
    position = mul(pos, _104);
    baseDiffuse = color0 * _22_u_color;
    gl_Position = mul(position, _22_u_projViewMatrix);
}

SPIRV_Cross_Output main(SPIRV_Cross_Input stage_input)
{
    weights = stage_input.weights;
    joints = stage_input.joints;
    texcoord0 = stage_input.texcoord0;
    normals = stage_input.normals;
    tangents = stage_input.tangents;
    pos = stage_input.pos;
    color0 = stage_input.color0;
    vert_main();
    SPIRV_Cross_Output stage_output;
    stage_output.gl_Position = gl_Position;
    stage_output.color = color;
    stage_output.uv = uv;
    stage_output.normal = normal;
    stage_output.tangent = tangent;
    stage_output.position = position;
    stage_output.baseDiffuse = baseDiffuse;
    return stage_output;
}
