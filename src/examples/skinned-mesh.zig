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

const shader_builtin = delve.shaders.default_skinned;

var time: f32 = 0.0;
var mesh_test: ?mesh.Mesh = null;
var camera: cam.Camera = undefined;

// This example shows loading and drawing meshes

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
    try app.start(app.AppConfig{ .title = "Delve Framework - Skinned Mesh Drawing Example" });
}

pub fn registerModule() !void {
    const meshExample = modules.Module{
        .name = "skinned_mesh_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(meshExample);
}

fn on_init() !void {
    debug.log("Skinned mesh example module initializing", .{});

    graphics.setClearColor(colors.examples_bg_light);

    // Make a perspective camera, with a 90 degree FOV
    camera = cam.Camera.initThirdPerson(90.0, 0.01, 50.0, 10.0, Vec3.up);
    camera.position = Vec3.new(0.0, 0.0, 0.0);
    camera.direction = Vec3.new(0.0, 0.0, 1.0);

    // Make our emissive shader from one that is pre-compiled
    const shader = graphics.Shader.initFromBuiltin(.{ .vertex_attributes = mesh.getSkinnedShaderAttributes() }, shader_builtin);

    if (shader == null) {
        debug.log("Could not get shader", .{});
        return;
    }

    // Create a material out of our shader and textures
    const material = delve.platform.graphics.Material.init(.{
        .shader = shader.?,
        .texture_0 = delve.platform.graphics.createSolidTexture(0xFF0000FF),
        .texture_1 = delve.platform.graphics.createSolidTexture(0x00000000),
        .num_uniform_fs_blocks = 2,
    });

    // Load our mesh!
    mesh_test = mesh.Mesh.initFromFile(delve.mem.getAllocator(), "assets/meshes/RiggedSimple.gltf", .{ .material = material });
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

    const proj_view_matrix = camera.getProjView();

    var model = Mat4.translate(Vec3.new(0.0, -0.75, 0.0));
    model = model.mul(Mat4.rotate(-90, Vec3.new(1.0, 0.0, 0.0)));

    mesh_test.?.material.fs_uniforms[1].?.begin();
    mesh_test.?.material.fs_uniforms[1].?.addFloat("u_test", std.math.sin(time * 0.1) * 0.5 + 0.5);
    mesh_test.?.material.fs_uniforms[1].?.end();

    mesh_test.?.draw(proj_view_matrix, model);
}

fn on_cleanup() !void {
    debug.log("Skinned mesh example module cleaning up", .{});

    if (mesh_test == null)
        return;

    mesh_test.?.deinit();
}
