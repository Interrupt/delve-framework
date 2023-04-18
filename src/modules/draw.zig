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
        .{ .name = "clear", .func = ziglua.wrap(clear) },
        .{ .name = "line", .func = ziglua.wrap(line) },
    };

    lua.newLib(&funcs);
    return 1;
}

fn clear(lua: *Lua) i32 {
    var color_idx = lua.toNumber(1) catch 0;

    if(enable_debug_logging)
        std.debug.print("Draw: clear {d}\n", .{color_idx});

    const renderer = zigsdl.getRenderer();
    _ = sdl.SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF );
    _ = sdl.SDL_RenderClear(renderer);

    return 0;
}

fn line(lua: *Lua) i32 {
    var start_x = @floatToInt(c_int, lua.toNumber(1) catch 0);
    var start_y = @floatToInt(c_int, lua.toNumber(2) catch 0);
    var end_x = @floatToInt(c_int, lua.toNumber(3) catch 0);
    var end_y = @floatToInt(c_int, lua.toNumber(4) catch 0);
    var color_idx = lua.toNumber(5) catch 0;

    if(enable_debug_logging)
        std.debug.print("Draw: line({d},{d},{d},{d},{d})\n", .{start_x, start_y, end_x, end_y, color_idx});

    const renderer = zigsdl.getRenderer();
    _ = sdl.SDL_SetRenderDrawColor(renderer, 0xFF, 0x00, 0x00, 0xFF );
    _ = sdl.SDL_RenderDrawLine(renderer, start_x, start_y, end_x, end_y);

    return 0;
}
