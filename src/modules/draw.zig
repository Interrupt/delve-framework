const std = @import("std");
const math = std.math;
const ziglua = @import("ziglua");
const zigsdl = @import("../sdl.zig");
const main = @import("../main.zig");
const debug = @import("../debug.zig");
const text_module = @import("text.zig");

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
        .{ .name = "filled_rectangle", .func = ziglua.wrap(filled_rectangle_lua) },
        .{ .name = "rectangle", .func = ziglua.wrap(rectangle_lua) },
        .{ .name = "text", .func = ziglua.wrap(text) },
    };

    lua.newLib(&funcs);
    return 1;
}

fn clear(lua: *Lua) i32 {
    var color_idx = @floatToInt(u32, lua.toNumber(1) catch 0);

    if (enable_debug_logging)
        debug.log("Draw: clear {d}", .{color_idx});

    // Four bytes per color
    color_idx *= main.palette.channels;

    if (color_idx >= main.palette.height * main.palette.pitch)
        color_idx = main.palette.pitch - 4;

    const r = main.palette.raw[color_idx];
    const g = main.palette.raw[color_idx + 1];
    const b = main.palette.raw[color_idx + 2];

    const renderer = zigsdl.getRenderer();
    _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF);
    _ = sdl.SDL_RenderClear(renderer);

    return 0;
}

fn line(lua: *Lua) i32 {
    var start_x = @floatToInt(c_int, lua.toNumber(1) catch 0);
    var start_y = @floatToInt(c_int, lua.toNumber(2) catch 0);
    var end_x = @floatToInt(c_int, lua.toNumber(3) catch 0);
    var end_y = @floatToInt(c_int, lua.toNumber(4) catch 0);
    var color_idx = @floatToInt(u32, lua.toNumber(5) catch 0);

    if (enable_debug_logging)
        debug.log("Draw: line({d},{d},{d},{d},{d})", .{ start_x, start_y, end_x, end_y, color_idx });

    // Four bytes per color
    color_idx *= main.palette.channels;

    if (color_idx >= main.palette.height * main.palette.pitch)
        color_idx = main.palette.pitch - 4;

    const r = main.palette.raw[color_idx];
    const g = main.palette.raw[color_idx + 1];
    const b = main.palette.raw[color_idx + 2];

    const renderer = zigsdl.getRenderer();
    _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF);
    _ = sdl.SDL_RenderDrawLine(renderer, start_x, start_y, end_x, end_y);

    return 0;
}

fn filled_circle(lua: *Lua) i32 {
    var x = lua.toNumber(1) catch 0;
    var y = lua.toNumber(2) catch 0;
    var radius = lua.toNumber(3) catch 0;
    var color_idx = @floatToInt(u32, lua.toNumber(4) catch 0);

    // Four bytes per color
    color_idx *= main.palette.channels;

    if (color_idx >= main.palette.height * main.palette.pitch)
        color_idx = main.palette.pitch - 4;

    const r = main.palette.raw[color_idx];
    const g = main.palette.raw[color_idx + 1];
    const b = main.palette.raw[color_idx + 2];

    const renderer = zigsdl.getRenderer();
    _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF);

    // Dissapear when too small
    if (radius <= 0.25)
        return 0;

    // In the easy case, just plot a pixel
    if (radius <= 0.5) {
        _ = sdl.SDL_RenderDrawPoint(renderer, @floatToInt(c_int, x), @floatToInt(c_int, y));
        return 0;
    }

    // Harder case, draw the circle in vertical strips
    // Can figure out the height of the strip based on the xpos via good old pythagoros
    // Y = 2 * sqrt(R^2 - X^2)
    var x_idx: f64 = -radius;
    while (x_idx < 1) : (x_idx += 1) {
        var offset = math.sqrt(math.pow(f64, radius, 2) - math.pow(f64, x_idx, 2));
        var y_idx: f64 = -offset;
        if (offset <= 0.5)
            continue;

        offset = std.math.round(offset);

        // Draw mirrored sides!
        while (y_idx < offset) : (y_idx += 1) {
            _ = sdl.SDL_RenderDrawPoint(renderer, @floatToInt(c_int, x + x_idx), @floatToInt(c_int, y + y_idx));
            if (x + x_idx != x - x_idx and x_idx <= 0)
                _ = sdl.SDL_RenderDrawPoint(renderer, @floatToInt(c_int, x - x_idx), @floatToInt(c_int, y + y_idx));
        }
    }

    return 0;
}

fn filled_rectangle_lua(lua: *Lua) i32 {
    var start_x = @floatToInt(i32, lua.toNumber(1) catch 0);
    var start_y = @floatToInt(i32, lua.toNumber(2) catch 0);
    var width = @floatToInt(i32, lua.toNumber(3) catch 0);
    var height = @floatToInt(i32, lua.toNumber(4) catch 0);
    var color_idx = @floatToInt(u32, lua.toNumber(4) catch 0);

    filled_rectangle(start_x, start_y, width, height, color_idx);

    return 0;
}

fn rectangle_lua(lua: *Lua) i32 {
    var start_x = @floatToInt(i32, lua.toNumber(1) catch 0);
    var start_y = @floatToInt(i32, lua.toNumber(2) catch 0);
    var width = @floatToInt(i32, lua.toNumber(3) catch 0);
    var height = @floatToInt(i32, lua.toNumber(4) catch 0);
    var color_idx = @floatToInt(u32, lua.toNumber(4) catch 0);

    rectangle(start_x, start_y, width, height, color_idx);

    return 0;
}

pub fn rectangle(start_x: i32, start_y: i32, width: i32, height: i32, color: u32) void {
    // Four bytes per color
    var color_idx = color * main.palette.channels;

    if (color_idx >= main.palette.height * main.palette.pitch)
        color_idx = main.palette.pitch - 4;

    const r = main.palette.raw[color_idx];
    const g = main.palette.raw[color_idx + 1];
    const b = main.palette.raw[color_idx + 2];

    const renderer = zigsdl.getRenderer();
    _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF);

    const rect = sdl.SDL_Rect{ .x = start_x, .y = start_y, .w = width + 1, .h = height + 1 };
    _ = sdl.SDL_RenderDrawRect(renderer, &rect);
}

pub fn filled_rectangle(start_x: i32, start_y: i32, width: i32, height: i32, color: u32) void {
    // Four bytes per color
    var color_idx = color * main.palette.channels;

    if (color_idx >= main.palette.height * main.palette.pitch)
        color_idx = main.palette.pitch - 4;

    const r = main.palette.raw[color_idx];
    const g = main.palette.raw[color_idx + 1];
    const b = main.palette.raw[color_idx + 2];

    const renderer = zigsdl.getRenderer();
    _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF);

    const rect = sdl.SDL_Rect{ .x = start_x, .y = start_y, .w = width + 1, .h = height + 1 };
    _ = sdl.SDL_RenderFillRect(renderer, &rect);
}

fn text(lua: *Lua) i32 {
    return text_module.text(lua);
}
