diagnostic(off, derivative_uniformity);

alias Arr = array<mat4x4f, 64u>;

struct vs_params {
  /* @offset(0) */
  u_projViewMatrix : mat4x4f,
  /* @offset(64) */
  u_modelMatrix : mat4x4f,
  /* @offset(128) */
  u_color : vec4f,
  /* @offset(144) */
  u_joints : Arr,
  /* @offset(4240) */
  u_tex_pan : vec4f,
}

var<private> weights : vec4f;

@binding(0) @group(0) var<uniform> x_22 : vs_params;

var<private> joints : vec4f;

var<private> color : vec4f;

var<private> uv : vec2f;

var<private> texcoord0 : vec2f;

var<private> normal : vec3f;

var<private> normals : vec3f;

var<private> tangent : vec4f;

var<private> tangents : vec4f;

var<private> position_1 : vec4f;

var<private> pos : vec4f;

var<private> baseDiffuse : vec4f;

var<private> color0 : vec4f;

var<private> gl_Position : vec4f;

fn main_1() {
  var skin : mat4x4f;
  var model : mat4x4f;
  let x_32 = (x_22.u_joints[i32(joints.x)] * weights.x);
  let x_41 = (x_22.u_joints[i32(joints.y)] * weights.y);
  let x_54 = mat4x4f((x_32[0u] + x_41[0u]), (x_32[1u] + x_41[1u]), (x_32[2u] + x_41[2u]), (x_32[3u] + x_41[3u]));
  let x_63 = (x_22.u_joints[i32(joints.z)] * weights.z);
  let x_76 = mat4x4f((x_54[0u] + x_63[0u]), (x_54[1u] + x_63[1u]), (x_54[2u] + x_63[2u]), (x_54[3u] + x_63[3u]));
  let x_85 = (x_22.u_joints[i32(joints.w)] * weights.w);
  skin = mat4x4f((x_76[0u] + x_85[0u]), (x_76[1u] + x_85[1u]), (x_76[2u] + x_85[2u]), (x_76[3u] + x_85[3u]));
  model = (x_22.u_modelMatrix * skin);
  color = vec4f(0.0f, 0.0f, 0.0f, 1.0f);
  uv = (texcoord0 + x_22.u_tex_pan.xy);
  normal = normalize((model * vec4f(normals.x, normals.y, normals.z, 0.0f))).xyz;
  tangent = tangents;
  position_1 = (model * pos);
  baseDiffuse = (color0 * x_22.u_color);
  gl_Position = (x_22.u_projViewMatrix * position_1);
  return;
}

struct main_out {
  @location(0)
  color_1 : vec4f,
  @location(1)
  uv_1 : vec2f,
  @location(2)
  normal_1 : vec3f,
  @location(3)
  tangent_1 : vec4f,
  @location(4)
  position_1_1 : vec4f,
  @location(5)
  baseDiffuse_1 : vec4f,
  @builtin(position)
  gl_Position : vec4f,
}

@vertex
fn main(@location(6) weights_param : vec4f, @location(5) joints_param : vec4f, @location(2) texcoord0_param : vec2f, @location(3) normals_param : vec3f, @location(4) tangents_param : vec4f, @location(0) pos_param : vec4f, @location(1) color0_param : vec4f) -> main_out {
  weights = weights_param;
  joints = joints_param;
  texcoord0 = texcoord0_param;
  normals = normals_param;
  tangents = tangents_param;
  pos = pos_param;
  color0 = color0_param;
  main_1();
  return main_out(color, uv, normal, tangent, position_1, baseDiffuse, gl_Position);
}
