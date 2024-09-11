#version 300 es
precision mediump float;
precision highp int;

uniform highp vec4 fs_params[2];
uniform highp sampler2D tex_smp;

in highp vec2 uv;
in highp vec4 color;
layout(location = 0) out highp vec4 frag_color;

void main()
{
    highp vec4 _28 = texture(tex_smp, uv) * color;
    highp vec4 c = _28;
    if (_28.w <= fs_params[1].x)
    {
        discard;
    }
    highp vec4 _54 = c;
    highp vec3 _65 = (_54.xyz * (1.0 - fs_params[0].w)) + (fs_params[0].xyz * fs_params[0].w);
    highp vec4 _80 = _54;
    _80.x = _65.x;
    _80.y = _65.y;
    _80.z = _65.z;
    c = _80;
    frag_color = _80;
}

