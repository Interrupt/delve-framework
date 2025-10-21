#version 430

uniform vec4 fs_params[41];
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
    float _30 = _distance / radius;
    if (_30 >= 1.0)
    {
        return 0.0;
    }
    float param = _30;
    float param_1 = 1.0 - sqr(param);
    return (max_intensity * sqr(param_1)) / fma(falloff, _30, 1.0);
}

float calcFogFactor(float distance_to_eye)
{
    return clamp(((distance_to_eye - fs_params[39].x) / (fs_params[39].y - fs_params[39].x)) * fs_params[40].w, 0.0, 1.0);
}

void main()
{
    vec4 _113 = texture(tex_smp, uv) * color;
    vec4 c = _113;
    vec4 lit_color = fs_params[3];
    if (_113.w <= fs_params[2].x)
    {
        discard;
    }
    for (int i = 0; i < int(fs_params[6].x); i++)
    {
        int _145 = i * 2;
        vec3 _168 = fs_params[_145 * 1 + 7].xyz - position.xyz;
        float param = length(_168);
        float param_1 = fs_params[_145 * 1 + 7].w;
        float param_2 = 1.0;
        float param_3 = 1.0;
        vec4 _198 = lit_color;
        vec3 _200 = _198.xyz + ((fs_params[(_145 + 1) * 1 + 7].xyz * max(dot(normalize(_168), normal), 0.0)) * attenuate_light(param, param_1, param_2, param_3));
        vec4 _329 = _198;
        _329.x = _200.x;
        _329.y = _200.y;
        _329.z = _200.z;
        lit_color = _329;
    }
    vec4 _239 = lit_color;
    vec3 _241 = _239.xyz + (fs_params[5].xyz * (max(dot(vec4(fs_params[4].x, fs_params[4].y, fs_params[4].z, 0.0), vec4(normal, 0.0)), 0.0) * fs_params[4].w));
    vec4 _335 = _239;
    _335.x = _241.x;
    _335.y = _241.y;
    _335.z = _241.z;
    lit_color = _335;
    vec4 _250 = c * _335;
    vec4 _257 = texture(tex_emissive_smp, uv);
    vec3 _275 = (_250.xyz * (1.0 - min((_257.x + _257.y) + _257.z, 1.0))) + _257.xyz;
    vec4 _344 = _250;
    _344.x = _275.x;
    _344.y = _275.y;
    _344.z = _275.z;
    vec3 _296 = (_344.xyz * (1.0 - fs_params[1].w)) + (fs_params[1].xyz * fs_params[1].w);
    vec4 _350 = _344;
    _350.x = _296.x;
    _350.y = _296.y;
    _350.z = _296.z;
    c = _350;
    float param_4 = length(fs_params[0] - position);
    frag_color = vec4(mix(c.xyz, fs_params[40].xyz, vec3(calcFogFactor(param_4))), 1.0);
}

