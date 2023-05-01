const std = @import("std");
const math = std.math;
const ziglua = @import("ziglua");
const zigsdl = @import("../sdl.zig");
const main = @import("../main.zig");
const gif = @import("../gif.zig");
const debug = @import("../debug.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Lua = ziglua.Lua;

const text_asset = @embedFile("../static/font.gif");
var text_gif: gif.GifImage = undefined;
var text_surface: *sdl.SDL_Surface = undefined;

pub fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "draw", .func = ziglua.wrap(text) },
    };

    text_gif = gif.loadBytes(text_asset) catch {
        debug.log("Text: Error loading builtin font.\n", .{});
        return 0;
    };

    text_surface = sdl.SDL_CreateRGBSurfaceFrom(
        text_gif.raw.ptr,
        @intCast(c_int, text_gif.width),
        @intCast(c_int, text_gif.height),
        @intCast(c_int, text_gif.channels * 8),     // depth
        @intCast(c_int, text_gif.pitch),            // pitch
        0x000000ff,                                 // red mask
        0x0000ff00,                                 // green mask
        0x00ff0000,                                 // blue mask
        0);                                         // alpha mask

    debug.log("Text: Loaded builtin font: {d}kb\n", .{text_asset.len / 1000});

    lua.newLib(&funcs);
    return 1;
}

fn text(lua: *Lua) i32 {
    var text_string = lua.toString(1) catch "";
    var x_pos = lua.toNumber(2) catch 0;
    var y_pos = lua.toNumber(3) catch 0;
    var color_idx = @floatToInt(u32, lua.toNumber(4) catch 0);

    drawText(text_string, @floatToInt(i32, x_pos), @floatToInt(i32, y_pos), color_idx);

    return 0;
}

pub fn drawText(text_string: [*:0]const u8, x: i32, y: i32, color: u32) void {
    var x_offset: i32 = 0;
    var y_offset: i32 = 0;

    var idx: u32 = 0;

    // Draw until hitting the sentinel
    while(true) {
        var char: u8 = text_string[idx];
        idx += 1;

        if (char == 0)
            break;

        if (char == '\n') {
            x_offset = 0;
            y_offset += 8;
            continue;
        }

        drawGlyph(char, x + x_offset, y + y_offset, color);
        x_offset += 8;
    }
}

pub fn drawGlyph(char: u8, x: i32, y: i32, color: u32) void {
    const renderer = zigsdl.getRenderer();
    const draw_width = 8;
    const draw_height = 8;

    // Text spritesheet has 32 columns
    const sheet_columns = 32;
    const picked_column = char % sheet_columns;
    const picked_row = char / sheet_columns;

    const char_x_offset: u32 = picked_column * draw_width;
    const char_y_offset: u32 = picked_row * draw_height;

    var res_x: c_int = 0;
    var res_y: c_int = 0;
    _ = sdl.SDL_GetRendererOutputSize(renderer, &res_x, &res_y);

    // Four bytes per color
    var color_idx = color * main.palette.channels;

    if(color_idx >= main.palette.height * main.palette.pitch)
        color_idx = 0;

    const pal_r = main.palette.raw[color_idx];
    const pal_g = main.palette.raw[color_idx + 1];
    const pal_b = main.palette.raw[color_idx + 2];
    _ = sdl.SDL_SetRenderDrawColor(renderer, pal_r, pal_g, pal_b, 0xFF );

    for (char_x_offset .. char_x_offset + draw_width) |x_pos| {
        for (char_y_offset .. char_y_offset + draw_height) |y_pos| {
            const index = (x_pos * text_gif.channels) + (y_pos * text_gif.pitch);
            const r = text_gif.raw[index];
            const g = text_gif.raw[index + 1];
            const b = text_gif.raw[index + 2];

            // Skip black pixels
            if(r == 0 and g == 0 and b == 0)
                continue;

            const x_pixel = x + @intCast(i32, x_pos - char_x_offset);
            const y_pixel = y + @intCast(i32, y_pos - char_y_offset);

            if(x_pixel < 0 or y_pixel < 0 or x_pixel > res_x or y_pixel > res_y)
                continue;

            // _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF );
            _ = sdl.SDL_RenderDrawPoint(renderer, @intCast(c_int, x_pixel), @intCast(c_int, y_pixel));
        }
    }
}

pub fn drawSprite(x: u32, y: u32) void {
    const renderer = zigsdl.getRenderer();
    const draw_width = text_gif.width;
    const draw_height = text_gif.height;

    const char_x_offset = 0;
    const char_y_offset = 0;

    for (char_x_offset .. char_x_offset + draw_width) |x_pos| {
        for (char_y_offset .. char_y_offset + draw_height) |y_pos| {
            const index = (x_pos * text_gif.channels) + (y_pos * text_gif.pitch);
            const r = text_gif.raw[index];
            const g = text_gif.raw[index + 1];
            const b = text_gif.raw[index + 2];

            // Skip black pixels
            if(r == 0 and g == 0 and b == 0)
                continue;

            _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF );
            _ = sdl.SDL_RenderDrawPoint(renderer,
                @intCast(c_int, x + x_pos - char_x_offset),
                @intCast(c_int, y + y_pos - char_y_offset));
        }
    }
}
