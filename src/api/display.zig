const std = @import("std");
const fmt = @import("fmt");
const ziglua = @import("ziglua");
const debug = @import("../debug.zig");
const scripting = @import("../scripting.zig");

const Lua = ziglua.Lua;

var enable_debug_logging = false;

// pub fn bindLib() void {
//     const funcs = comptime [_]scripting.ScriptFn{
//         scripting.wrapFn("set_resolution", set_resolution),
//         scripting.wrapFn("set_size", test_something),
//     };
//     scripting.bindLibrary("display", &funcs);
// }

pub fn set_resolution(res_x: i32, res_y: i32) void {
    // var scale_x: f32 = 1.0;
    // var scale_y: f32 = 1.0;

    debug.log("set resolution: {d}x{d}\n", .{res_x, res_y});
    // _ = sdl.SDL_RenderGetScale(zigsdl.getRenderer(), &scale_x, &scale_y);

    // res_x *= @intFromFloat(scale_x);
    // res_y *= @intFromFloat(scale_y);

    // const window = zigsdl.getWindow();
    // _ = sdl.SDL_SetWindowSize(window, res_x, res_y);
}

// pub fn set_size(lua: *Lua) i32 {
//     var res_x: c_int = @intFromFloat(lua.toNumber(1) catch 0);
//     var res_y: c_int = @intFromFloat(lua.toNumber(2) catch 0);
//
//     _ = res_x;
//     _ = res_y;
//
//     // var scale_x: f32 = 0;
//     // var scale_y: f32 = 0;
//     // _ = sdl.SDL_RenderGetScale(zigsdl.getRenderer(), &scale_x, &scale_y);
//
//     // const window = zigsdl.getWindow();
//     // _ = sdl.SDL_SetWindowSize(window, res_x, res_y);
//
//     return 0;
// }

pub fn set_size(one: i32, two: i32) void {
    debug.log("API Test 2: {d}x{d}\n", .{one, two});
}

pub fn test_something(one: i32, two: i32) void {
    debug.log("API Test: {d}x{d}\n", .{one, two});
}
