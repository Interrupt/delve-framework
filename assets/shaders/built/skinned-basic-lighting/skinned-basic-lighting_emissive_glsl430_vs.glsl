#version 430

uniform vec4 vs_params[266];
layout(location = 6) in vec4 weights;
layout(location = 5) in vec4 joints;
layout(location = 0) out vec4 color;
layout(location = 1) out vec2 uv;
layout(location = 2) in vec2 texcoord0;
layout(location = 2) out vec3 normal;
layout(location = 3) in vec3 normals;
layout(location = 3) out vec4 tangent;
layout(location = 4) in vec4 tangents;
layout(location = 4) out vec4 position;
layout(location = 0) in vec4 pos;
layout(location = 5) out vec4 baseDiffuse;
layout(location = 1) in vec4 color0;

void main()
{
    mat4 _32 = mat4(vs_params[int(joints.x) * 4 + 9], vs_params[int(joints.x) * 4 + 10], vs_params[int(joints.x) * 4 + 11], vs_params[int(joints.x) * 4 + 12]) * weights.x;
    mat4 _41 = mat4(vs_params[int(joints.y) * 4 + 9], vs_params[int(joints.y) * 4 + 10], vs_params[int(joints.y) * 4 + 11], vs_params[int(joints.y) * 4 + 12]) * weights.y;
    mat4 _63 = mat4(vs_params[int(joints.z) * 4 + 9], vs_params[int(joints.z) * 4 + 10], vs_params[int(joints.z) * 4 + 11], vs_params[int(joints.z) * 4 + 12]) * weights.z;
    mat4 _85 = mat4(vs_params[int(joints.w) * 4 + 9], vs_params[int(joints.w) * 4 + 10], vs_params[int(joints.w) * 4 + 11], vs_params[int(joints.w) * 4 + 12]) * weights.w;
    mat4 _104 = mat4(vs_params[4], vs_params[5], vs_params[6], vs_params[7]) * mat4(((_32[0] + _41[0]) + _63[0]) + _85[0], ((_32[1] + _41[1]) + _63[1]) + _85[1], ((_32[2] + _41[2]) + _63[2]) + _85[2], ((_32[3] + _41[3]) + _63[3]) + _85[3]);
    color = vec4(0.0, 0.0, 0.0, 1.0);
    uv = texcoord0 + vs_params[265].xy;
    normal = normalize(_104 * vec4(normals, 0.0)).xyz;
    tangent = tangents;
    position = _104 * pos;
    baseDiffuse = color0 * vs_params[8];
    gl_Position = mat4(vs_params[0], vs_params[1], vs_params[2], vs_params[3]) * position;
}

