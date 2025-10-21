#version 300 es
precision mediump float;
precision highp int;

uniform highp vec4 fs_params[2];
uniform highp sampler2D tex_smp;
uniform highp sampler2D tex_emissive_smp;

in highp vec2 uv;
in highp vec4 color;
layout(location = 0) out highp vec4 frag_color;
in highp vec3 normal;
in highp vec4 tangent;

void main()
{
    highp vec4 _28 = texture(tex_smp, uv) * color;
    highp vec4 c = _28;
    if (_28.w <= fs_params[1].x)
    {
        discard;
    }
    highp vec4 _53 = texture(tex_emissive_smp, uv);
    highp vec4 _69 = c;
    highp vec3 _76 = (_69.xyz * (1.0 - min((_53.x + _53.y) + _53.z, 1.0))) + _53.xyz;
    highp vec4 _117 = _69;
    _117.x = _76.x;
    _117.y = _76.y;
    _117.z = _76.z;
    highp vec3 _99 = (_117.xyz * (1.0 - fs_params[0].w)) + (fs_params[0].xyz * fs_params[0].w);
    highp vec4 _123 = _117;
    _123.x = _99.x;
    _123.y = _99.y;
    _123.z = _99.z;
    c = _123;
    frag_color = _123;
}

