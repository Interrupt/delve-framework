diagnostic(off, derivative_uniformity);

struct vs_params {
  /* @offset(0) */
  u_projViewMatrix : mat4x4f,
  /* @offset(64) */
  u_modelMatrix : mat4x4f,
  /* @offset(128) */
  u_color : vec4f,
  /* @offset(144) */
  u_tex_pan : vec4f,
}

@binding(0) @group(0) var<uniform> x_19 : vs_params;

var<private> pos : vec4f;

var<private> color : vec4f;

var<private> color0 : vec4f;

var<private> uv : vec2f;

var<private> texcoord0 : vec2f;

var<private> normals : vec3f;

var<private> tangents : vec4f;

var<private> gl_Position : vec4f;

fn main_1() {
  gl_Position = ((x_19.u_projViewMatrix * x_19.u_modelMatrix) * pos);
  color = (color0 * x_19.u_color);
  uv = (texcoord0 + x_19.u_tex_pan.xy);
  return;
}

struct main_out {
  @builtin(position)
  gl_Position : vec4f,
  @location(0)
  color_1 : vec4f,
  @location(1)
  uv_1 : vec2f,
}

@vertex
fn main(@location(0) pos_param : vec4f, @location(1) color0_param : vec4f, @location(2) texcoord0_param : vec2f, @location(3) normals_param : vec3f, @location(4) tangents_param : vec4f) -> main_out {
  pos = pos_param;
  color0 = color0_param;
  texcoord0 = texcoord0_param;
  normals = normals_param;
  tangents = tangents_param;
  main_1();
  return main_out(gl_Position, color, uv);
}
