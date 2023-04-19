const std = @import("std");
const lua = @import("lua.zig");
const sdl = @import("sdl.zig");
const gif = @import("gif.zig");

var args_gpa = std.heap.GeneralPurposeAllocator(.{}){};
var args_allocator = args_gpa.allocator();

var isRunning = true;
var numTicks: u64 = 0;

pub var assets_path: [:0]const u8 = undefined;
pub var palette: gif.GifImage = undefined;

pub fn main() !void {
    std.debug.print("Brass Emulator Starting\n", .{});

    // Get arguments
    var args = try std.process.argsAlloc(args_allocator);

    // Get the path to the assets
    assets_path = if(args.len >= 2) args[1] else ".";
    std.debug.print("Assets Path: {s}\n", .{assets_path});

    // Technically not needed? Will be freed after program exits
    //defer std.process.argsFree(args_allocator, args);
    //defer _ = args_gpa.deinit();

    palette = try gif.loadFile(try getAssetPath("palette.gif"));
    defer palette.destroy();

    // Start up SDL2
    try sdl.init();
    defer sdl.deinit();

    // Start up Lua
    try lua.init("main.lua");
    defer lua.deinit();

    // First, call the init function
    try lua.callFunction("_init");

    // Kick off the game loop!
    while(isRunning) {
        sdl.processEvents();

        try lua.callFunction("_update");
        try lua.callFunction("_draw");
        numTicks += 1;

        sdl.present();
    }
}

pub fn getAssetPath(file_path: []const u8) ![:0]const u8 {
    var path: [100]u8 = undefined;
    const concat_path = try std.fmt.bufPrintZ(&path, "{s}/{s}", .{ assets_path, file_path });
    std.debug.print("Generated Asset Path: {s}\n", .{concat_path});
    return concat_path;
}

pub fn stop() void {
    isRunning = false;   
}

