const std = @import("std");
const delve = @import("delve");
const app = delve.app;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// easy access to some imports
const cam = delve.graphics.camera;
const colors = delve.colors;
const debug = delve.debug;
const graphics = delve.platform.graphics;
const images = delve.images;
const input = delve.platform.input;
const math = delve.math;
const modules = delve.modules;
const skinned_mesh = delve.graphics.skinned_mesh;

// easy access to some types
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;
const Color = colors.Color;

// use the basic lit shaders
const lit_shader = delve.shaders.default_basic_lighting;
const skinned_lit_shader = delve.shaders.default_skinned_basic_lighting;

// layout that will tell our materials how to pass params to the shader
const basic_lighting_fs_uniforms: []const delve.platform.graphics.MaterialUniformDefaults = &[_]delve.platform.graphics.MaterialUniformDefaults{ .CAMERA_POSITION, .COLOR_OVERRIDE, .ALPHA_CUTOFF, .DIRECTIONAL_LIGHT, .POINT_LIGHTS_8 };

var animated_mesh: skinned_mesh.SkinnedMesh = undefined;
var animation: skinned_mesh.PlayingAnimation = undefined;

var time: f32 = 0.0;
var camera: cam.Camera = undefined;

const mesh_file = "assets/meshes/CesiumMan.gltf";
const mesh_texture_file = "assets/meshes/CesiumMan.png";

var cube1: delve.graphics.mesh.Mesh = undefined;
var cube2: delve.graphics.mesh.Mesh = undefined;

var skinned_mesh_material: delve.platform.graphics.Material = undefined;
var static_mesh_material: delve.platform.graphics.Material = undefined;

// This example shows an example of some simple lighting in a shader

// Web build note: this does not seem to work when built in --release=fast or --release=small

pub fn main() !void {
    // Pick the allocator to use depending on platform
    const builtin = @import("builtin");
    if (builtin.os.tag == .wasi or builtin.os.tag == .emscripten) {
        // Web builds hack: use the C allocator to avoid OOM errors
        // See https://github.com/ziglang/zig/issues/19072
        try delve.init(std.heap.c_allocator);
    } else {
        try delve.init(gpa.allocator());
    }

    try registerModule();
    try app.start(app.AppConfig{ .title = "Delve Framework - Lighting Example" });
}

pub fn registerModule() !void {
    const meshExample = modules.Module{
        .name = "lighting_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(meshExample);
}

fn on_init() !void {
    debug.log("Lighting example module initializing", .{});

    graphics.setClearColor(colors.examples_bg_dark);

    // Make a perspective camera, with a 90 degree FOV
    camera = cam.Camera.initThirdPerson(90.0, 0.01, 150.0, 2.0, Vec3.up);
    camera.position = Vec3.new(0.0, 0.0, 0.0);
    camera.direction = Vec3.new(0.0, 0.0, 1.0);

    // make shaders for skinned and unskinned meshes
    const skinned_shader = graphics.Shader.initFromBuiltin(.{ .vertex_attributes = skinned_mesh.getSkinnedShaderAttributes() }, skinned_lit_shader);

    const static_shader = graphics.Shader.initFromBuiltin(.{ .vertex_attributes = delve.graphics.mesh.getShaderAttributes() }, lit_shader);

    var base_img: images.Image = try images.loadFile(mesh_texture_file);
    const tex_base = graphics.Texture.init(&base_img);

    // Create a material out of our shader and textures
    skinned_mesh_material = delve.platform.graphics.Material.init(.{
        .shader = skinned_shader.?,
        .texture_0 = tex_base,
        .texture_1 = delve.platform.graphics.createSolidTexture(0x00000000),

        // use the VS layout that supports sending joints to the shader
        .default_vs_uniform_layout = delve.platform.graphics.DefaultSkinnedMeshVSUniforms,

        // use the FS layout that supports lighting
        .default_fs_uniform_layout = basic_lighting_fs_uniforms,
    });

    // Create a material out of the texture
    static_mesh_material = graphics.Material.init(.{
        .shader = static_shader.?,
        .texture_0 = delve.platform.graphics.createSolidTexture(0xFFFFFFFF),
        .texture_1 = delve.platform.graphics.createSolidTexture(0x00000000),

        // use the FS layout that supports lighting
        .default_fs_uniform_layout = basic_lighting_fs_uniforms,
    });

    // Load an animated mesh
    const loaded_mesh = skinned_mesh.SkinnedMesh.initFromFile(delve.mem.getAllocator(), mesh_file, .{ .material = &skinned_mesh_material });

    if (loaded_mesh == null) {
        debug.fatal("Could not load skinned mesh!", .{});
        return;
    }

    // make some cubes
    cube1 = try delve.graphics.mesh.createCube(math.Vec3.new(0, -1.0, 0), math.Vec3.new(10.0, 0.25, 10.0), delve.colors.white, &static_mesh_material);
    cube2 = try delve.graphics.mesh.createCube(math.Vec3.new(0, 0, 0), math.Vec3.new(2.0, 1.25, 1.0), delve.colors.white, &static_mesh_material);

    animated_mesh = loaded_mesh.?;
    animation = try animated_mesh.createAnimation(0, 1.0, true);
}

fn on_tick(delta: f32) void {
    // There is a built in fly mode, but you can also just set the position / direction
    camera.runSimpleCamera(4 * delta, 120 * delta, false);

    time += delta * 100;

    animated_mesh.updateAnimation(&animation, delta);

    if (input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();
}

fn on_draw() void {
    const proj_view_matrix = camera.getProjView();

    var model = Mat4.translate(Vec3.new(0.0, -0.75, 0.0));
    model = model.mul(Mat4.rotate(-90, Vec3.new(1.0, 0.0, 0.0)));

    animated_mesh.applyAnimation(&animation, 0.9); // apply an animation to the mesh, with 90% blend

    // create a directional light that rotates around the mesh
    const light_dir = Vec3.new(0.3, 0.7, 0.0).rotate(time, Vec3.y_axis);
    const directional_light: delve.platform.graphics.DirectionalLight = .{ .dir = light_dir, .color = delve.colors.white, .brightness = 0.15 };

    // make some point lights
    const light_pos_1 = Vec3.new(std.math.sin(time * 0.002) * 2, std.math.sin(time * 0.003) + 0.5, std.math.sin(time * 0.0041) * -2.5);
    const light_pos_2 = Vec3.new(std.math.sin(time * -0.012), 0.4, std.math.sin(time * -0.013));

    const point_light_1: delve.platform.graphics.PointLight = .{ .pos = light_pos_1, .radius = 5.0, .color = delve.colors.green };
    const point_light_2: delve.platform.graphics.PointLight = .{ .pos = light_pos_2, .radius = 2.0, .color = delve.colors.red };
    const point_light_3: delve.platform.graphics.PointLight = .{ .pos = Vec3.new(-2, 1.2, -2), .radius = 3.0, .color = delve.colors.blue };

    const point_lights = &[_]delve.platform.graphics.PointLight{ point_light_1, point_light_2, point_light_3 };

    // add the lights and camera to the materials
    static_mesh_material.params.camera_position = camera.getPosition();
    static_mesh_material.params.point_lights = @constCast(point_lights);
    static_mesh_material.params.directional_light = directional_light;
    skinned_mesh_material.params = static_mesh_material.params;

    animated_mesh.draw(proj_view_matrix, model);
    cube1.draw(proj_view_matrix, Mat4.identity);
    cube2.draw(proj_view_matrix, Mat4.translate(Vec3.new(-2, 0, 0)).mul(Mat4.rotate(time * 0.1, Vec3.y_axis)));
}

fn on_cleanup() !void {
    debug.log("Lighting example module cleaning up", .{});

    animation.deinit();
    animated_mesh.deinit();
}
