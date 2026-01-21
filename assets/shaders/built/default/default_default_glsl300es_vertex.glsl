#version 300 es

uniform vec4 vs_params[10];
layout(location = 0) in vec4 pos;
out vec4 color;
layout(location = 1) in vec4 color0;
out vec2 uv;
layout(location = 2) in vec2 texcoord0;

void main()
{
    gl_Position = (mat4(vs_params[0], vs_params[1], vs_params[2], vs_params[3]) * mat4(vs_params[4], vs_params[5], vs_params[6], vs_params[7])) * pos;
    color = color0 * vs_params[8];
    uv = texcoord0 + vs_params[9].xy;
}

