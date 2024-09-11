#version 430

uniform vec4 fs_params[2];
layout(binding = 0) uniform sampler2D tex_smp;

layout(location = 1) in vec2 uv;
layout(location = 0) in vec4 color;
layout(location = 0) out vec4 frag_color;

void main()
{
    vec4 _28 = texture(tex_smp, uv) * color;
    vec4 c = _28;
    if (_28.w <= fs_params[1].x)
    {
        discard;
    }
    vec4 _54 = c;
    vec3 _65 = (_54.xyz * (1.0 - fs_params[0].w)) + (fs_params[0].xyz * fs_params[0].w);
    vec4 _80 = _54;
    _80.x = _65.x;
    _80.y = _65.y;
    _80.z = _65.z;
    c = _80;
    frag_color = _80;
}

