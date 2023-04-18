const std = @import("std");
const lua = @import("lua.zig");
const sdl = @import("sdl.zig");

var isRunning = true;
var numTicks: u64 = 0;

pub fn main() !void {
    std.debug.print("Brass Emulator Starting\n", .{});

    // Start up SDL2
    try sdl.init();
    defer sdl.deinit();

    // Start up Lua
    try lua.init("assets/main.lua");
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
        sdl.delay(1);
    }
}

pub fn stop() void {
    isRunning = false;   
}

