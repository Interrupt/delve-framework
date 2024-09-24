const std = @import("std");
const delve = @import("delve");
const app = delve.app;

const debug = delve.debug;
const papp = delve.platform.app;
const graphics = delve.platform.graphics;
const colors = delve.colors;
const images = delve.images;
const input = delve.platform.input;
const math = delve.math;
const modules = delve.modules;
const fps_module = delve.module.fps_counter;

pub const test_asset = @embedFile("static/test.gif");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

var texture: graphics.Texture = undefined;
var test_image: images.Image = undefined;

const state = struct {
    var start_x: f32 = 120.0;
    var x_pos: f32 = 120.0;
    var x_pos_delta: f32 = 120.0;
    var x_pos_fixed: f32 = 120.0;
    var speed: f32 = 300.0;
};

// This example shows the simple debug drawing functions.
// These functions are slow, but a quick way to get stuff on screen!

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
    try fps_module.registerModule();
    try app.start(app.AppConfig{ .title = "Delve Framework - Frame Pacing Test" });
}

pub fn registerModule() !void {
    const debugDrawExample = modules.Module{
        .name = "frame_pacing_test",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .fixed_tick_fn = on_fixed_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(debugDrawExample);
}

fn on_init() !void {
    debug.log("Frame pacing example module initializing", .{});

    // papp.setTargetFPS(60);
    papp.setFixedTimestep(1.0 / 24.0);

    fps_module.showFPS(true);

    graphics.setClearColor(colors.examples_bg_dark);

    test_image = images.loadBytes(test_asset) catch {
        debug.log("Could not load test texture", .{});
        return;
    };
    texture = graphics.Texture.init(test_image);
}

fn on_tick(delta: f32) void {
    state.x_pos += (1.0 / 60.0) * state.speed;
    state.x_pos_delta += delta * state.speed;

    if (state.x_pos > 600.0)
        state.x_pos = 0.0;

    if (state.x_pos_delta > 600.0)
        state.x_pos_delta = 0.0;

    if (input.isKeyJustPressed(.ESCAPE))
        papp.exit();
}

fn on_fixed_tick(fixed_delta: f32) void {
    state.x_pos_fixed += fixed_delta * state.speed;

    if (state.x_pos_fixed > 600.0)
        state.x_pos_fixed = 0.0;
}

fn on_draw() void {
    // Draw our debug cat image, but use the color override to tint it!
    var y_pos: f32 = 50.0;
    const y_spacing: f32 = 120.0;

    const fixed_timestep_lerp = papp.getFixedTimestepLerp(true);

    graphics.setDebugTextScale(1);
    graphics.setDebugTextColor(colors.Color.new(0.9, 0.9, 0.9, 1.0));
    graphics.drawDebugText(10, y_pos, "raw tick:");
    graphics.drawDebugRectangle(texture, state.start_x + state.x_pos, y_pos, 100.0, 100.0, colors.white);
    y_pos += y_spacing;

    graphics.drawDebugText(10, y_pos, "delta tick:");
    graphics.drawDebugRectangle(texture, state.start_x + state.x_pos_delta, y_pos, 100.0, 100.0, colors.white);
    y_pos += y_spacing;

    graphics.drawDebugText(10, y_pos, "fixed tick:");
    graphics.drawDebugRectangle(texture, state.start_x + state.x_pos_fixed, y_pos, 100.0, 100.0, colors.white);
    y_pos += y_spacing;

    graphics.drawDebugText(10, y_pos, "fixed tick with lerp:");
    graphics.drawDebugRectangle(texture, state.start_x + state.x_pos_fixed + (fixed_timestep_lerp * state.speed), y_pos, 100.0, 100.0, colors.white);
}

fn on_cleanup() !void {
    debug.log("Frame pacing example module cleaning up", .{});
    test_image.deinit();
    texture.destroy();
}
