const std = @import("std");
const math = std.math;
const ziglua = @import("ziglua");
const main = @import("../main.zig");
const debug = @import("../debug.zig");
const text_module = @import("text.zig");
const graphics_system = @import("../platform/graphics.zig");

const Vec2 = @import("../math.zig").Vec2;

// const Lua = ziglua.Lua;

var enable_debug_logging = false;

// pub fn makeLib(lua: *Lua) i32 {
//     const funcs = [_]ziglua.FnReg{
//         .{ .name = "clear", .func = ziglua.wrap(clear) },
//         .{ .name = "line", .func = ziglua.wrap(line) },
//         .{ .name = "filled_circle", .func = ziglua.wrap(filled_circle) },
//         .{ .name = "filled_rectangle", .func = ziglua.wrap(filled_rectangle_lua) },
//         .{ .name = "rectangle", .func = ziglua.wrap(rectangle_lua) },
//         .{ .name = "text", .func = ziglua.wrap(text) },
//     };
//
//     lua.newLib(&funcs);
//     return 1;
// }

pub fn clear(pal_color: u32) void {
    if (enable_debug_logging)
        debug.log("Draw: clear {d}", .{pal_color});

    // Four bytes per color
    var color_idx = pal_color * main.palette.channels;

    if (color_idx >= main.palette.height * main.palette.pitch)
        color_idx = main.palette.pitch - 4;

    const r = main.palette.raw[color_idx];
    const g = main.palette.raw[color_idx + 1];
    const b = main.palette.raw[color_idx + 2];

    const color: graphics_system.Color = graphics_system.Color{
        .r = @floatFromInt(r),
        .g = @floatFromInt(g),
        .b = @floatFromInt(b),
    };

    graphics_system.setClearColor(color);
}

pub fn line(start_x :i32, start_y: i32, end_x: i32, end_y: i32, pal_color: u32) void {
    if (enable_debug_logging)
        debug.log("Draw: line({d},{d},{d},{d},{d})", .{ start_x, start_y, end_x, end_y, pal_color });

    // Four bytes per color
    var color_idx = pal_color * main.palette.channels;

    if (color_idx >= main.palette.height * main.palette.pitch)
        color_idx = main.palette.pitch - 4;

    const r = main.palette.raw[color_idx];
    const g = main.palette.raw[color_idx + 1];
    const b = main.palette.raw[color_idx + 2];

    const color: graphics_system.Color = graphics_system.Color{
        .r = @floatFromInt(r),
        .g = @floatFromInt(g),
        .b = @floatFromInt(b),
    };

    const start: Vec2 = Vec2 {
        .x = @floatFromInt(start_x),
        .y = @floatFromInt(start_y),
    };

    const end: Vec2 = Vec2 {
        .x = @floatFromInt(end_x),
        .y = @floatFromInt(end_y),
    };

    graphics_system.line(start, end, color);
}

pub fn filled_circle(x: f32, y: f32, radius: f32, pal_color: u32) void {
    _ = x;
    _ = y;

    // Four bytes per color
    var color_idx = pal_color * main.palette.channels;

    if (color_idx >= main.palette.height * main.palette.pitch)
        color_idx = main.palette.pitch - 4;

    // const r = main.palette.raw[color_idx];
    // const g = main.palette.raw[color_idx + 1];
    // const b = main.palette.raw[color_idx + 2];

    // const renderer = zigsdl.getRenderer();
    // _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF);

    // Dissapear when too small
    if (radius <= 0.25)
        return;

    // In the easy case, just plot a pixel
    if (radius <= 0.5) {
        // _ = sdl.SDL_RenderDrawPoint(renderer, @intFromFloat(x), @intFromFloat(y));
        return;
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

        _ = y_idx;

        offset = std.math.round(offset);

        // Draw mirrored sides!
        // while (y_idx < offset) : (y_idx += 1) {
        //     _ = sdl.SDL_RenderDrawPoint(renderer, @intFromFloat(x + x_idx), @intFromFloat(y + y_idx));
        //     if (x + x_idx != x - x_idx and x_idx <= 0)
        //         _ = sdl.SDL_RenderDrawPoint(renderer, @intFromFloat(x - x_idx), @intFromFloat(y + y_idx));
        // }
    }
}

pub fn rectangle(start_x: i32, start_y: i32, width: i32, height: i32, color: u32) void {
    _ = start_x;
    _ = start_y;
    _ = width;
    _ = height;

    // Four bytes per color
    var color_idx = color * main.palette.channels;

    if (color_idx >= main.palette.height * main.palette.pitch)
        color_idx = main.palette.pitch - 4;

    // const r = main.palette.raw[color_idx];
    // const g = main.palette.raw[color_idx + 1];
    // const b = main.palette.raw[color_idx + 2];
    //
    // const renderer = zigsdl.getRenderer();
    // _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF);

    // const rect = sdl.SDL_Rect{ .x = start_x, .y = start_y, .w = width + 1, .h = height + 1 };
    // _ = sdl.SDL_RenderDrawRect(renderer, &rect);
}

pub fn filled_rectangle(start_x: i32, start_y: i32, width: i32, height: i32, color: u32) void {
    // _ = start_x;
    // _ = start_y;
    // _ = width;
    // _ = height;

    // Four bytes per color
    var color_idx = color * main.palette.channels;

    if (color_idx >= main.palette.height * main.palette.pitch)
        color_idx = main.palette.pitch - 4;

    const r = @as(f32, @floatFromInt(main.palette.raw[color_idx])) / 256.0;
    const g = @as(f32, @floatFromInt(main.palette.raw[color_idx + 1])) / 256.0;
    const b = @as(f32, @floatFromInt(main.palette.raw[color_idx + 2])) / 256.0;

    const c = graphics_system.Color{ .r = r, .g = g, .b = b, .a = 1.0 };

    // const renderer = zigsdl.getRenderer();
    // _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF);

    // const rect = sdl.SDL_Rect{ .x = start_x, .y = start_y, .w = width + 1, .h = height + 1 };
    // _ = sdl.SDL_RenderFillRect(renderer, &rect);

    graphics_system.setDebugDrawTexture(graphics_system.tex_white);
    graphics_system.drawDebugRectangle(@floatFromInt(start_x), @floatFromInt(start_y), @floatFromInt(width), @floatFromInt(height), c);
}

pub fn text(text_string: [*:0]const u8, x_pos: i32, y_pos: i32, color_idx: u32) void {
    text_module.draw(text_string, x_pos, y_pos, color_idx);
}
