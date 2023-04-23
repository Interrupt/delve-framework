const std = @import("std");
const zigsdl = @import("../sdl.zig");
const ziglua = @import("ziglua");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Lua = ziglua.Lua;

const MouseButtons = [_]u32 {
    sdl.SDL_BUTTON_LMASK,
    sdl.SDL_BUTTON_MMASK,
    sdl.SDL_BUTTON_RMASK,
    sdl.SDL_BUTTON_X1MASK,
    sdl.SDL_BUTTON_X2MASK,
};

pub fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "position", .func = ziglua.wrap(position) },
        .{ .name = "button", .func = ziglua.wrap(button) },
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

// Get Mouse Button Pressed State
fn button(lua: *Lua) i32 {
    var button_idx = @floatToInt(u5, lua.toNumber(1) catch 0);

    const button_state: u32 = sdl.SDL_GetMouseState(null, null);
    const is_pressed = (button_state & MouseButtons[button_idx]) != 0;

    lua.pushBoolean(is_pressed);
    return 1;
}
