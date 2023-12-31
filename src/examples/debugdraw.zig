const std = @import("std");
const batcher = @import("../graphics/batcher.zig");
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");
const images = @import("../images.zig");
const input = @import("../platform/input.zig");
const math = @import("../math.zig");
const modules = @import("../modules.zig");

pub const test_asset = @embedFile("../static/test_transparent.gif");

var time: f32 = 0.0;
var texture: graphics.Texture = undefined;
var test_image: images.Image = undefined;

// -- This module exercises the simple debug drawing functions --

pub fn registerModule() !void {
    const debugDrawExample = modules.Module {
        .name = "debug_draw_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(debugDrawExample);
}

fn on_init() void {
    debug.log("Debug draw example module initializing", .{});

    test_image = images.loadBytes(test_asset) catch {
        debug.log("Could not load test texture", .{});
        return;
    };
    texture = graphics.Texture.init(&test_image);
}

fn on_tick(tick: u64) void {
    time = @floatFromInt(tick);
}

fn on_draw() void {
    // Draw our debug cat image, but use the color override to tint it!
    const r_ovr = std.math.sin(time * 0.006) + 0.5;
    const g_ovr = std.math.sin(time * 0.008) + 0.5;
    const b_ovr = std.math.sin(time * 0.01) + 0.5;
    const a_ovr = std.math.sin(time * 0.02) - 0.5; // alpha channel controls how much tinting should occur

    const params = graphics.ShaderParams{.color_override = [_]f32{r_ovr, g_ovr, b_ovr, a_ovr}};
    graphics.setDebugDrawShaderParams(params);
    defer graphics.setDebugDrawShaderParams(graphics.ShaderParams{}); // reset when done!

    graphics.drawDebugRectangle(texture, 120.0, 200.0, 100.0, 100.0, graphics.Color{.r=1.0, .g=1.0, .b=1.0, .a=1.0});

    // Now draw some text
    const scale = 1.5 + std.math.sin(time * 0.02) * 0.2;

    graphics.setDebugTextScale(scale, scale);
    graphics.setDebugTextColor4f(1.0, std.math.sin(time * 0.02), 0.0, 1.0);
    graphics.drawDebugText(2.0 / scale, 240.0 / scale, "This is from the debug draw module!");
}

fn on_cleanup() void {
    debug.log("Debug draw example module cleaning up", .{});
    test_image.destroy();
}
