for shader in basic-lighting default-mesh default emissive skinned-basic-lighting skinned; do
  tools/sokol-shdc -i assets/shaders/$shader.glsl -o src/framework/graphics/shaders/$shader.glsl.zig -l glsl300es:glsl430:wgsl:metal_macos:metal_ios:metal_sim:hlsl4 -f sokol_zig --reflection
done