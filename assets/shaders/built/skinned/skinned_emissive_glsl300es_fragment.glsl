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
in highp vec4 joint;
in highp vec4 weight;

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
    highp vec4 _119 = _69;
    _119.x = _76.x;
    _119.y = _76.y;
    _119.z = _76.z;
    highp vec3 _99 = (_119.xyz * (1.0 - fs_params[0].w)) + (fs_params[0].xyz * fs_params[0].w);
    highp vec4 _125 = _119;
    _125.x = _99.x;
    _125.y = _99.y;
    _125.z = _99.z;
    c = _125;
    frag_color = _125;
}

