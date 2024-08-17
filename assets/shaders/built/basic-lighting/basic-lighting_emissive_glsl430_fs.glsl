#version 430

uniform vec4 fs_params[39];
layout(binding = 0) uniform sampler2D tex_smp;
layout(binding = 1) uniform sampler2D tex_emissive_smp;

layout(location = 1) in vec2 uv;
layout(location = 0) in vec4 color;
layout(location = 4) in vec4 position;
layout(location = 2) in vec3 normal;
layout(location = 0) out vec4 frag_color;
layout(location = 3) in vec4 tangent;

float sqr(float x)
{
    return x * x;
}

float attenuate_light(float _distance, float radius, float max_intensity, float falloff)
{
    float _27 = _distance / radius;
    if (_27 >= 1.0)
    {
        return 0.0;
    }
    float param = _27;
    float param_1 = 1.0 - sqr(param);
    return (max_intensity * sqr(param_1)) / fma(falloff, _27, 1.0);
}

void main()
{
    vec4 _74 = texture(tex_smp, uv) * color;
    vec4 c = _74;
    vec4 lit_color = fs_params[3];
    if (_74.w <= fs_params[2].x)
    {
        discard;
    }
    for (int i = 0; i < int(fs_params[6].x); i++)
    {
        int _115 = i * 2;
        vec3 _138 = fs_params[_115 * 1 + 7].xyz - position.xyz;
        float param = length(_138);
        float param_1 = fs_params[_115 * 1 + 7].w;
        float param_2 = 1.0;
        float param_3 = 1.0;
        vec4 _168 = lit_color;
        vec3 _170 = _168.xyz + ((fs_params[(_115 + 1) * 1 + 7].xyz * max(dot(normalize(_138), normal), 0.0)) * attenuate_light(param, param_1, param_2, param_3));
        vec4 _282 = _168;
        _282.x = _170.x;
        _282.y = _170.y;
        _282.z = _170.z;
        lit_color = _282;
    }
    vec4 _211 = lit_color;
    vec3 _213 = _211.xyz + (fs_params[5].xyz * (max(dot(vec4(fs_params[4].x, fs_params[4].y, fs_params[4].z, 0.0), vec4(normal, 0.0)), 0.0) * fs_params[4].w));
    vec4 _288 = _211;
    _288.x = _213.x;
    _288.y = _213.y;
    _288.z = _213.z;
    lit_color = _288;
    vec4 _222 = c * _288;
    vec4 _229 = texture(tex_emissive_smp, uv);
    vec3 _247 = (_222.xyz * (1.0 - min((_229.x + _229.y) + _229.z, 1.0))) + _229.xyz;
    vec4 _297 = _222;
    _297.x = _247.x;
    _297.y = _247.y;
    _297.z = _247.z;
    vec3 _268 = (_297.xyz * (1.0 - fs_params[1].w)) + (fs_params[1].xyz * fs_params[1].w);
    vec4 _303 = _297;
    _303.x = _268.x;
    _303.y = _268.y;
    _303.z = _268.z;
    c = _303;
    frag_color = _303;
}

