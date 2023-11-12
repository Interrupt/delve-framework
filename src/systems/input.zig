const debug = @import("../debug.zig");
const zigsdl = @import("../sdl.zig");
const gfx = @import("graphics.zig");

const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const MouseButtons = [_]u32 {
    sdl.SDL_BUTTON_LMASK,
    sdl.SDL_BUTTON_MMASK,
    sdl.SDL_BUTTON_RMASK,
    sdl.SDL_BUTTON_X1MASK,
    sdl.SDL_BUTTON_X2MASK,
};

pub fn init() ! void {
    debug.log("Input subsystem starting", .{});
}

pub fn deinit() void {
    debug.log("Input subsystem stopping", .{});
}

pub fn processInput() void {
    zigsdl.processEvents();
}

pub fn getMousePosition() gfx.Vector2 {
    var x: c_int = 0;
    var y: c_int = 0;
    _ = sdl.SDL_GetMouseState(&x, &y);

    var scale_x: f32 = 0;
    var scale_y: f32 = 0;
    _ = sdl.SDL_RenderGetScale(zigsdl.getRenderer(), &scale_x, &scale_y);

    // Scale position based on the render size
    const mouse_x = @as(f32, @floatFromInt(x)) / scale_x;
    const mouse_y = @as(f32, @floatFromInt(y)) / scale_y;

    return gfx.Vector2 {
        .x = mouse_x,
        .y = mouse_y,
    };
}

pub fn isKeyPressed(key_idx: usize) bool {
    var num_keys: c_int = 0;
    var state = sdl.SDL_GetKeyboardState(&num_keys);

    var pressed: bool= false;
    if (key_idx < num_keys) {
        pressed = state[key_idx] != 0;
    }

    return pressed;
}

pub fn isMouseButtonPressed(button_idx: usize) bool {
    const button_state: u32 = sdl.SDL_GetMouseState(null, null);
    return (button_state & MouseButtons[button_idx]) != 0;
}
