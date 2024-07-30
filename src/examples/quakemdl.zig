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
        try delve.init(gpa.allocator());
    }

    const example = delve.modules.Module{
        .name = "quakemdl_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
    };

    try delve.modules.registerModule(example);
    try delve.module.fps_counter.registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework - Quake MDL Example", .sampler_pool_size = 1024 });
}

pub fn on_init() !void {
    // create our camera
    camera = delve.graphics.camera.Camera.initThirdPerson(90.0, 0.01, 256.0, 64.0, math.Vec3.up);

    const allocator = delve.mem.getAllocator();
    mdl = try delve.utils.quakemdl.get_mdl(allocator, "assets/meshes/player.mdl");

    // set a bg color
    delve.platform.graphics.setClearColor(delve.colors.examples_bg_dark);

    // capture mouse
    delve.platform.app.captureMouse(true);
}

pub fn on_tick(delta: f32) void {
    if (delve.platform.input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();

    time += delta;

    camera.runSimpleCamera(8 * delta, 120 * delta, true);
}

var mdl_frame_counter: f32 = 0;

pub fn on_draw() void {
    const proj_view_matrix = camera.getProjView();
    const model = math.Mat4.identity;

    const frustum = camera.getViewFrustum();
    if (!frustum.containsPoint(math.Vec3.new(0, 0, 0))) {
        return;
    }

    const mdl_frame_index = @as(u32, @intFromFloat(mdl_frame_counter)) % @as(u32, @intCast(mdl.frames.len));

    mdl.frames[mdl_frame_index].single.mesh.draw(proj_view_matrix, model);

    mdl_frame_counter += 0.1;
}