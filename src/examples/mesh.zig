const std = @import("std");
const batcher = @import("../graphics/batcher.zig");
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");
const images = @import("../images.zig");
const input = @import("../platform/input.zig");
const math = @import("../math.zig");
const modules = @import("../modules.zig");

const mesh = @import("../graphics/mesh.zig");

var time: f32 = 0.0;
var mesh_test: ?mesh.Mesh = null;

// -- This module exercises loading and drawing a mesh --

pub fn registerModule() !void {
    const meshExample = modules.Module {
        .name = "mesh_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(meshExample);
}

fn on_init() void {
    debug.log("Mesh example module initializing", .{});

    mesh_test = mesh.Mesh.initFromFile("meshes/Suzanne.gltf", .{});
    // mesh_test = mesh.Mesh.initFromFile("meshes/SciFiHelmet.gltf", .{});
}

fn on_tick(tick: u64) void {
    time = @floatFromInt(tick);
}

fn on_draw() void {
    // draw the test mesh
    if(mesh_test == null)
        return;


    var view = math.Mat4.lookat(.{ .x = 0.0, .y = 0.0, .z = 6.0 }, math.Vec3.zero(), math.Vec3.up());
    var model = math.Mat4.rotate(time * 0.6, .{ .x = 0.0, .y = 1.0, .z = 0.0 });

    graphics.setProjectionPerspective(60.0, 0.01, 50.0);
    graphics.setView(view, model);

    mesh_test.?.draw();
}

fn on_cleanup() void {
    debug.log("Mesh example module cleaning up", .{});

    if(mesh_test == null)
        return;

    mesh_test.?.deinit();
}
