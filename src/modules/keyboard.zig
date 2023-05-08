const std = @import("std");
const zigsdl = @import("../sdl.zig");
const debug = @import("../debug.zig");
const ziglua = @import("ziglua");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Lua = ziglua.Lua;

pub fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "key", .func = ziglua.wrap(isKeyPressed) },
    };

    lua.newLib(&funcs);
    return 1;
}

fn isKeyPressed(lua: *Lua) i32 {
    var key_idx = @floatToInt(usize, lua.toNumber(1) catch 0);

    var num_keys: c_int = 0;
    var state = sdl.SDL_GetKeyboardState(&num_keys);

    var pressed: u8 = 0;
    if (key_idx < num_keys) {
        pressed = state[key_idx];
    }

    lua.pushBoolean(pressed == 1);
    return 1;
}
