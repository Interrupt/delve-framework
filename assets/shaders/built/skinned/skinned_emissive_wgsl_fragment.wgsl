diagnostic(off, derivative_uniformity);

struct fs_params {
  /* @offset(0) */
  u_color_override : vec4f,
  /* @offset(16) */
  u_alpha_cutoff : f32,
}

@binding(64) @group(1) var tex : texture_2d<f32>;

@binding(66) @group(1) var smp : sampler;

var<private> uv : vec2f;

var<private> color : vec4f;

@binding(9) @group(0) var<uniform> x_36 : fs_params;

@binding(65) @group(1) var tex_emissive : texture_2d<f32>;

var<private> frag_color : vec4f;

var<private> normal : vec3f;

var<private> tangent : vec4f;

var<private> joint : vec4f;

var<private> weight : vec4f;

fn main_1() {
  var c : vec4f;
  var e : vec4f;
  var e_amt : f32;
  var override_mod : f32;
  let x_23 = uv;
  let x_24 = textureSample(tex, smp, x_23);
  c = (x_24 * color);
  if ((c.w <= x_36.u_alpha_cutoff)) {
    discard;
  }
  let x_52 = uv;
  let x_53 = textureSample(tex_emissive, smp, x_52);
  e = x_53;
  e_amt = min(((e.x + e.y) + e.z), 1.0f);
  let x_76 = ((c.xyz * (1.0f - e_amt)) + e.xyz);
  c.x = x_76.x;
  c.y = x_76.y;
  c.z = x_76.z;
  override_mod = (1.0f - x_36.u_color_override.w);
  let x_99 = ((c.xyz * override_mod) + (x_36.u_color_override.xyz * x_36.u_color_override.w));
  c.x = x_99.x;
  c.y = x_99.y;
  c.z = x_99.z;
  frag_color = c;
  return;
}

struct main_out {
  @location(0)
  frag_color_1 : vec4f,
}

@fragment
fn main(@location(1) uv_param : vec2f, @location(0) color_param : vec4f, @location(2) normal_param : vec3f, @location(3) tangent_param : vec4f, @location(4) joint_param : vec4f, @location(5) weight_param : vec4f) -> main_out {
  uv = uv_param;
  color = color_param;
  normal = normal_param;
  tangent = tangent_param;
  joint = joint_param;
  weight = weight_param;
  main_1();
  return main_out(frag_color);
}
