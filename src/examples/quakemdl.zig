const std = @import("std");
const delve = @import("delve");
const app = delve.app;

const graphics = delve.platform.graphics;
const math = delve.math;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

var camera: delve.graphics.camera.Camera = undefined;

var mdl: delve.utils.quakemdl.MDL = undefined;

var time: f64 = 0.0;

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

    const example = delve.modules.Module{
        .name = "quakemdl_example",
        .init_fn = on_init,
        .cleanup_fn = on_cleanup,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
    };

    try delve.modules.registerModule(example);
    try delve.module.fps_counter.registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework - Quake MDL Example", .sampler_pool_size = 1024 });
}

pub fn on_cleanup() !void {
    delve.debug.log("Quake MDL example shutting down!", .{});
    mdl.deinit();
}

pub fn on_init() !void {
    // create our camera
    camera = delve.graphics.camera.Camera.initThirdPerson(90.0, 0.01, 256.0, 64.0, math.Vec3.up);

    const allocator = delve.mem.getAllocator();
    mdl = try delve.utils.quakemdl.open(allocator, "assets/meshes/pumpkin.mdl");

    // set a bg color
    delve.platform.graphics.setClearColor(delve.colors.examples_bg_dark);

    // capture mouse
    delve.platform.app.captureMouse(true);
}

pub fn on_tick(delta: f32) void {
    if (delve.platform.input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();

    time += delta;

    camera.runSimpleCamera(48 * delta, 120 * delta, true);
}

var counter: f32 = 0;
var index: u32 = 0;

pub fn on_draw() void {
    const view_mats = camera.update();
    const model = math.Mat4.identity.mul(math.Mat4.translate(math.Vec3.new(0, -32, 0)));

    defer counter += 0.1;
    index = @as(u32, @intFromFloat(counter)) % @as(u32, @intCast(mdl.frames.len));

    var frame = &mdl.frames[index];
    var mesh = switch (frame.*) {
        .single => &frame.single.mesh,
        .group => &frame.group.frames[0].mesh,
    };

    const frustum = camera.getViewFrustum();
    if (!frustum.containsBoundingBox(mesh.bounds.transform(model))) {
        return;
    }

    mesh.draw(view_mats, model);
}
