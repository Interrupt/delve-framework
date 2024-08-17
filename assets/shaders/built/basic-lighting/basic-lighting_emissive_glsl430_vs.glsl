#version 430

uniform vec4 vs_params[9];
layout(location = 0) out vec4 color;
layout(location = 1) in vec4 color0;
layout(location = 1) out vec2 uv;
layout(location = 2) in vec2 texcoord0;
layout(location = 2) out vec3 normal;
layout(location = 3) in vec3 normals;
layout(location = 3) out vec4 tangent;
layout(location = 4) in vec4 tangents;
layout(location = 4) out vec4 position;
layout(location = 0) in vec4 pos;

void main()
{
    color = color0 * vs_params[8];
    uv = texcoord0;
    mat4 _35 = mat4(vs_params[4], vs_params[5], vs_params[6], vs_params[7]);
    normal = normalize(_35 * vec4(normals, 0.0)).xyz;
    tangent = tangents;
    position = _35 * pos;
    gl_Position = mat4(vs_params[0], vs_params[1], vs_params[2], vs_params[3]) * position;
}

