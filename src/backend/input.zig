const debug = @import("../debug.zig");
//const zigsdl = @import("../sdl.zig");
const gfx = @import("graphics.zig");

// const sdl = @cImport({
//     @cInclude("SDL2/SDL.h");
// });

// const MouseButtons = [_]u32 {
//     sdl.SDL_BUTTON_LMASK,
//     sdl.SDL_BUTTON_MMASK,
//     sdl.SDL_BUTTON_RMASK,
//     sdl.SDL_BUTTON_X1MASK,
//     sdl.SDL_BUTTON_X2MASK,
// };

const state = struct {
    var mouse_x: f32 = 0;
    var mouse_y: f32 = 0;
};

pub fn init() ! void {
    debug.log("Input subsystem starting", .{});
}

pub fn deinit() void {
    debug.log("Input subsystem stopping", .{});
}

pub fn processInput() void {
    //zigsdl.processEvents();
}

pub fn getMousePosition() gfx.Vector2 {
    return gfx.Vector2 {
        .x = state.mouse_x,
        .y = state.mouse_y,
    };
}

pub fn isKeyPressed(key_idx: usize) bool {
    _ = key_idx;
    // var num_keys: c_int = 0;
    // var state = sdl.SDL_GetKeyboardState(&num_keys);
    //
    // var pressed: bool= false;
    // if (key_idx < num_keys) {
    //     pressed = state[key_idx] != 0;
    // }
    //
    // return pressed;

    return false;
}

pub fn isMouseButtonPressed(button_idx: usize) bool {
    _ = button_idx;
    // const button_state: u32 = sdl.SDL_GetMouseState(null, null);
    // return (button_state & MouseButtons[button_idx]) != 0;

    return false;
}

pub fn onMouseMoved(x: f32, y: f32) void {
    state.mouse_x = x;
    state.mouse_y = y;
}
