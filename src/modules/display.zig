const std = @import("std");
const ziglua = @import("ziglua");
const zigsdl = @import("../sdl.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Lua = ziglua.Lua;

var enable_debug_logging = false;

pub fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "set_resolution", .func = ziglua.wrap(set_resolution) },
        .{ .name = "set_size", .func = ziglua.wrap(set_size) },
    };

    lua.newLib(&funcs);
    return 1;
}

fn set_resolution(lua: *Lua) i32 {
    var res_x = @floatToInt(c_int, lua.toNumber(1) catch 0);
    var res_y = @floatToInt(c_int, lua.toNumber(2) catch 0);

    var scale_x: f32 = 0;
    var scale_y: f32 = 0;
    _ = sdl.SDL_RenderGetScale(zigsdl.getRenderer(), &scale_x, &scale_y);

    res_x *= @floatToInt(c_int, scale_x);
    res_y *= @floatToInt(c_int, scale_y);

    const window = zigsdl.getWindow();
    _ = sdl.SDL_SetWindowSize(window, res_x, res_y);

    return 0;
}

fn set_size(lua: *Lua) i32 {
    var res_x = @floatToInt(c_int, lua.toNumber(1) catch 0);
    var res_y = @floatToInt(c_int, lua.toNumber(2) catch 0);

    // var scale_x: f32 = 0;
    // var scale_y: f32 = 0;
    // _ = sdl.SDL_RenderGetScale(zigsdl.getRenderer(), &scale_x, &scale_y);

    const window = zigsdl.getWindow();
    _ = sdl.SDL_SetWindowSize(window, res_x, res_y);

    return 0;
}
