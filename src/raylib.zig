const std = @import("std");
const main = @import("main.zig");
const debug = @import("debug.zig");
const rl = @import("raylib");

pub const render_scale = 3;

pub fn init() !void {
    debug.log("Initializing Raylib", .{});

    rl.initWindow(320 * render_scale, 200 * render_scale, "Zig Game Test");
    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
}

pub fn deinit() void {
    rl.closeWindow();
}

pub fn processEvents() void {
}

pub fn beginDrawing() void {
    rl.beginDrawing();
    rl.clearBackground(rl.Color.white);
    rl.drawText("Congrats! You created your first window!", 190, 200, 20, rl.Color.light_gray);
}

pub fn endDrawing() void {
    rl.endDrawing();
}
