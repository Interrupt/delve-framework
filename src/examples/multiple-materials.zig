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
const gltf = delve.assets.gltf;
const mesh = delve.graphics.mesh;

// easy access to some types
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;
const Color = colors.Color;

const default_shader_builtin = delve.shaders.default;

var time: f32 = 0.0;
var camera: cam.Camera = undefined;

var mesh1: ?mesh.Mesh = null;
var mesh2: ?mesh.Mesh = null;
var gltf_data: *gltf.Data = undefined;
var shader: delve.platform.graphics.Shader = undefined;
var materials: std.ArrayList(graphics.Material) = undefined;
var allocator: std.mem.Allocator = undefined;

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
    try app.start(app.AppConfig{ .title = "Delve Framework - Multiple Materials" });
}

pub fn registerModule() !void {
    const meshExample = modules.Module{
        .name = "multiple_materials_example",
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
    camera = cam.Camera.initThirdPerson(90, 0.01, 50.0, 5.0, Vec3.new(0, -4, -4));
    camera.position = Vec3.new(-2, 0, 0);

    shader = try graphics.Shader.initFromBuiltin(.{ .vertex_attributes = mesh.getShaderAttributes() }, default_shader_builtin);

    allocator = delve.mem.getAllocator();

    const path = "assets/meshes/";
    // https://github.com/KhronosGroup/glTF-Sample-Assets/blob/main/Models/CesiumMilkTruck/README.md
    const filename = "CesiumMilkTruck.gltf";

    gltf_data = try gltf.loadData(filename, path);

    materials = std.ArrayList(graphics.Material).init(allocator);

    gltf.loadMaterials(gltf_data, 0, path, shader, &materials);

    std.debug.print("amount of materials {d} \n", .{materials.items.len});

    mesh1 = mesh.Mesh.initFromData(allocator, gltf_data, 0, .{ .materials = materials });
    // mesh2 = mesh.Mesh.initFromData(allocator, gltf_data, 1, .{ .materials = materials });
}

fn on_tick(delta: f32) void {
    // There is a built in fly mode, but you can also just set the position / direction
    camera.runSimpleCamera(4 * delta, 120 * delta, false);

    time += delta * 100;

    if (input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();
}

fn on_draw() void {
    const view_mats = camera.update();

    var model_matrix = Mat4.translate(Vec3.new(2.0, 0.0, 0.0));
    model_matrix = model_matrix.mul(Mat4.rotate(time * 0.6, Vec3.new(0.0, 1.0, 0.0)));

    model_matrix = Mat4.translate(Vec3.new(-2.0, 0.0, 0.0));
    mesh1.?.draw(view_mats, model_matrix);
    // mesh2.?.draw(view_mats, model_matrix);
}

fn on_cleanup() !void {
    debug.log("Model example module cleaning up", .{});

    for (materials.items) |*m| {
        m.deinit();
    }
    materials.deinit();
    shader.destroy();

    gltf.freeData(gltf_data);

    mesh1.?.deinit();
    // mesh2.?.deinit();
}
