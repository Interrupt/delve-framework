const std = @import("std");
const debug = @import("debug.zig");
const images = @import("images.zig");
const lua = @import("scripting/lua.zig");
const modules = @import("modules.zig");
const scripting = @import("scripting/manager.zig");

// Main systems
const app_backend = @import("platform/app.zig");
const gfx = @import("platform/graphics.zig");
const input = @import("platform/input.zig");
const gfx_3d = @import("graphics/3d.zig");

const Allocator = std.mem.Allocator;

var args_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var args_allocator = args_gpa.allocator();

const fallback_assets_path = "assets";
pub var assets_path: [:0]const u8 = undefined;
pub var palette: images.Image = undefined;

pub fn main() !void {
    debug.init();
    defer debug.deinit();

    debug.log("Brass Emulator Starting", .{});

    // Get arguments
    const args = try std.process.argsAlloc(args_allocator);
    defer _ = args_gpa.deinit();
    defer std.process.argsFree(args_allocator, args);

    // Get the path to the assets
    assets_path = switch (args.len >= 2) {
        true => try args_allocator.dupeZ(u8, args[1]),
        else => try args_allocator.dupeZ(u8, fallback_assets_path),
    };
    defer args_allocator.free(assets_path);

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

    // Test some example modules
    try @import("examples/debugdraw.zig").registerModule();
    try @import("examples/batcher.zig").registerModule();

    // Kick off the game loop!
    app_backend.startMainLoop();

    debug.log("Brass Emulator Stopping", .{});
}

pub fn startSubsystems() !void {
    // try gfx.init();
    try input.init();
    try scripting.init();
}

pub fn stopSubsystems() void {
    // gfx.deinit();
    input.deinit();
    scripting.deinit();
}

pub fn getAssetPath(file_path: []const u8, allocator: Allocator) ![:0]const u8 {
    const total_size = assets_path.len + file_path.len + 2;
    var path: []u8 = try allocator.alloc(u8, total_size);
    return try std.fmt.bufPrintZ(path, "{s}/{s}", .{ assets_path, file_path });
}
