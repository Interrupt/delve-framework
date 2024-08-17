#version 300 es
precision mediump float;
precision highp int;

uniform highp vec4 fs_params[39];
uniform highp sampler2D tex_smp;
uniform highp sampler2D tex_emissive_smp;

in highp vec2 uv;
in highp vec4 color;
in highp vec4 position;
in highp vec3 normal;
layout(location = 0) out highp vec4 frag_color;
in highp vec4 tangent;

highp float sqr(highp float x)
{
    return x * x;
}

highp float attenuate_light(highp float _distance, highp float radius, highp float max_intensity, highp float falloff)
{
    highp float _27 = _distance / radius;
    if (_27 >= 1.0)
    {
        return 0.0;
    }
    highp float param = _27;
    highp float param_1 = 1.0 - sqr(param);
    return (max_intensity * sqr(param_1)) / (falloff * _27 + 1.0);
}

void main()
{
    highp vec4 _74 = texture(tex_smp, uv) * color;
    highp vec4 c = _74;
    highp vec4 lit_color = fs_params[3];
    if (_74.w <= fs_params[2].x)
    {
        discard;
    }
    for (int i = 0; i < int(fs_params[6].x); i++)
    {
        int _115 = i * 2;
        highp vec3 _138 = fs_params[_115 * 1 + 7].xyz - position.xyz;
        highp float param = length(_138);
        highp float param_1 = fs_params[_115 * 1 + 7].w;
        highp float param_2 = 1.0;
        highp float param_3 = 1.0;
        highp vec4 _168 = lit_color;
        highp vec3 _170 = _168.xyz + ((fs_params[(_115 + 1) * 1 + 7].xyz * max(dot(normalize(_138), normal), 0.0)) * attenuate_light(param, param_1, param_2, param_3));
        highp vec4 _282 = _168;
        _282.x = _170.x;
        _282.y = _170.y;
        _282.z = _170.z;
        lit_color = _282;
    }
    highp vec4 _211 = lit_color;
    highp vec3 _213 = _211.xyz + (fs_params[5].xyz * (max(dot(vec4(fs_params[4].x, fs_params[4].y, fs_params[4].z, 0.0), vec4(normal, 0.0)), 0.0) * fs_params[4].w));
    highp vec4 _288 = _211;
    _288.x = _213.x;
    _288.y = _213.y;
    _288.z = _213.z;
    lit_color = _288;
    highp vec4 _222 = c * _288;
    highp vec4 _229 = texture(tex_emissive_smp, uv);
    highp vec3 _247 = (_222.xyz * (1.0 - min((_229.x + _229.y) + _229.z, 1.0))) + _229.xyz;
    highp vec4 _297 = _222;
    _297.x = _247.x;
    _297.y = _247.y;
    _297.z = _247.z;
    highp vec3 _268 = (_297.xyz * (1.0 - fs_params[1].w)) + (fs_params[1].xyz * fs_params[1].w);
    highp vec4 _303 = _297;
    _303.x = _268.x;
    _303.y = _268.y;
    _303.z = _268.z;
    c = _303;
    frag_color = _303;
}

