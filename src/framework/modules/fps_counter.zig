const std = @import("std");
const colors = @import("../colors.zig");
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");
const papp = @import("../platform/app.zig");
const mem = @import("../mem.zig");
const modules = @import("../modules.zig");
const input = @import("../platform/input.zig");

// This is a module that will draw the current FPS in the corner of the screen

var allocator: std.mem.Allocator = undefined;

var show_fps: bool = false;
var last_fps_str: ?[:0]u8 = null;
var last_fps: i32 = -1;

/// Registers this module
pub fn registerModule() !void {
    const fpsCounter = modules.Module{
        .name = "fps_counter",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(fpsCounter);
}

fn on_init() !void {
    allocator = mem.getAllocator();
}

fn on_cleanup() !void {
    if (last_fps_str != null) {
        allocator.free(last_fps_str.?);
        last_fps_str = null;
    }
}

fn on_tick(delta: f32) void {
    _ = delta;

    if (input.isKeyPressed(.LEFT_SHIFT) and input.isKeyJustPressed(.F)) {
        toggleFPS();
    }
}

fn on_draw() void {
    if (!show_fps)
        return;

    // This should only change once a second
    const fps = papp.getFPS();
    defer last_fps = fps;

    // Easy case, just draw our cached string
    if (fps == last_fps and last_fps_str != null) {
        drawFPS(last_fps_str.?);
        return;
    }

    if (last_fps_str != null)
        allocator.free(last_fps_str.?);

    // Harder case, build the string again
    const fps_string = std.fmt.allocPrint(allocator, "FPS: {d}\x00", .{fps}) catch {
        return;
    };

    const null_terminated_fps = fps_string[0..(fps_string.len - 1) :0];
    last_fps_str = null_terminated_fps;

    drawFPS(null_terminated_fps);
}

fn drawFPS(fps_string: [:0]u8) void {
    graphics.setDebugTextScale(1.0);
    graphics.setDebugTextColor(colors.Color.newBytes(0x88, 0x88, 0x88, 0xFF));
    graphics.drawDebugText(2, 4, fps_string);
}

pub fn showFPS(enabled: bool) void {
    show_fps = enabled;
}

pub fn toggleFPS() void {
    show_fps = !show_fps;
}
