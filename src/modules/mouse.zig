const std = @import("std");
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
        
    // Return the x & y positions!
    lua.pushNumber(@intToFloat(f32, x));
    lua.pushNumber(@intToFloat(f32, y));
    return 2;
}
