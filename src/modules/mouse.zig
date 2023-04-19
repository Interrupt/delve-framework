const std = @import("std");
const zigsdl = @import("../sdl.zig");
const ziglua = @import("ziglua");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Lua = ziglua.Lua;

pub fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "position", .func = ziglua.wrap(position) },
    };

    lua.newLib(&funcs);
    return 1;
}

// Get Mouse Position
fn position(lua: *Lua) i32 {

    var x: c_int = 0;
    var y: c_int = 0;
    _ = sdl.SDL_GetMouseState(&x, &y);

    var scale_x: f32 = 0;
    var scale_y: f32 = 0;

    _ = sdl.SDL_RenderGetScale(zigsdl.getRenderer(), &scale_x, &scale_y);

    // Scale position based on the render size
    const mouse_x = @intToFloat(f32, x) / scale_x;
    const mouse_y = @intToFloat(f32, y) / scale_y;
        
    // Return the x & y positions!
    lua.pushNumber(mouse_x);
    lua.pushNumber(mouse_y);
    return 2;
}
