const std = @import("std");
const math = std.math;
const ziglua = @import("ziglua");
const zigsdl = @import("../sdl.zig");
const main = @import("../main.zig");
const debug = @import("../debug.zig");
const assets = @import("assets.zig");
const gif = @import("../gif.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Lua = ziglua.Lua;

var enable_debug_logging = false;

pub fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "blit", .func = ziglua.wrap(blit) },
    };

    lua.newLib(&funcs);
    return 1;
}

fn blit(lua: *Lua) i32 {
    var texture_handle = @floatToInt(u32, lua.toNumber(1) catch 0);
    var source_x = @floatToInt(i32, lua.toNumber(2) catch 0);
    var source_y = @floatToInt(i32, lua.toNumber(3) catch 0);
    var source_width = @floatToInt(u32, lua.toNumber(4) catch 0);
    var source_height = @floatToInt(u32, lua.toNumber(5) catch 0);
    var dest_x = @floatToInt(i32, lua.toNumber(6) catch 0);
    var dest_y = @floatToInt(i32, lua.toNumber(7) catch 0);

    if (enable_debug_logging)
        debug.log("Blitting texture {d}", .{texture_handle});

    blitTexture(texture_handle, source_x, source_y, source_width, source_height, dest_x, dest_y);
    return 0;
}

pub fn blitTexture(texture_handle: u32, source_x: i32, source_y: i32, source_width: u32, source_height: u32, dest_x: i32, dest_y: i32) void {
    const renderer = zigsdl.getRenderer();

    // Get the texture to draw!
    var loaded_gif: ?gif.GifImage = assets.getTextureFromHandle(texture_handle);
    if (loaded_gif == null)
        return;

    // Found the texture, good to go!
    const gif_image = loaded_gif.?;

    // Also make sure not to draw outside the bounds of the screen
    var res_x: c_int = 0;
    var res_y: c_int = 0;
    _ = sdl.SDL_GetRendererOutputSize(renderer, &res_x, &res_y);

    for (0..source_width) |x_pos| {
        for (0..source_height) |y_pos| {
            const x_pixel_pos = @intCast(i32, x_pos) + source_x;
            const y_pixel_pos = @intCast(i32, y_pos) + source_y;

            if (x_pixel_pos < 0 or x_pixel_pos > gif_image.width)
                continue;
            if (y_pixel_pos < 0 or y_pixel_pos > gif_image.height)
                continue;

            const index = (x_pixel_pos * gif_image.channels) + (y_pixel_pos * @intCast(i32, gif_image.pitch));

            const final_index: usize = @intCast(usize, index);
            if (index + 2 >= gif_image.width * gif_image.height * gif_image.channels)
                continue;

            const r = gif_image.raw[final_index];
            const g = gif_image.raw[final_index + 1];
            const b = gif_image.raw[final_index + 2];

            // Skip black pixels
            if (r == 0 and g == 0 and b == 0)
                continue;

            const x_pixel = @intCast(i32, x_pos) + dest_x;
            const y_pixel = @intCast(i32, y_pos) + dest_y;

            if (x_pixel < 0 or y_pixel < 0 or x_pixel > res_x or y_pixel > res_y)
                continue;

            _ = sdl.SDL_SetRenderDrawColor(renderer, r, g, b, 0xFF);
            _ = sdl.SDL_RenderDrawPoint(renderer, @intCast(c_int, x_pixel), @intCast(c_int, y_pixel));
        }
    }
}
