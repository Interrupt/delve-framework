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

var texture: graphics.Texture = undefined;
var test_image: images.Image = undefined;

const state = struct {
    var start_x: f32 = 120.0;
    var x_pos: f32 = 120.0;
    var x_pos_delta: f32 = 120.0;
};

// This example shows the simple debug drawing functions.
// These functions are slow, but a quick way to get stuff on screen!

pub fn main() !void {
    try registerModule();
    try fps_module.registerModule();
    try app.start(app.AppConfig{ .title = "Delve Framework - Frame Pacing Test" });
}

pub fn registerModule() !void {
    const debugDrawExample = modules.Module{
        .name = "frame_pacing_test",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(debugDrawExample);
}

fn on_init() void {
    debug.log("Frame pacing example module initializing", .{});

    papp.setTargetFPS(60);
    // papp.setFixedTimestep(1.0 / 60.0);

    fps_module.showFPS(true);

    test_image = images.loadBytes(test_asset) catch {
        debug.log("Could not load test texture", .{});
        return;
    };
    texture = graphics.Texture.init(&test_image);
}

fn on_tick(delta: f32) void {
    state.x_pos += (1.0 / 60.0) * 300.0;
    state.x_pos_delta += delta * 300.0;

    if(state.x_pos > 600.0)
        state.x_pos = 0.0;

    if(state.x_pos_delta > 600.0)
        state.x_pos_delta = 0.0;

    if (input.isKeyJustPressed(.ESCAPE))
        std.os.exit(0);
}

fn on_draw() void {
    // Draw our debug cat image, but use the color override to tint it!
    graphics.drawDebugRectangle(texture, state.start_x + state.x_pos, 120.0, 100.0, 100.0, colors.white);
    graphics.drawDebugRectangle(texture, state.start_x + state.x_pos_delta, 260.0, 100.0, 100.0, colors.white);
}

fn on_cleanup() void {
    debug.log("Frame pacing example module cleaning up", .{});
    test_image.destroy();
}
