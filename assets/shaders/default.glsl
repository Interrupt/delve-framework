//------------------------------------------------------------------------------
//  Shader code for the built in default shader.
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
    vec4 u_tex_pan;
};

in vec4 pos;
in vec4 color0;
in vec2 texcoord0;

out vec4 color;
out vec2 uv;

void main() {
    gl_Position = u_projViewMatrix * u_modelMatrix * pos;
    color = color0 * u_color;
    uv = texcoord0 + u_tex_pan.xy;
}
#pragma sokol @end

#pragma sokol @fs fs
uniform texture2D tex;
uniform sampler smp;
uniform fs_params {
    vec4 u_color_override;
    float u_alpha_cutoff;
};

in vec4 color;
in vec2 uv;
out vec4 frag_color;

void main() {
    vec4 c = texture(sampler2D(tex, smp), uv) * color;

    // to make sprite drawing easier, discard full alpha pixels
    if(c.a <= u_alpha_cutoff) {
        discard;
    }

    // to also make sprite flash effects easier, allow a color to take over the final output
    float override_mod = 1.0 - u_color_override.a;
    c.rgb = (c.rgb * override_mod) + (u_color_override.rgb * u_color_override.a);

    frag_color = c;
}
#pragma sokol @end

#pragma sokol @program default vs fs
