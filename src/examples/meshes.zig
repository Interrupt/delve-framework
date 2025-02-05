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
const mesh = delve.graphics.mesh;

// easy access to some types
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;
const Color = colors.Color;

const emissive_shader_builtin = delve.shaders.default_emissive;

var time: f32 = 0.0;
var camera: cam.Camera = undefined;

var mesh_test: ?mesh.Mesh = null;
var shader: delve.platform.graphics.Shader = undefined;
var material: graphics.Material = undefined;

// This example shows loading and drawing meshes

pub fn main() !void {
    // Pick the allocator to use depending on platform
    const builtin = @import("builtin");
    if (builtin.os.tag == .wasi or builtin.os.tag == .emscripten) {
        // Web builds hack: use the C allocator to avoid OOM errors
        // See https://github.com/ziglang/zig/issues/19072
        try delve.init(std.heap.c_allocator);
    } else {
        // Using the default allocator will let us detect memory leaks
        try delve.init(delve.mem.createDefaultAllocator());
    }

    try registerModule();
    try app.start(app.AppConfig{ .title = "Delve Framework - Mesh Drawing Example" });
}

pub fn registerModule() !void {
    const meshExample = modules.Module{
        .name = "mesh_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(meshExample);
}

fn on_init() !void {
    debug.log("Mesh example module initializing", .{});

    graphics.setClearColor(colors.examples_bg_light);

    // Make a perspective camera, with a 90 degree FOV
    camera = cam.Camera.initThirdPerson(90.0, 0.01, 50.0, 5.0, Vec3.up);
    camera.position = Vec3.new(0.0, 0.0, 0.0);

    // Load the base color texture for the mesh
    const base_texture_file = "assets/meshes/SciFiHelmet_BaseColor_512.png";
    var base_img: images.Image = images.loadFile(base_texture_file) catch {
        debug.log("Assets: Error loading image asset: {s}", .{base_texture_file});
        return;
    };
    defer base_img.deinit();
    const tex_base = graphics.Texture.init(base_img);

    // Load the emissive texture for the mesh
    const emissive_texture_file = "assets/meshes/SciFiHelmet_Emissive_512.png";
    var emissive_img: images.Image = images.loadFile(emissive_texture_file) catch {
        debug.log("Assets: Error loading image asset: {s}", .{emissive_texture_file});
        return;
    };
    defer emissive_img.deinit();
    const tex_emissive = graphics.Texture.init(emissive_img);

    // Make our emissive shader from one that is pre-compiled
    shader = try graphics.Shader.initFromBuiltin(.{ .vertex_attributes = mesh.getShaderAttributes() }, emissive_shader_builtin);

    // Create a material out of our shader and textures
    material = try graphics.Material.init(.{
        .shader = shader,
        .texture_0 = tex_base,
        .texture_1 = tex_emissive,
    });

    // Load our mesh!
    mesh_test = mesh.Mesh.initFromFile(delve.mem.getAllocator(), "assets/meshes/SciFiHelmet.gltf", .{ .material = material });
}

fn on_tick(delta: f32) void {
    // There is a built in fly mode, but you can also just set the position / direction
    camera.runSimpleCamera(4 * delta, 120 * delta, false);

    time += delta * 100;

    if (input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();
}

fn on_draw() void {
    // Exit early if we have no mesh loaded
    if (mesh_test == null)
        return;

    const view_mats = camera.update();

    var model = Mat4.translate(Vec3.new(2.0, 0.0, 0.0));
    model = model.mul(Mat4.rotate(time * 0.6, Vec3.new(0.0, 1.0, 0.0)));

    const sin_val = std.math.sin(time * 0.006) + 0.5;
    mesh_test.?.material.state.params.draw_color = Color.new(sin_val, sin_val, sin_val, 1.0);
    mesh_test.?.draw(view_mats, model);

    model = Mat4.translate(Vec3.new(-2.0, 0.0, 0.0));
    mesh_test.?.draw(view_mats, model);
}

fn on_cleanup() !void {
    debug.log("Mesh example module cleaning up", .{});

    if (mesh_test == null)
        return;

    mesh_test.?.deinit();
    material.deinit();
    shader.destroy();
}
