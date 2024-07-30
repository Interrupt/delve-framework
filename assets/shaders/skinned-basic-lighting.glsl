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
    uv = texcoord0;
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
    vec4 u_dir_light_dir;
    vec4 u_dir_light_color;
    float u_num_point_lights;
    vec4 u_point_light_positions[8];
    vec4 u_point_light_colors[8];
};

in vec4 color;
in vec2 uv;
in vec3 normal;
in vec4 tangent;
in vec4 position;
in vec4 baseDiffuse;
out vec4 frag_color;

void main() {
    vec4 c = texture(sampler2D(tex, smp), uv) * baseDiffuse;
    vec4 lit_color = color;

    // to make sprite drawing easier, discard full alpha pixels
    if(c.a <= u_alpha_cutoff) {
        discard;
    }

    // simple lighting!
    for(int i = 0; i < int(u_num_point_lights); ++i) {
        vec3 lightPosEye = u_point_light_positions[i].xyz;
        vec3 lightColor = u_point_light_colors[i].xyz;

        vec3 lightMinusPos = (lightPosEye - position.xyz);
        vec3 lightDir = normalize(lightMinusPos);
        float lightBrightness = max(dot( lightDir, normal), 0.0) * u_point_light_colors[i].a;

        float dist = length(lightMinusPos);
        float radius = u_point_light_positions[i].w;
        float attenuation = clamp(1.0 - dist/radius, 0.0, 1.0);

        // testing out a specular term
        vec3 cameraLocN = vec3(normalize(u_cameraPos));
        vec3 reflectAmt = normalize(reflect(-vec3(lightPosEye), normal));
        float specularAmt = max(0.0, dot(cameraLocN, reflectAmt));
        specularAmt = pow(specularAmt, 50.0);

        lit_color.rgb += (lightBrightness * lightColor * attenuation) + (specularAmt * normalize(lightColor));
    }

    {
        // directional light
        vec4 lightDir = vec4(u_dir_light_dir.x, u_dir_light_dir.y, u_dir_light_dir.z, 0.0);
        vec4 lightColor = u_dir_light_color;

        float lightBrightness = max(dot( lightDir, vec4(normal, 0.0)), 0.0) * u_dir_light_dir.w;

        // testing out a specular term
        vec3 cameraLocN = vec3(normalize(u_cameraPos));
        vec3 reflectAmt = normalize(reflect(vec3(-lightDir), normal));
        float specularAmt = max(0.0, dot(cameraLocN, reflectAmt));
        specularAmt = pow(specularAmt, 30.0);

        lit_color.rgb += (lightBrightness * lightColor.rgb) + (specularAmt * lightColor.rgb);
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

    frag_color = c;
}
#pragma sokol @end

#pragma sokol @program emissive vs fs
