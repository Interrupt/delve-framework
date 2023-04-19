const std = @import("std");
const ziglua = @import("ziglua");
const zigsdl = @import("../sdl.zig");
const main = @import("../main.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Lua = ziglua.Lua;

var enable_debug_logging = false;

pub fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "clear", .func = ziglua.wrap(clear) },
        .{ .name = "line", .func = ziglua.wrap(line) },
        .{ .name = "filled_circle", .func = ziglua.wrap(filled_circle) },
    };

    lua.newLib(&funcs);
    return 1;
}

fn clear(lua: *Lua) i32 {
    var color_idx = @floatToInt(u32, lua.toNumber(1) catch 0);

    if(enable_debug_logging)
        std.debug.print("Draw: clear {d}\n", .{color_idx});

    // Four bytes per color
    color_idx *= main.palette.channels;

    const r = main.palette.raw[color_idx];
    const g = main.palette.raw[color_idx + 1];
    const b = main.palette.raw[color_idx + 2];

    const renderer = zigsdl.getRenderer();
    _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF );
    _ = sdl.SDL_RenderClear(renderer);

    return 0;
}

fn line(lua: *Lua) i32 {
    var start_x = @floatToInt(c_int, lua.toNumber(1) catch 0);
    var start_y = @floatToInt(c_int, lua.toNumber(2) catch 0);
    var end_x = @floatToInt(c_int, lua.toNumber(3) catch 0);
    var end_y = @floatToInt(c_int, lua.toNumber(4) catch 0);
    var color_idx = @floatToInt(u32, lua.toNumber(5) catch 0);

    if(enable_debug_logging)
        std.debug.print("Draw: line({d},{d},{d},{d},{d})\n", .{start_x, start_y, end_x, end_y, color_idx});

    // Four bytes per color
    color_idx *= main.palette.channels;
    
    const r = main.palette.raw[color_idx];
    const g = main.palette.raw[color_idx + 1];
    const b = main.palette.raw[color_idx + 2];

    const renderer = zigsdl.getRenderer();
    _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF );
    _ = sdl.SDL_RenderDrawLine(renderer, start_x, start_y, end_x, end_y);

    return 0;
}

fn filled_circle(lua: *Lua) i32 {
    var x = @floatToInt(c_int, lua.toNumber(1) catch 0);
    var y = @floatToInt(c_int, lua.toNumber(2) catch 0);
    var radius = @floatToInt(c_int, lua.toNumber(3) catch 0);
    var color_idx = @floatToInt(u32, lua.toNumber(4) catch 0);

    // Four bytes per color
    color_idx *= main.palette.channels;

    if(color_idx >= main.palette.height * main.palette.pitch)
        color_idx = 0;
    
    const r = main.palette.raw[color_idx];
    const g = main.palette.raw[color_idx + 1];
    const b = main.palette.raw[color_idx + 2];

    const renderer = zigsdl.getRenderer();
    _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF );

    var x_idx: c_int = -radius;
    while(x_idx < radius) : (x_idx += 1) {
        var y_idx: c_int = -radius;
        while(y_idx < radius) : (y_idx += 1) {
            _ = sdl.SDL_RenderDrawPoint(renderer, x + x_idx, y + y_idx);
        }
    }

    return 0;
}
