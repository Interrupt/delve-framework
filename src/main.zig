const std = @import("std");
const lua = @import("lua.zig");

var shouldQuit = false;

pub fn main() !void {
    std.debug.print("Brass Emulator Starting\n", .{});

    // Start up Lua
    try lua.initLua("main.lua");
    defer lua.deinitLua();

    // First, call the init function
    try lua.callFunction("_init");

    // Kick off the game loop!
    while(!shouldQuit) {
        std.debug.print("Brass Emulator: tick!\n", .{});

        try lua.callFunction("_update");
        try lua.callFunction("_draw");
    }
}

pub fn exit() void {
    shouldQuit = true;
}
