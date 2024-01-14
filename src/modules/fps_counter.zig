const std = @import("std");
const debug = @import("../debug.zig");
const graphics = @import("../platform/graphics.zig");
const papp = @import("../platform/app.zig");
const modules = @import("../modules.zig");

// This is a module that will draw the current FPS in the corner of the screen

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

var show_fps: bool = true;
var last_fps_str: ?[:0]u8 = null;
var last_fps: i32 = -1;

/// Registers this module
pub fn registerModule() !void {
    const fpsCounter = modules.Module {
        .name = "fps_counter",
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(fpsCounter);
}

pub fn on_cleanup() void {
    if(last_fps_str != null) {
        allocator.free(last_fps_str.?);
        last_fps_str = null;
    }
}

pub fn on_tick(delta: f32) void {
    _ = delta;
}

pub fn on_draw() void {
    if(!show_fps)
        return;

    // This should only change once a second
    const fps = papp.getFPS();
    defer last_fps = fps;

    // Easy case, just draw our cached string
    if(fps == last_fps and last_fps_str != null) {
        drawFPS(last_fps_str.?);
        return;
    }

    if(last_fps_str != null)
        allocator.free(last_fps_str.?);

    // Harder case, build the string again
    const fps_string = std.fmt.allocPrintZ(allocator, "FPS: {d}", .{fps}) catch {
        return;
    };
    last_fps_str = fps_string;

    drawFPS(fps_string);
}

pub fn drawFPS(fps_string: [:0]u8) void {
    graphics.setDebugTextScale(1.0, 1.0);
    graphics.setDebugTextColor4b(0x88, 0x88, 0x88, 0xFF);
    graphics.drawDebugText(2, 2, fps_string);
}
