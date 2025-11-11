diagnostic(off, derivative_uniformity);

struct fs_params {
  /* @offset(0) */
  u_color_override : vec4f,
  /* @offset(16) */
  u_alpha_cutoff : f32,
}

@binding(64) @group(1) var tex : texture_2d<f32>;

@binding(65) @group(1) var smp : sampler;

var<private> uv : vec2f;

var<private> color : vec4f;

@binding(9) @group(0) var<uniform> x_36 : fs_params;

var<private> frag_color : vec4f;

fn main_1() {
  var c : vec4f;
  var override_mod : f32;
  let x_23 = uv;
  let x_24 = textureSample(tex, smp, x_23);
  c = (x_24 * color);
  if ((c.w <= x_36.u_alpha_cutoff)) {
    discard;
  }
  override_mod = (1.0f - x_36.u_color_override.w);
  let x_65 = ((c.xyz * override_mod) + (x_36.u_color_override.xyz * x_36.u_color_override.w));
  c.x = x_65.x;
  c.y = x_65.y;
  c.z = x_65.z;
  frag_color = c;
  return;
}

struct main_out {
  @location(0)
  frag_color_1 : vec4f,
}

@fragment
fn main(@location(1) uv_param : vec2f, @location(0) color_param : vec4f) -> main_out {
  uv = uv_param;
  color = color_param;
  main_1();
  return main_out(frag_color);
}
