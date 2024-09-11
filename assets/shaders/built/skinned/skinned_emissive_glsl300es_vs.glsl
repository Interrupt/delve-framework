#version 300 es

uniform vec4 vs_params[265];
layout(location = 6) in vec4 weights;
layout(location = 5) in vec4 joints;
layout(location = 0) in vec4 pos;
out vec4 color;
layout(location = 1) in vec4 color0;
out vec2 uv;
layout(location = 2) in vec2 texcoord0;
out vec3 normal;
layout(location = 3) in vec3 normals;
out vec4 tangent;
layout(location = 4) in vec4 tangents;
out vec4 joint;
out vec4 weight;

void main()
{
    mat4 _32 = mat4(vs_params[int(joints.x) * 4 + 9], vs_params[int(joints.x) * 4 + 10], vs_params[int(joints.x) * 4 + 11], vs_params[int(joints.x) * 4 + 12]) * weights.x;
    mat4 _41 = mat4(vs_params[int(joints.y) * 4 + 9], vs_params[int(joints.y) * 4 + 10], vs_params[int(joints.y) * 4 + 11], vs_params[int(joints.y) * 4 + 12]) * weights.y;
    mat4 _63 = mat4(vs_params[int(joints.z) * 4 + 9], vs_params[int(joints.z) * 4 + 10], vs_params[int(joints.z) * 4 + 11], vs_params[int(joints.z) * 4 + 12]) * weights.z;
    mat4 _85 = mat4(vs_params[int(joints.w) * 4 + 9], vs_params[int(joints.w) * 4 + 10], vs_params[int(joints.w) * 4 + 11], vs_params[int(joints.w) * 4 + 12]) * weights.w;
    gl_Position = (mat4(vs_params[0], vs_params[1], vs_params[2], vs_params[3]) * (mat4(vs_params[4], vs_params[5], vs_params[6], vs_params[7]) * mat4(((_32[0] + _41[0]) + _63[0]) + _85[0], ((_32[1] + _41[1]) + _63[1]) + _85[1], ((_32[2] + _41[2]) + _63[2]) + _85[2], ((_32[3] + _41[3]) + _63[3]) + _85[3]))) * pos;
    color = color0 * vs_params[8];
    uv = texcoord0;
    normal = normals;
    tangent = tangents;
    joint = joints;
    weight = weights;
}

