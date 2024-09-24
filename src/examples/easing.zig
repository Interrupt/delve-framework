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
const interpolation = delve.utils.interpolation;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub const test_asset = @embedFile("static/test.gif");

var texture: graphics.Texture = undefined;
var test_image: images.Image = undefined;

const state = struct {
    var time: f64 = 0.0;
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
    try app.start(app.AppConfig{ .title = "Delve Framework - Easing Example" });
}

pub fn registerModule() !void {
    const example = modules.Module{
        .name = "easing_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(example);
}

fn on_init() !void {
    graphics.setClearColor(colors.examples_bg_dark);

    test_image = images.loadBytes(test_asset) catch {
        debug.log("Could not load test texture", .{});
        return;
    };
    texture = graphics.Texture.init(test_image);
}

fn on_tick(delta: f32) void {
    state.time += delta;

    if (state.time >= 2.5)
        state.time = 0.0;

    if (input.isKeyJustPressed(.SPACE))
        state.time = 0.0;

    if (input.isKeyJustPressed(.ESCAPE))
        papp.exit();
}

fn on_draw() void {
    // Draw our debug cat image, but use the color override to tint it!
    var y_pos: f32 = 10.0;
    const size: f32 = 50.0;
    const y_spacing: f32 = size + 8;

    const start_x: f32 = 200.0;
    const end_x: f32 = 800.0;

    const time: f32 = @floatCast(state.time);

    graphics.setDebugTextScale(1);
    graphics.setDebugTextColor(colors.Color.new(0.9, 0.9, 0.9, 1.0));

    var v = interpolation.Lerp.applyIn(start_x, end_x, time);
    graphics.drawDebugText(10, y_pos, "lerp:");
    graphics.drawDebugRectangle(texture, v, y_pos, size, size, colors.white);
    y_pos += y_spacing;

    v = interpolation.EaseQuad.applyOut(start_x, end_x, time);
    graphics.drawDebugText(10, y_pos, "quad out:");
    graphics.drawDebugRectangle(texture, v, y_pos, size, size, colors.white);
    y_pos += y_spacing;

    v = interpolation.EaseExpo.applyIn(start_x, end_x, time);
    graphics.drawDebugText(10, y_pos, "expo in:");
    graphics.drawDebugRectangle(texture, v, y_pos, size, size, colors.white);
    y_pos += y_spacing;

    v = interpolation.EaseBounce.applyOut(start_x, end_x, time);
    graphics.drawDebugText(10, y_pos, "bounce out:");
    graphics.drawDebugRectangle(texture, v, y_pos, size, size, colors.white);
    y_pos += y_spacing;

    v = interpolation.Circle.applyInMirrored(start_x, end_x, time);
    graphics.drawDebugText(10, y_pos, "circle in (mirrored):");
    graphics.drawDebugRectangle(texture, v, y_pos, size, size, colors.white);
    y_pos += y_spacing;

    v = interpolation.EaseQuint.applyInOut(start_x, end_x, time);
    graphics.drawDebugText(10, y_pos, "quint in/out:");
    graphics.drawDebugRectangle(texture, v, y_pos, size, size, colors.white);
    y_pos += y_spacing;

    v = interpolation.EaseElastic.applyOut(start_x, end_x, time);
    graphics.drawDebugText(10, y_pos, "elastic out:");
    graphics.drawDebugRectangle(texture, v, y_pos, size, size, colors.white);
    y_pos += y_spacing;

    v = interpolation.Sin.applyIn(start_x, end_x, time);
    graphics.drawDebugText(10, y_pos, "sin:");
    graphics.drawDebugRectangle(texture, v, y_pos, size, size, colors.white);
    y_pos += y_spacing;

    v = interpolation.PerlinSmoothstep.applyIn(start_x, end_x, time);
    graphics.drawDebugText(10, y_pos, "smoothstep:");
    graphics.drawDebugRectangle(texture, v, y_pos, size, size, colors.white);
    y_pos += y_spacing;
}

fn on_cleanup() !void {
    debug.log("Frame pacing example module cleaning up", .{});
    test_image.deinit();
    texture.destroy();
}
