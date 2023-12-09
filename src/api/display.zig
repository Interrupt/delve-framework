const std = @import("std");
const fmt = @import("fmt");
const ziglua = @import("ziglua");
const debug = @import("../debug.zig");
const scripting = @import("../scripting.zig");

const Lua = ziglua.Lua;

var enable_debug_logging = false;

pub fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        scripting.makeLuaBinding("set_resolution", set_resolution),
        scripting.makeLuaBinding("set_size", test_something),
    };

    lua.newLib(&funcs);
    return 1;
}

fn set_resolution(res_x: i32, res_y: i32) void {
    // var scale_x: f32 = 1.0;
    // var scale_y: f32 = 1.0;

    debug.log("set resolution: {d}x{d}\n", .{res_x, res_y});
    // _ = sdl.SDL_RenderGetScale(zigsdl.getRenderer(), &scale_x, &scale_y);

    // res_x *= @intFromFloat(scale_x);
    // res_y *= @intFromFloat(scale_y);

    // const window = zigsdl.getWindow();
    // _ = sdl.SDL_SetWindowSize(window, res_x, res_y);
}

fn set_size(lua: *Lua) i32 {
    var res_x: c_int = @intFromFloat(lua.toNumber(1) catch 0);
    var res_y: c_int = @intFromFloat(lua.toNumber(2) catch 0);

    _ = res_x;
    _ = res_y;

    // var scale_x: f32 = 0;
    // var scale_y: f32 = 0;
    // _ = sdl.SDL_RenderGetScale(zigsdl.getRenderer(), &scale_x, &scale_y);

    // const window = zigsdl.getWindow();
    // _ = sdl.SDL_SetWindowSize(window, res_x, res_y);

    return 0;
}

fn test_something(one: i32, two: i32) void {
    debug.log("API Test: {d}x{d}\n", .{one, two});
}
