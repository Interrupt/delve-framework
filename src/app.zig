const std = @import("std");
const debug = @import("debug.zig");
const images = @import("images.zig");
const lua = @import("scripting/lua.zig");
const modules = @import("modules.zig");
const scripting = @import("scripting/manager.zig");

// Main systems
const app_backend = @import("platform/app.zig");
const input = @import("platform/input.zig");

pub var assets_path: [:0]const u8 = "assets";
pub var palette: images.Image = undefined;

pub fn setAssetsPath(path: [:0]const u8) !void {
    assets_path = path;
}

pub fn start() !void {
    debug.init();
    defer debug.deinit();

    debug.log("Delve Framework Starting", .{});

    // App backend init
    try app_backend.init();
    defer app_backend.deinit();

    // Change the working dir to where the assets are
    debug.log("Assets Path: {s}", .{assets_path});
    try std.os.chdirZ(assets_path);

    // Load the palette
    palette = try images.loadFile("palette.gif");
    defer palette.destroy();

    // Start up the subsystems
    try startSubsystems();
    defer stopSubsystems();

    // Kick off the game loop!
    app_backend.startMainLoop();

    debug.log("Delve framework stopping", .{});
}

pub fn startSubsystems() !void {
    try input.init();
    try scripting.init();
}

pub fn stopSubsystems() void {
    input.deinit();
    scripting.deinit();
}
