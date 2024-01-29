const debug = @import("../debug.zig");
const gfx = @import("graphics.zig");
const modules = @import("../modules.zig");
const math = @import("../math.zig");

/// Keyboard key codes
pub const KeyCodes = enum(i32) {
    INVALID = 0,
    SPACE = 32,
    APOSTROPHE = 39,
    COMMA = 44,
    MINUS = 45,
    PERIOD = 46,
    SLASH = 47,
    _0 = 48,
    _1 = 49,
    _2 = 50,
    _3 = 51,
    _4 = 52,
    _5 = 53,
    _6 = 54,
    _7 = 55,
    _8 = 56,
    _9 = 57,
    SEMICOLON = 59,
    EQUAL = 61,
    A = 65,
    B = 66,
    C = 67,
    D = 68,
    E = 69,
    F = 70,
    G = 71,
    H = 72,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    M = 77,
    N = 78,
    O = 79,
    P = 80,
    Q = 81,
    R = 82,
    S = 83,
    T = 84,
    U = 85,
    V = 86,
    W = 87,
    X = 88,
    Y = 89,
    Z = 90,
    LEFT_BRACKET = 91,
    BACKSLASH = 92,
    RIGHT_BRACKET = 93,
    GRAVE_ACCENT = 96,
    WORLD_1 = 161,
    WORLD_2 = 162,
    ESCAPE = 256,
    ENTER = 257,
    TAB = 258,
    BACKSPACE = 259,
    INSERT = 260,
    DELETE = 261,
    RIGHT = 262,
    LEFT = 263,
    DOWN = 264,
    UP = 265,
    PAGE_UP = 266,
    PAGE_DOWN = 267,
    HOME = 268,
    END = 269,
    CAPS_LOCK = 280,
    SCROLL_LOCK = 281,
    NUM_LOCK = 282,
    PRINT_SCREEN = 283,
    PAUSE = 284,
    F1 = 290,
    F2 = 291,
    F3 = 292,
    F4 = 293,
    F5 = 294,
    F6 = 295,
    F7 = 296,
    F8 = 297,
    F9 = 298,
    F10 = 299,
    F11 = 300,
    F12 = 301,
    F13 = 302,
    F14 = 303,
    F15 = 304,
    F16 = 305,
    F17 = 306,
    F18 = 307,
    F19 = 308,
    F20 = 309,
    F21 = 310,
    F22 = 311,
    F23 = 312,
    F24 = 313,
    F25 = 314,
    KP_0 = 320,
    KP_1 = 321,
    KP_2 = 322,
    KP_3 = 323,
    KP_4 = 324,
    KP_5 = 325,
    KP_6 = 326,
    KP_7 = 327,
    KP_8 = 328,
    KP_9 = 329,
    KP_DECIMAL = 330,
    KP_DIVIDE = 331,
    KP_MULTIPLY = 332,
    KP_SUBTRACT = 333,
    KP_ADD = 334,
    KP_ENTER = 335,
    KP_EQUAL = 336,
    LEFT_SHIFT = 340,
    LEFT_CONTROL = 341,
    LEFT_ALT = 342,
    LEFT_SUPER = 343,
    RIGHT_SHIFT = 344,
    RIGHT_CONTROL = 345,
    RIGHT_ALT = 346,
    RIGHT_SUPER = 347,
    MENU = 348,
};

/// Mouse button codes
pub const MouseButtons = enum(i32) {
    LEFT = 0,
    RIGHT = 1,
    MIDDLE = 2,
};

/// Current input state
const state = struct {
    // current pos
    var mouse_x: f32 = 0;
    var mouse_y: f32 = 0;

    // distance from last tick
    var mouse_dx: f32 = 0;
    var mouse_dy: f32 = 0;

    // distance from last frame
    // split from last tick, because we might want to instantly respond to mouse input
    var mouse_frame_dx: f32 = 0;
    var mouse_frame_dy: f32 = 0;

    // last reported pos
    var last_mouse_x: f32 = 0;
    var last_mouse_y: f32 = 0;

    var keyboard_pressed: [512]bool = undefined;
    var keyboard_just_pressed: [512]bool = undefined;

    var mouse_pressed: [3]bool = undefined;
    var mouse_just_pressed: [3]bool = undefined;
};

/// Registers the input subsystem as a module
pub fn registerModule() !void {
    const inputSubsystem = modules.Module{
        .name = "subsystem.input",
        .post_tick_fn = on_post_tick,
        .post_draw_fn = on_post_draw,
    };

    try modules.registerModule(inputSubsystem);
}

/// Starts up the input subsystem
pub fn init() !void {
    debug.log("Input subsystem starting", .{});
    try registerModule();
}

/// Frees the input subsystem
pub fn deinit() void {
    debug.log("Input subsystem stopping", .{});
}

/// App lifecycle event that happens after ticking
fn on_post_tick() void {
    // reset the 'just pressed' states
    for (0..state.keyboard_just_pressed.len) |i| {
        state.keyboard_just_pressed[i] = false;
    }
    for (0..state.mouse_just_pressed.len) |i| {
        state.mouse_just_pressed[i] = false;
    }

    // keep track of where the mouse was at the end of this frame
    state.last_mouse_x = state.mouse_x;
    state.last_mouse_y = state.mouse_y;

    // reset the mouse delta state.
    state.mouse_dx = 0;
    state.mouse_dy = 0;
}

fn on_post_draw() void {
    // reset the mouse delta state.
    state.mouse_frame_dx = 0;
    state.mouse_frame_dy = 0;
}

/// Returns the current mouse position
pub fn getMousePosition() math.Vec2 {
    return math.Vec2{
        .x = state.mouse_x,
        .y = state.mouse_y,
    };
}

/// Returns whether a key is currently pressed
pub fn isKeyPressed(keycode: KeyCodes) bool {
    const key_idx: usize = @intCast(@intFromEnum(keycode));
    if (key_idx >= state.keyboard_pressed.len)
        return false;

    return state.keyboard_pressed[key_idx];
}

/// Returns whether a key has just been pressed this frame
pub fn isKeyJustPressed(keycode: KeyCodes) bool {
    const key_idx: usize = @intCast(@intFromEnum(keycode));
    if (key_idx >= state.keyboard_just_pressed.len)
        return false;

    return state.keyboard_just_pressed[key_idx];
}

/// Returns whether a mouse button is pressed
pub fn isMouseButtonPressed(button: MouseButtons) bool {
    const button_idx: usize = @intCast(@intFromEnum(button));
    if (button_idx >= state.mouse_pressed.len)
        return false;

    return state.mouse_pressed[button_idx];
}

/// Returns whether a mouse button has just been pressed this frame
pub fn isMouseButtonJustPressed(button: MouseButtons) bool {
    const button_idx: usize = @intCast(@intFromEnum(button));
    if (button_idx >= state.mouse_just_pressed.len)
        return false;

    return state.mouse_just_pressed[button_idx];
}

var is_first_mouse_move = true;

/// Update the mouse movement state
pub fn onMouseMoved(x: f32, y: f32, dx: f32, dy: f32) void {
    // ignore mouse movement if the console is up!
    if (debug.isConsoleVisible())
        return;

    state.mouse_x = x;
    state.mouse_y = y;
    state.mouse_dx += dx;
    state.mouse_dy += dy;
    state.mouse_frame_dx += dx;
    state.mouse_frame_dy += dy;

    // There is no last mouse event until we move once
    if (is_first_mouse_move) {
        is_first_mouse_move = false;
        state.last_mouse_x = x;
        state.last_mouse_y = y;
    }
}

/// Update the keypress state when a key is pressed down
pub fn onKeyDown(keycode: i32) void {
    if (debug.isConsoleVisible()) {
        debug.handleKeyDown(keycode);
        return;
    }

    if (keycode < state.keyboard_pressed.len) {
        const code: usize = @intCast(keycode);
        state.keyboard_pressed[code] = true;
        state.keyboard_just_pressed[code] = true;
    }
}

/// Update the keypress state when a key is let up
pub fn onKeyUp(keycode: i32) void {
    if (keycode < state.keyboard_pressed.len) {
        state.keyboard_pressed[@intCast(keycode)] = false;
    }
}

/// React to keyboard characters being pressed
pub fn onKeyChar(char_code: u32) void {
    if (char_code == '~') {
        debug.setConsoleVisible(!debug.isConsoleVisible());
        return;
    }

    if (debug.isConsoleVisible()) {
        debug.handleKeyboardTextInput(@intCast(char_code));
    }
}

/// Update mouse button state when buttons are pressed
pub fn onMouseDown(btn: i32) void {
    if (btn < state.mouse_pressed.len) {
        const code: usize = @intCast(btn);
        state.mouse_pressed[code] = true;
        state.mouse_just_pressed[code] = true;
    }
}

/// Update mouse button state when buttons are released
pub fn onMouseUp(btn: i32) void {
    if (btn < state.mouse_pressed.len) {
        state.mouse_pressed[@intCast(btn)] = false;
    }
}

/// Difference in mouse position from last frame
pub fn getMouseDelta() math.Vec2 {
    return math.Vec2.new(state.mouse_dx, state.mouse_dy);
}
