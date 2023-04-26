const std = @import("std");
const math = std.math;
const ziglua = @import("ziglua");
const zigsdl = @import("../sdl.zig");
const main = @import("../main.zig");
const gif = @import("../gif.zig");

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
        std.debug.print("Text: Error loading builtin font.\n", .{});
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

    std.debug.print("Text: Loaded builtin font: {d}kb\n", .{text_asset.len / 1000});

    lua.newLib(&funcs);
    return 1;
}

fn text(lua: *Lua) i32 {
    var text_string = lua.toString(1) catch "";
    var x_pos = @floatToInt(u32, lua.toNumber(2) catch 0);
    var y_pos = @floatToInt(u32, lua.toNumber(3) catch 0);
    //var color_idx = @floatToInt(u32, lua.toNumber(4) catch 0);

    // std.debug.print("Text: {s} at {d},{d}\n", .{text_string, x_pos, y_pos});
    drawText(text_string, x_pos, y_pos);

    return 0;
}

pub fn drawText(text_string: [*:0]const u8, x: u32, y: u32) void {
    var x_offset: u32 = 0;
    var y_offset: u32 = 0;

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

        x_offset += 8;

        drawGlyph(char, x + x_offset, y + y_offset);
    }
}

pub fn drawGlyph(char: u8, x: u32, y: u32) void {
    const renderer = zigsdl.getRenderer();
    const draw_width = 8;
    const draw_height = 8;

    // Text spritesheet has 32 columns
    const sheet_columns = 32;
    const picked_column = char % sheet_columns;
    const picked_row = char / sheet_columns;

    const char_x_offset: u32 = picked_column * draw_width;
    const char_y_offset: u32 = picked_row * draw_height;

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
