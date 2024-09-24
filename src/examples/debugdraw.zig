const std = @import("std");
const delve = @import("delve");
const app = delve.app;

const debug = delve.debug;
const graphics = delve.platform.graphics;
const colors = delve.colors;
const images = delve.images;
const input = delve.platform.input;
const math = delve.math;
const modules = delve.modules;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub const test_asset = @embedFile("static/test_transparent.gif");

var time: f32 = 0.0;
var texture: graphics.Texture = undefined;
var test_image: images.Image = undefined;

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
    try app.start(app.AppConfig{ .title = "Delve Framework - Debug Draw Example" });
}

pub fn registerModule() !void {
    const debugDrawExample = modules.Module{
        .name = "debug_draw_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(debugDrawExample);
}

fn on_init() !void {
    debug.log("Debug draw example module initializing", .{});

    test_image = images.loadBytes(test_asset) catch {
        debug.log("Could not load test texture", .{});
        return;
    };
    texture = graphics.Texture.init(test_image);

    graphics.setClearColor(colors.examples_bg_dark);
}

fn on_tick(delta: f32) void {
    time += delta * 100.0;

    if (input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();
}

fn on_draw() void {
    // Draw our debug cat image, but use the color override to tint it!
    const r_ovr = std.math.sin(time * 0.006) + 0.5;
    const g_ovr = std.math.sin(time * 0.008) + 0.5;
    const b_ovr = std.math.sin(time * 0.01) + 0.5;
    const a_ovr = std.math.sin(time * 0.02) - 0.5; // alpha channel controls how much tinting should occur

    graphics.setDebugDrawColorOverride(colors.Color.new(r_ovr, g_ovr, b_ovr, a_ovr));
    defer graphics.setDebugDrawColorOverride(colors.transparent); // reset when done!

    graphics.drawDebugRectangle(texture, 120.0, 200.0, 100.0, 100.0, colors.white);

    // Now draw some text
    const scale = 1.5 + std.math.sin(time * 0.02) * 0.2;

    graphics.setDebugTextScale(scale);
    graphics.setDebugTextColor(colors.Color.new(1.0, std.math.sin(time * 0.02), 0.0, 1.0));
    graphics.drawDebugText(4.0, 480.0, "This is from the debug draw module!");
}

fn on_cleanup() !void {
    debug.log("Debug draw example module cleaning up", .{});
    test_image.deinit();
}
