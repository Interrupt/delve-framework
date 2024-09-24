//------------------------------------------------------------------------------
//  Shader code for the built in default shader, plus an emissive term.
//
//  NOTE: This source file also uses the '#pragma sokol' form of the
//  custom tags.
//------------------------------------------------------------------------------
#pragma sokol @header const m = @import("../../math.zig")
#pragma sokol @ctype mat4 m.Mat4

#pragma sokol @vs vs
uniform vs_params {
    mat4 u_projViewMatrix;
    mat4 u_modelMatrix;
    vec4 u_color;
    mat4 u_joints[64];
    vec4 u_tex_pan;
};

in vec4 pos;
in vec4 color0;
in vec2 texcoord0;
in vec3 normals;
in vec4 tangents;
in vec4 joints;
in vec4 weights;

out vec4 color;
out vec2 uv;
out vec3 normal;
out vec4 tangent;
out vec4 position;
out vec4 baseDiffuse;

void main() {
    mat4 skin = (weights.x * u_joints[int(joints.x)] +
                weights.y * u_joints[int(joints.y)] +
                weights.z * u_joints[int(joints.z)] +
                weights.w * u_joints[int(joints.w)]);

    mat4 model = u_modelMatrix * skin;

    color = vec4(0.0, 0.0, 0.0, 1.0);
    uv = texcoord0 + u_tex_pan.xy;
    normal = normalize(model * vec4(normals, 0.0)).xyz;
    tangent = tangents;
    position = model * pos;
    baseDiffuse = color0 * u_color;

    gl_Position = u_projViewMatrix * position;

}
#pragma sokol @end

#pragma sokol @fs fs
uniform texture2D tex;
uniform texture2D tex_emissive;
uniform sampler smp;
uniform fs_params {
    vec4 u_cameraPos;
    vec4 u_color_override;
    float u_alpha_cutoff;
    vec4 u_ambient_light;
    vec4 u_dir_light_dir;
    vec4 u_dir_light_color;
    float u_num_point_lights;
    vec4 u_point_light_data[32]; // each light is packed as two vec4s
    vec4 u_fog_data; // x is start, y is end, z and w are unused so far
    vec4 u_fog_color; // fog color rgb, and a is fog amount
};

in vec4 color;
in vec2 uv;
in vec3 normal;
in vec4 tangent;
in vec4 position;
in vec4 baseDiffuse;
out vec4 frag_color;

float sqr(float x)
{
    return x * x;
}

// light attenuation function from https://lisyarus.github.io/blog/posts/point-light-attenuation.html
float attenuate_light(float distance, float radius, float max_intensity, float falloff)
{
    float s = distance / radius;

    if (s >= 1.0)
        return 0.0;

    float s2 = sqr(s);

    return max_intensity * sqr(1 - s2) / (1 + falloff * s);
}

float calcFogFactor(float distance_to_eye)
{
    float fog_start = u_fog_data.x;
    float fog_end = u_fog_data.y;
    float fog_amount = u_fog_color.a;
    float fog_factor = (distance_to_eye - fog_start) / (fog_end - fog_start);
    return clamp(fog_factor * fog_amount, 0.0, 1.0);
}

void main() {
    vec4 c = texture(sampler2D(tex, smp), uv) * baseDiffuse;
    vec4 lit_color = u_ambient_light;

    // to make sprite drawing easier, discard full alpha pixels
    if(c.a <= u_alpha_cutoff) {
        discard;
    }

    // simple lighting!
    for(int i = 0; i < int(u_num_point_lights); ++i) {
        vec4 point_light_pos_data = u_point_light_data[i * 2];
        vec4 point_light_color_data = u_point_light_data[(i * 2) + 1];

        vec3 lightPosEye = point_light_pos_data.xyz;
        vec3 lightColor = point_light_color_data.xyz;

        vec3 lightMinusPos = (lightPosEye - position.xyz);
        vec3 lightDir = normalize(lightMinusPos);
        float lightBrightness = max(dot( lightDir, normal), 0.0);

        float dist = length(lightMinusPos);
        float radius = point_light_pos_data.w;
        float attenuation = attenuate_light(dist, radius, 1.0, 1.0);
        lit_color.rgb += (lightBrightness * lightColor * attenuation);
    }

    {
        // directional light
        vec4 lightDir = vec4(u_dir_light_dir.x, u_dir_light_dir.y, u_dir_light_dir.z, 0.0);
        vec4 lightColor = u_dir_light_color;
        float lightBrightness = max(dot( lightDir, vec4(normal, 0.0)), 0.0) * u_dir_light_dir.w;
        lit_color.rgb += (lightBrightness * lightColor.rgb);
    }

    // apply lighting color on top of the base diffuse color
    c *= lit_color;

    // add the emissive term
    vec4 e = texture(sampler2D(tex_emissive, smp), uv);

    float e_amt = min(e.r + e.g + e.b, 1.0);
    c.rgb = (c.rgb * (1.0 - e_amt)) + (e.rgb);

    // for flash effects, allow a color to take over the final output
    float override_mod = 1.0 - u_color_override.a;
    c.rgb = (c.rgb * override_mod) + (u_color_override.rgb * u_color_override.a);

    // finally, add fog
    float fog_factor = calcFogFactor(length(u_cameraPos - position));

    frag_color = vec4(mix(c.rgb, u_fog_color.rgb, fog_factor), 1.0);
}
#pragma sokol @end

#pragma sokol @program emissive vs fs
