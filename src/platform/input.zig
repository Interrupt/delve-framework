const debug = @import("../debug.zig");
const gfx = @import("graphics.zig");
const math = @import("../math.zig");

const state = struct {
    var mouse_x: f32 = 0;
    var mouse_y: f32 = 0;
    var keyboard_state: [512]bool = undefined;
    var mouse_state: [3]bool = undefined;
};

pub fn init() ! void {
    debug.log("Input subsystem starting", .{});
}

pub fn deinit() void {
    debug.log("Input subsystem stopping", .{});
}

pub fn getMousePosition() math.Vec2 {
    return math.Vec2 {
        .x = state.mouse_x,
        .y = state.mouse_y,
    };
}

pub fn isKeyPressed(key_idx: usize) bool {
    if(key_idx >= state.keyboard_state.len)
        return false;

    return state.keyboard_state[key_idx];
}

pub fn isMouseButtonPressed(button_idx: usize) bool {
    if(button_idx >= state.mouse_state.len)
        return false;

    return state.mouse_state[button_idx];
}

pub fn onMouseMoved(x: f32, y: f32) void {
    state.mouse_x = x;
    state.mouse_y = y;
}

pub fn onKeyDown(keycode: i32) void {
    if(keycode < state.keyboard_state.len) {
        state.keyboard_state[@intCast(keycode)] = true;
    }

    if(debug.isConsoleVisible()) {
        debug.handleKeyDown(keycode);
    }
}

pub fn onKeyUp(keycode: i32) void {
    if(keycode < state.keyboard_state.len) {
        state.keyboard_state[@intCast(keycode)] = false;
    }
}

pub fn onKeyChar(char_code: u32) void {
    if(char_code == '~') {
        debug.setConsoleVisible(!debug.isConsoleVisible());
        return;
    }

    if(debug.isConsoleVisible()) {
        debug.handleKeyboardTextInput(@intCast(char_code));
    }
}

pub fn onMouseDown(btn: i32) void {
    if(btn < state.mouse_state.len) {
        state.mouse_state[@intCast(btn)] = true;
    }
}

pub fn onMouseUp(btn: i32) void {
    if(btn < state.mouse_state.len) {
        state.mouse_state[@intCast(btn)] = false;
    }
}
