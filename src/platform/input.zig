const debug = @import("../debug.zig");
const gfx = @import("graphics.zig");
const math = @import("../math.zig");
const modules = @import("../modules.zig");

const state = struct {
    var mouse_x: f32 = 0;
    var mouse_y: f32 = 0;

    var keyboard_pressed: [512]bool = undefined;
    var mouse_pressed: [3]bool = undefined;

    var keyboard_just_pressed: [512]bool = undefined;
    var mouse_just_pressed: [3]bool = undefined;
};

/// Registers the input subsystem as a module
pub fn registerModule() !void {
    const inputSubsystem = modules.Module {
        .name = "input_subystem",
        .tick_fn = on_tick,
    };

    try modules.registerModule(inputSubsystem);
}

pub fn init() !void {
    debug.log("Input subsystem starting", .{});
    try registerModule();
}

pub fn deinit() void {
    debug.log("Input subsystem stopping", .{});
}

pub fn on_tick(tick: u64) void {
    _ = tick;
    // reset the 'just pressed' states
    for(0 .. state.keyboard_just_pressed.len) |i| {
        state.keyboard_just_pressed[i] = false;
    }
    for(0 .. state.mouse_just_pressed.len) |i| {
        state.mouse_just_pressed[i] = false;
    }
}

pub fn getMousePosition() math.Vec2 {
    return math.Vec2 {
        .x = state.mouse_x,
        .y = state.mouse_y,
    };
}

pub fn isKeyPressed(key_idx: usize) bool {
    if(key_idx >= state.keyboard_pressed.len)
        return false;

    return state.keyboard_pressed[key_idx];
}

pub fn isKeyJustPressed(key_idx: usize) bool {
    if(key_idx >= state.keyboard_just_pressed.len)
        return false;

    return state.keyboard_just_pressed[key_idx];
}

pub fn isMouseButtonPressed(button_idx: usize) bool {
    if(button_idx >= state.mouse_pressed.len)
        return false;

    return state.mouse_pressed[button_idx];
}

pub fn isMouseButtonJustPressed(button_idx: usize) bool {
    if(button_idx >= state.mouse_just_pressed.len)
        return false;

    return state.mouse_just_pressed[button_idx];
}

pub fn onMouseMoved(x: f32, y: f32) void {
    state.mouse_x = x;
    state.mouse_y = y;
}

pub fn onKeyDown(keycode: i32) void {
    if(keycode < state.keyboard_pressed.len) {
        const code: usize = @intCast(keycode);
        state.keyboard_pressed[code] = true;
        state.keyboard_just_pressed[code] = true;
    }

    if(debug.isConsoleVisible()) {
        debug.handleKeyDown(keycode);
    }
}

pub fn onKeyUp(keycode: i32) void {
    if(keycode < state.keyboard_pressed.len) {
        state.keyboard_pressed[@intCast(keycode)] = false;
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
    if(btn < state.mouse_pressed.len) {
        const code: usize = @intCast(btn);
        state.mouse_pressed[code] = true;
        state.mouse_just_pressed[code] = true;
    }
}

pub fn onMouseUp(btn: i32) void {
    if(btn < state.mouse_pressed.len) {
        state.mouse_pressed[@intCast(btn)] = false;
    }
}
