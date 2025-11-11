#version 430

uniform vec4 fs_params[2];
layout(binding = 0) uniform sampler2D tex_smp;
layout(binding = 1) uniform sampler2D tex_emissive_smp;

layout(location = 1) in vec2 uv;
layout(location = 0) in vec4 color;
layout(location = 0) out vec4 frag_color;
layout(location = 2) in vec3 normal;
layout(location = 3) in vec4 tangent;

void main()
{
    vec4 _28 = texture(tex_smp, uv) * color;
    vec4 c = _28;
    if (_28.w <= fs_params[1].x)
    {
        discard;
    }
    vec4 _53 = texture(tex_emissive_smp, uv);
    vec4 _69 = c;
    vec3 _76 = (_69.xyz * (1.0 - min((_53.x + _53.y) + _53.z, 1.0))) + _53.xyz;
    vec4 _117 = _69;
    _117.x = _76.x;
    _117.y = _76.y;
    _117.z = _76.z;
    vec3 _99 = (_117.xyz * (1.0 - fs_params[0].w)) + (fs_params[0].xyz * fs_params[0].w);
    vec4 _123 = _117;
    _123.x = _99.x;
    _123.y = _99.y;
    _123.z = _99.z;
    c = _123;
    frag_color = _123;
}

