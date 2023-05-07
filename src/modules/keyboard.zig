const std = @import("std");
const zigsdl = @import("../sdl.zig");
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
    var char: c_int = 0;
    _ = char;

    lua.pushBoolean(false);
    return 1;
}

// fn button(lua: *Lua) i32 {
//     var button_idx = @floatToInt(u5, lua.toNumber(1) catch 0);
//
//     const button_state: u32 = sdl.SDL_GetMouseState(null, null);
//     const is_pressed = (button_state & MouseButtons[button_idx]) != 0;
//
//     lua.pushBoolean(is_pressed);
//     return 1;
// }
