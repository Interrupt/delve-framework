const std = @import("std");
const lua = @import("lua.zig");

pub fn main() !void {
    std.debug.print("Brass Emulator Starting\n", .{});

    try lua.initLua("main.lua");
    defer lua.deinitLua();

    // Run the '_init' lua function
    try lua.runInit();
}

