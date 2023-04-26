const std = @import("std");
const math = std.math;
const ziglua = @import("ziglua");
const zigsdl = @import("../sdl.zig");
const main = @import("../main.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Lua = ziglua.Lua;

pub fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "loadGif", .func = ziglua.wrap(loadGif) },
    };

    lua.newLib(&funcs);
    return 1;
}

fn loadGif(lua: *Lua) i32 {
    var filename_arg= lua.toString(1) catch "";

    std.debug.print("Load Gif: {s}\n", .{filename_arg});

    return 0;
}
