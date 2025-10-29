diagnostic(off, derivative_uniformity);

alias Arr = array<vec4f, 32u>;

struct fs_params {
  /* @offset(0) */
  u_cameraPos : vec4f,
  /* @offset(16) */
  u_color_override : vec4f,
  /* @offset(32) */
  u_alpha_cutoff : f32,
  /* @offset(48) */
  u_ambient_light : vec4f,
  /* @offset(64) */
  u_dir_light_dir : vec4f,
  /* @offset(80) */
  u_dir_light_color : vec4f,
  /* @offset(96) */
  u_num_point_lights : f32,
  /* @offset(112) */
  u_point_light_data : Arr,
  /* @offset(624) */
  u_fog_data : vec4f,
  /* @offset(640) */
  u_fog_color : vec4f,
}

@binding(9) @group(0) var<uniform> x_63 : fs_params;

@binding(64) @group(1) var tex : texture_2d<f32>;

@binding(66) @group(1) var smp : sampler;

var<private> uv : vec2f;

var<private> baseDiffuse : vec4f;

var<private> position_1 : vec4f;

var<private> normal : vec3f;

@binding(65) @group(1) var tex_emissive : texture_2d<f32>;

var<private> frag_color : vec4f;

var<private> color : vec4f;

var<private> tangent : vec4f;

fn sqr_f1_(x : ptr<function, f32>) -> f32 {
  let x_22 = *(x);
  let x_23 = *(x);
  return (x_22 * x_23);
}

fn attenuate_light_f1_f1_f1_f1_(distance_1 : ptr<function, f32>, radius : ptr<function, f32>, max_intensity : ptr<function, f32>, falloff : ptr<function, f32>) -> f32 {
  var s : f32;
  var s2 : f32;
  var param : f32;
  var param_1 : f32;
  s = (*(distance_1) / *(radius));
  if ((s >= 1.0f)) {
    return 0.0f;
  }
  param = s;
  let x_42 = sqr_f1_(&(param));
  s2 = x_42;
  let x_43 = *(max_intensity);
  param_1 = (1.0f - s2);
  let x_47 = sqr_f1_(&(param_1));
  let x_49 = *(falloff);
  let x_50 = s;
  return ((x_43 * x_47) / (1.0f + (x_49 * x_50)));
}

fn calcFogFactor_f1_(distance_to_eye : ptr<function, f32>) -> f32 {
  var fog_start : f32;
  var fog_end : f32;
  var fog_amount : f32;
  var fog_factor : f32;
  fog_start = x_63.u_fog_data.x;
  fog_end = x_63.u_fog_data.y;
  fog_amount = x_63.u_fog_color.w;
  fog_factor = ((*(distance_to_eye) - fog_start) / (fog_end - fog_start));
  let x_87 = fog_factor;
  let x_88 = fog_amount;
  return clamp((x_87 * x_88), 0.0f, 1.0f);
}

fn main_1() {
  var c : vec4f;
  var lit_color : vec4f;
  var i : i32;
  var point_light_pos_data : vec4f;
  var point_light_color_data : vec4f;
  var lightPosEye : vec3f;
  var lightColor : vec3f;
  var lightMinusPos : vec3f;
  var lightDir : vec3f;
  var lightBrightness : f32;
  var dist : f32;
  var radius_1 : f32;
  var attenuation : f32;
  var param_2 : f32;
  var param_3 : f32;
  var param_4 : f32;
  var param_5 : f32;
  var lightDir_1 : vec4f;
  var lightColor_1 : vec4f;
  var lightBrightness_1 : f32;
  var e : vec4f;
  var e_amt : f32;
  var override_mod : f32;
  var fog_factor_1 : f32;
  var param_6 : f32;
  let x_108 = uv;
  let x_109 = textureSample(tex, smp, x_108);
  c = (x_109 * baseDiffuse);
  lit_color = x_63.u_ambient_light;
  if ((c.w <= x_63.u_alpha_cutoff)) {
    discard;
  }
  i = 0i;
  loop {
    if ((i < i32(x_63.u_num_point_lights))) {
    } else {
      break;
    }
    point_light_pos_data = x_63.u_point_light_data[(i * 2i)];
    point_light_color_data = x_63.u_point_light_data[((i * 2i) + 1i)];
    lightPosEye = point_light_pos_data.xyz;
    lightColor = point_light_color_data.xyz;
    lightMinusPos = (lightPosEye - position_1.xyz);
    lightDir = normalize(lightMinusPos);
    lightBrightness = max(dot(lightDir, normal), 0.0f);
    dist = length(lightMinusPos);
    radius_1 = point_light_pos_data.w;
    param_2 = dist;
    param_3 = radius_1;
    param_4 = 1.0f;
    param_5 = 1.0f;
    let x_192 = attenuate_light_f1_f1_f1_f1_(&(param_2), &(param_3), &(param_4), &(param_5));
    attenuation = x_192;
    let x_200 = (lit_color.xyz + ((lightColor * lightBrightness) * attenuation));
    lit_color.x = x_200.x;
    lit_color.y = x_200.y;
    lit_color.z = x_200.z;

    continuing {
      i = (i + 1i);
    }
  }
  lightDir_1 = vec4f(x_63.u_dir_light_dir.x, x_63.u_dir_light_dir.y, x_63.u_dir_light_dir.z, 0.0f);
  lightColor_1 = x_63.u_dir_light_color;
  lightBrightness_1 = (max(dot(lightDir_1, vec4f(normal.x, normal.y, normal.z, 0.0f)), 0.0f) * x_63.u_dir_light_dir.w);
  let x_241 = (lit_color.xyz + (lightColor_1.xyz * lightBrightness_1));
  lit_color.x = x_241.x;
  lit_color.y = x_241.y;
  lit_color.z = x_241.z;
  c = (c * lit_color);
  let x_256 = uv;
  let x_257 = textureSample(tex_emissive, smp, x_256);
  e = x_257;
  e_amt = min(((e.x + e.y) + e.z), 1.0f);
  let x_275 = ((c.xyz * (1.0f - e_amt)) + e.xyz);
  c.x = x_275.x;
  c.y = x_275.y;
  c.z = x_275.z;
  override_mod = (1.0f - x_63.u_color_override.w);
  let x_296 = ((c.xyz * override_mod) + (x_63.u_color_override.xyz * x_63.u_color_override.w));
  c.x = x_296.x;
  c.y = x_296.y;
  c.z = x_296.z;
  param_6 = length((x_63.u_cameraPos - position_1));
  let x_310 = calcFogFactor_f1_(&(param_6));
  fog_factor_1 = x_310;
  let x_320 = mix(c.xyz, x_63.u_fog_color.xyz, vec3f(fog_factor_1));
  frag_color = vec4f(x_320.x, x_320.y, x_320.z, 1.0f);
  return;
}

struct main_out {
  @location(0)
  frag_color_1 : vec4f,
}

@fragment
fn main(@location(1) uv_param : vec2f, @location(5) baseDiffuse_param : vec4f, @location(4) position_1_param : vec4f, @location(2) normal_param : vec3f, @location(0) color_param : vec4f, @location(3) tangent_param : vec4f) -> main_out {
  uv = uv_param;
  baseDiffuse = baseDiffuse_param;
  position_1 = position_1_param;
  normal = normal_param;
  color = color_param;
  tangent = tangent_param;
  main_1();
  return main_out(frag_color);
}
