const std = @import("std");
const assert = std.debug.assert;
const app = @import("../../app.zig");
const debug = @import("../../debug.zig");
const platform = @import("../app.zig");
const input = @import("../input.zig");
const cimgui = @import("cimgui");

const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const simgui = sokol.imgui;

const target = @import("builtin").target;

const c = @cImport({
    @cInclude("SDL3/SDL.h");
    if (target.os.tag == .emscripten) @cInclude("emscripten.h");
});

var window: *c.SDL_Window = undefined;
var gl_context: c.SDL_GLContext = undefined;
var app_config: app.AppConfig = undefined;
var hooks: platform.PlatformHooks = undefined;
var running: bool = false;

pub fn init(cfg: platform.PlatformHooks) void {
    debug.log("Initializing SDL Backend", .{});

    if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_GAMEPAD)) {
        debug.log("ERROR: Failed to initialize SDL - {s}", .{c.SDL_GetError()});
        std.process.exit(1);
    }
    debug.log("SDL initialized", .{});

    hooks = cfg;
}

pub fn deinit() void {
    debug.log("Deinitializing SDL App Backend", .{});
    window = undefined;
    gl_context = undefined;
    app_config = undefined;
    hooks = undefined;
    c.SDL_Quit();
}

fn sokol_init() void {
    debug.log("Sokol graphics context initializing", .{});

    // Leaving the OpenGL context initialization in "sokol" init, because it applies to the sokol case
    // and not the SDL_gpu case.

    assert(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_FLAGS, c.SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG));
    assert(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE));
    assert(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 3));
    assert(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 3));
    assert(c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1));

    gl_context = c.SDL_GL_CreateContext(window) orelse {
        debug.err("Failed to create GL context: {s}", .{c.SDL_GetError()});
        std.process.exit(1);
    };

    if (!c.SDL_GL_MakeCurrent(window, gl_context)) {
        debug.err("Failed to bind GL context: {s}", .{c.SDL_GetError()});
        std.process.exit(1);
    }

    sg.setup(.{
        // TODO
        //.environment = sglue.environment(),
        .logger = .{
            .func = slog.func,
        },
        .buffer_pool_size = app_config.buffer_pool_size, // sokol default is 128
        .shader_pool_size = app_config.shader_pool_size, // sokol default is 64
        .image_pool_size = app_config.image_pool_size, // sokol default is 128
        .pipeline_pool_size = app_config.pipeline_pool_size, // sokol default is 64
        .sampler_pool_size = app_config.sampler_pool_size, // sokol default is 64
        .attachments_pool_size = app_config.pass_pool_size, // sokol default is 16,
    });

    simgui.setup(.{
        .logger = .{
            .func = slog.func,
        },
    });

    const io = cimgui.igGetIO();
    // platform_io.Platform_SetClipboardTextFn = ImGui_ImplSDL3_SetClipboardText;
    // platform_io.Platform_GetClipboardTextFn = ImGui_ImplSDL3_GetClipboardText;
    io.*.SetPlatformImeDataFn = imguiSetPlatformImeData;

    const viewport = cimgui.igGetMainViewport();
    viewport.*.PlatformHandleRaw = @ptrCast(window);

    debug.log("Sokol setup backend: {}", .{sg.queryBackend()});

    // call the callback that will tell everything else to start up
    hooks.on_init_fn();
}

fn cleanup() void {
    hooks.on_cleanup_fn();
    sg.shutdown();
}

fn frame() void {
    hooks.on_frame_fn();
}

pub fn startMainLoop(config: app.AppConfig) void {
    app_config = config;

    debug.log("Creating SDL Window", .{});

    // TODO: For SDL_gpu we'll want Vulkan instead (or Metal... others?)
    const window_flags = c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_HIGH_PIXEL_DENSITY;

    window = c.SDL_CreateWindow(config.title, config.width, config.height, window_flags) orelse {
        debug.err("ERROR: Failed to create SDL window - {s}", .{c.SDL_GetError()});
        return;
    };
    _ = c.SDL_ShowWindow(window);
    _ = c.SDL_RaiseWindow(window);

    defer _ = c.SDL_DestroyWindow(window);

    sokol_init();
    defer _ = c.SDL_GL_DestroyContext(gl_context);

    debug.log("SDL app starting main loop", .{});

    const tick = struct {
        pub fn call() callconv(.C) void {
            var event: c.SDL_Event = undefined;
            while (c.SDL_PollEvent(&event)) {
                if (imguiHandleEvent(&event)) {
                    continue;
                }
                switch (event.type) {
                    c.SDL_EVENT_QUIT => {
                        if (target.os.tag == .emscripten) {
                            c.emscripten_cancel_main_loop();
                        } else {
                            running = false;
                        }
                    },
                    c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                        input.onMouseDown(event.button.button);
                    },
                    c.SDL_EVENT_MOUSE_BUTTON_UP => {
                        input.onMouseUp(event.button.button);
                    },
                    c.SDL_EVENT_MOUSE_MOTION => {
                        input.onMouseMoved(event.motion.x, event.motion.y, event.motion.xrel, event.motion.yrel);
                    },
                    c.SDL_EVENT_KEY_DOWN => {
                        if (!event.key.repeat) {
                            const code = sdlkToKeyCode(&event.key);
                            input.onKeyDown(@intFromEnum(code));
                        }
                    },
                    c.SDL_EVENT_KEY_UP => {
                        const code = sdlkToKeyCode(&event.key);
                        input.onKeyUp(@intFromEnum(code));
                    },
                    else => {},
                }
            }

            frame();
            assert(c.SDL_GL_SwapWindow(window));
        }
    }.call;

    if (target.os.tag == .emscripten) {
        c.emscripten_set_main_loop(tick, 0, 1);
    } else {
        running = true;
        while (running) {
            tick();
        }
    }

    cleanup();
}

pub fn getWidth() i32 {
    var w: c_int = 0;
    var _h: c_int = 0;
    if (!c.SDL_GetWindowSize(window, &w, &_h)) {
        debug.err("Unable to get SDL window size: {s}", .{c.SDL_GetError()});
    }
    return w;
}

pub fn getHeight() i32 {
    var _w: c_int = 0;
    var h: c_int = 0;
    if (!c.SDL_GetWindowSize(window, &_w, &h)) {
        debug.log("Unable to get SDL window size: {s}", .{c.SDL_GetError()});
    }
    return h;
}

pub fn captureMouse(captured: bool) void {
    if (!c.SDL_SetWindowRelativeMouseMode(window, captured)) {
        debug.log("Unable to capture mouse: {s}", .{c.SDL_GetError()});
    }

    if (captured) {
        _ = c.SDL_HideCursor();
    } else {
        _ = c.SDL_ShowCursor();
    }
}

pub fn startImguiFrame() void {
    var w: c_int = 0;
    var h: c_int = 0;
    if (!c.SDL_GetWindowSize(window, &w, &h)) {
        debug.log("Unable to get SDL window size: {s}", .{c.SDL_GetError()});
        return;
    }

    simgui.newFrame(.{
        .width = w,
        .height = w,
        .delta_time = platform.getCurrentDeltaTime(),
        .dpi_scale = getDpiScale(),
    });
}

pub fn renderImgui() void {
    simgui.render();
}

pub fn exit() void {
    var event: c.SDL_Event = .{
        .quit = .{
            .type = c.SDL_EVENT_QUIT,
            .timestamp = c.SDL_GetTicksNS(),
        },
    };
    _ = c.SDL_PushEvent(&event);
}

pub fn getDpiScale() f32 {
    const primary_display_id = c.SDL_GetPrimaryDisplay();
    return c.SDL_GetDisplayContentScale(primary_display_id);
}

///////////////////////////////////////////////////////////////////////////////

fn imguiHandleEvent(event: *c.SDL_Event) bool {
    const io = cimgui.igGetIO();
    switch (event.type) {
        c.SDL_EVENT_WINDOW_FOCUS_GAINED => {
            simgui.addFocusEvent(true);
        },
        c.SDL_EVENT_WINDOW_FOCUS_LOST => {
            simgui.addFocusEvent(false);
        },
        // c.SDL_EVENT_WINDOW_MOUSE_ENTER => {},
        // c.SDL_EVENT_WINDOW_MOUSE_LEAVE => {},
        c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
            imguiAddMouseButtonEvent(&event.button, true);
        },
        c.SDL_EVENT_MOUSE_BUTTON_UP => {
            imguiAddMouseButtonEvent(&event.button, false);
        },
        c.SDL_EVENT_MOUSE_MOTION => {
            const dpi = getDpiScale();
            simgui.addMousePosEvent(event.motion.x / dpi, event.motion.y / dpi);
        },
        c.SDL_EVENT_MOUSE_WHEEL => {
            const dpi = getDpiScale();
            simgui.addMousePosEvent(event.wheel.mouse_x / dpi, event.wheel.mouse_y / dpi);
            simgui.addMouseWheelEvent(event.wheel.x, event.wheel.y);
        },
        c.SDL_EVENT_TEXT_INPUT => {
            simgui.addInputCharactersUtf8(std.mem.span(event.text.text));
        },
        c.SDL_EVENT_KEY_DOWN => {
            if (!event.key.repeat) {
                imguiAddKeyEvent(&event.key);
            }
        },
        c.SDL_EVENT_KEY_UP => {
            imguiAddKeyEvent(&event.key);
        },
        else => {},
    }
    return io.*.WantCaptureKeyboard or io.*.WantCaptureMouse;
}

fn imguiSetPlatformImeData(_: [*c]cimgui.ImGuiViewport, data: [*c]cimgui.ImGuiPlatformImeData) callconv(.C) void {
    if (data.*.WantVisible) {
        if (!c.SDL_StartTextInput(window)) {
            debug.err("Failed to initiate text input: {s}", .{c.SDL_GetError()});
        }
    } else {
        _ = c.SDL_StopTextInput(window);
    }
}

fn imguiAddMouseButtonEvent(ev: *c.SDL_MouseButtonEvent, pressed: bool) void {
    const dpi = getDpiScale();
    const mouse_button: i32 = switch (ev.button) {
        c.SDL_BUTTON_LEFT => 0,
        c.SDL_BUTTON_RIGHT => 1,
        c.SDL_BUTTON_MIDDLE => 2,
        else => return,
    };
    simgui.addMousePosEvent(ev.x / dpi, ev.y / dpi);
    simgui.addMouseButtonEvent(mouse_button, pressed);
}

fn imguiUpdateModifierKeys(ev: *c.SDL_KeyboardEvent) void {
    const io = cimgui.igGetIO();
    cimgui.ImGuiIO_AddKeyEvent(io, cimgui.ImGuiMod_Ctrl, (ev.mod & c.SDL_KMOD_CTRL) != 0);
    cimgui.ImGuiIO_AddKeyEvent(io, cimgui.ImGuiMod_Shift, (ev.mod & c.SDL_KMOD_SHIFT) != 0);
    cimgui.ImGuiIO_AddKeyEvent(io, cimgui.ImGuiMod_Alt, (ev.mod & c.SDL_KMOD_ALT) != 0);
    cimgui.ImGuiIO_AddKeyEvent(io, cimgui.ImGuiMod_Super, (ev.mod & c.SDL_KMOD_GUI) != 0);
}

fn imguiAddKeyEvent(ev: *c.SDL_KeyboardEvent) void {
    var keycode = cimgui.ImGuiKey_None;
    keycode = switch (ev.key) {
        c.SDLK_SPACE => cimgui.ImGuiKey_Space,
        c.SDLK_APOSTROPHE => cimgui.ImGuiKey_Apostrophe,
        c.SDLK_COMMA => cimgui.ImGuiKey_Comma,
        c.SDLK_MINUS => cimgui.ImGuiKey_Minus,
        c.SDLK_PERIOD => cimgui.ImGuiKey_Period,
        c.SDLK_SLASH => cimgui.ImGuiKey_Slash,
        c.SDLK_0 => cimgui.ImGuiKey_0,
        c.SDLK_1 => cimgui.ImGuiKey_1,
        c.SDLK_2 => cimgui.ImGuiKey_2,
        c.SDLK_3 => cimgui.ImGuiKey_3,
        c.SDLK_4 => cimgui.ImGuiKey_4,
        c.SDLK_5 => cimgui.ImGuiKey_5,
        c.SDLK_6 => cimgui.ImGuiKey_6,
        c.SDLK_7 => cimgui.ImGuiKey_7,
        c.SDLK_8 => cimgui.ImGuiKey_8,
        c.SDLK_9 => cimgui.ImGuiKey_9,
        c.SDLK_SEMICOLON => cimgui.ImGuiKey_Semicolon,
        c.SDLK_EQUALS => cimgui.ImGuiKey_Equal,
        c.SDLK_A => cimgui.ImGuiKey_A,
        c.SDLK_B => cimgui.ImGuiKey_B,
        c.SDLK_C => cimgui.ImGuiKey_C,
        c.SDLK_D => cimgui.ImGuiKey_D,
        c.SDLK_E => cimgui.ImGuiKey_E,
        c.SDLK_F => cimgui.ImGuiKey_F,
        c.SDLK_G => cimgui.ImGuiKey_G,
        c.SDLK_H => cimgui.ImGuiKey_H,
        c.SDLK_I => cimgui.ImGuiKey_I,
        c.SDLK_J => cimgui.ImGuiKey_J,
        c.SDLK_K => cimgui.ImGuiKey_K,
        c.SDLK_L => cimgui.ImGuiKey_L,
        c.SDLK_M => cimgui.ImGuiKey_M,
        c.SDLK_N => cimgui.ImGuiKey_N,
        c.SDLK_O => cimgui.ImGuiKey_O,
        c.SDLK_P => cimgui.ImGuiKey_P,
        c.SDLK_Q => cimgui.ImGuiKey_Q,
        c.SDLK_R => cimgui.ImGuiKey_R,
        c.SDLK_S => cimgui.ImGuiKey_S,
        c.SDLK_T => cimgui.ImGuiKey_T,
        c.SDLK_U => cimgui.ImGuiKey_U,
        c.SDLK_V => cimgui.ImGuiKey_V,
        c.SDLK_W => cimgui.ImGuiKey_W,
        c.SDLK_X => cimgui.ImGuiKey_X,
        c.SDLK_Y => cimgui.ImGuiKey_Y,
        c.SDLK_Z => cimgui.ImGuiKey_Z,
        c.SDLK_LEFTBRACKET => cimgui.ImGuiKey_LeftBracket,
        c.SDLK_BACKSLASH => cimgui.ImGuiKey_Backslash,
        c.SDLK_RIGHTBRACKET => cimgui.ImGuiKey_RightBracket,
        c.SDLK_GRAVE => cimgui.ImGuiKey_GraveAccent,
        // c.SDLK_WORLD_1 => cimgui.ImGuiKey_WORLD_1,
        // c.SDLK_WORLD_2 => cimgui.ImGuiKey_WORLD_2,
        c.SDLK_ESCAPE => cimgui.ImGuiKey_Escape,
        c.SDLK_RETURN => cimgui.ImGuiKey_Enter,
        c.SDLK_TAB => cimgui.ImGuiKey_Tab,
        c.SDLK_BACKSPACE => cimgui.ImGuiKey_Backspace,
        c.SDLK_INSERT => cimgui.ImGuiKey_Insert,
        c.SDLK_DELETE => cimgui.ImGuiKey_Delete,
        c.SDLK_RIGHT => cimgui.ImGuiKey_RightArrow,
        c.SDLK_LEFT => cimgui.ImGuiKey_LeftArrow,
        c.SDLK_DOWN => cimgui.ImGuiKey_DownArrow,
        c.SDLK_UP => cimgui.ImGuiKey_UpArrow,
        c.SDLK_PAGEUP => cimgui.ImGuiKey_PageUp,
        c.SDLK_PAGEDOWN => cimgui.ImGuiKey_PageDown,
        c.SDLK_HOME => cimgui.ImGuiKey_Home,
        c.SDLK_END => cimgui.ImGuiKey_End,
        c.SDLK_CAPSLOCK => cimgui.ImGuiKey_CapsLock,
        c.SDLK_SCROLLLOCK => cimgui.ImGuiKey_ScrollLock,
        c.SDLK_NUMLOCKCLEAR => cimgui.ImGuiKey_NumLock,
        c.SDLK_PRINTSCREEN => cimgui.ImGuiKey_PrintScreen,
        c.SDLK_PAUSE => cimgui.ImGuiKey_Pause,
        c.SDLK_F1 => cimgui.ImGuiKey_F1,
        c.SDLK_F2 => cimgui.ImGuiKey_F2,
        c.SDLK_F3 => cimgui.ImGuiKey_F3,
        c.SDLK_F4 => cimgui.ImGuiKey_F4,
        c.SDLK_F5 => cimgui.ImGuiKey_F5,
        c.SDLK_F6 => cimgui.ImGuiKey_F6,
        c.SDLK_F7 => cimgui.ImGuiKey_F7,
        c.SDLK_F8 => cimgui.ImGuiKey_F8,
        c.SDLK_F9 => cimgui.ImGuiKey_F9,
        c.SDLK_F10 => cimgui.ImGuiKey_F10,
        c.SDLK_F11 => cimgui.ImGuiKey_F11,
        c.SDLK_F12 => cimgui.ImGuiKey_F12,
        c.SDLK_F13 => cimgui.ImGuiKey_F13,
        c.SDLK_F14 => cimgui.ImGuiKey_F14,
        c.SDLK_F15 => cimgui.ImGuiKey_F15,
        c.SDLK_F16 => cimgui.ImGuiKey_F16,
        c.SDLK_F17 => cimgui.ImGuiKey_F17,
        c.SDLK_F18 => cimgui.ImGuiKey_F18,
        c.SDLK_F19 => cimgui.ImGuiKey_F19,
        c.SDLK_F20 => cimgui.ImGuiKey_F20,
        c.SDLK_F21 => cimgui.ImGuiKey_F21,
        c.SDLK_F22 => cimgui.ImGuiKey_F22,
        c.SDLK_F23 => cimgui.ImGuiKey_F23,
        c.SDLK_F24 => cimgui.ImGuiKey_F24,
        // c.SDLK_F25 => cimgui.ImGuiKey_F25,
        c.SDLK_KP_0 => cimgui.ImGuiKey_Keypad0,
        c.SDLK_KP_1 => cimgui.ImGuiKey_Keypad1,
        c.SDLK_KP_2 => cimgui.ImGuiKey_Keypad2,
        c.SDLK_KP_3 => cimgui.ImGuiKey_Keypad3,
        c.SDLK_KP_4 => cimgui.ImGuiKey_Keypad4,
        c.SDLK_KP_5 => cimgui.ImGuiKey_Keypad5,
        c.SDLK_KP_6 => cimgui.ImGuiKey_Keypad6,
        c.SDLK_KP_7 => cimgui.ImGuiKey_Keypad7,
        c.SDLK_KP_8 => cimgui.ImGuiKey_Keypad8,
        c.SDLK_KP_9 => cimgui.ImGuiKey_Keypad9,
        c.SDLK_KP_DECIMAL => cimgui.ImGuiKey_KeypadDecimal,
        c.SDLK_KP_DIVIDE => cimgui.ImGuiKey_KeypadDivide,
        c.SDLK_KP_MULTIPLY => cimgui.ImGuiKey_KeypadMultiply,
        c.SDLK_KP_MINUS => cimgui.ImGuiKey_KeypadSubtract,
        c.SDLK_KP_PLUS => cimgui.ImGuiKey_KeypadAdd,
        c.SDLK_KP_ENTER => cimgui.ImGuiKey_KeypadEnter,
        c.SDLK_KP_EQUALS => cimgui.ImGuiKey_KeypadEqual,
        c.SDLK_LSHIFT => cimgui.ImGuiKey_LeftShift,
        c.SDLK_LCTRL => cimgui.ImGuiKey_LeftCtrl,
        c.SDLK_LALT => cimgui.ImGuiKey_LeftAlt,
        c.SDLK_LGUI => cimgui.ImGuiKey_LeftSuper,
        c.SDLK_RSHIFT => cimgui.ImGuiKey_RightShift,
        c.SDLK_RCTRL => cimgui.ImGuiKey_RightCtrl,
        c.SDLK_RALT => cimgui.ImGuiKey_RightAlt,
        c.SDLK_RGUI => cimgui.ImGuiKey_RightSuper,
        c.SDLK_MENU => cimgui.ImGuiKey_Menu,
        else => cimgui.ImGuiKey_None,
    };
    imguiUpdateModifierKeys(ev);
    simgui.addKeyEvent(keycode, ev.down);
}

fn sdlkToKeyCode(ev: *c.SDL_KeyboardEvent) input.KeyCodes {
    var keycode = input.KeyCodes.INVALID;
    keycode = switch (ev.key) {
        c.SDLK_SPACE => .SPACE,
        c.SDLK_APOSTROPHE => .APOSTROPHE,
        c.SDLK_COMMA => .COMMA,
        c.SDLK_MINUS => .MINUS,
        c.SDLK_PERIOD => .PERIOD,
        c.SDLK_SLASH => .SLASH,
        c.SDLK_0 => ._0,
        c.SDLK_1 => ._1,
        c.SDLK_2 => ._2,
        c.SDLK_3 => ._3,
        c.SDLK_4 => ._4,
        c.SDLK_5 => ._5,
        c.SDLK_6 => ._6,
        c.SDLK_7 => ._7,
        c.SDLK_8 => ._8,
        c.SDLK_9 => ._9,
        c.SDLK_SEMICOLON => .SEMICOLON,
        c.SDLK_EQUALS => .EQUAL,
        c.SDLK_A => .A,
        c.SDLK_B => .B,
        c.SDLK_C => .C,
        c.SDLK_D => .D,
        c.SDLK_E => .E,
        c.SDLK_F => .F,
        c.SDLK_G => .G,
        c.SDLK_H => .H,
        c.SDLK_I => .I,
        c.SDLK_J => .J,
        c.SDLK_K => .K,
        c.SDLK_L => .L,
        c.SDLK_M => .M,
        c.SDLK_N => .N,
        c.SDLK_O => .O,
        c.SDLK_P => .P,
        c.SDLK_Q => .Q,
        c.SDLK_R => .R,
        c.SDLK_S => .S,
        c.SDLK_T => .T,
        c.SDLK_U => .U,
        c.SDLK_V => .V,
        c.SDLK_W => .W,
        c.SDLK_X => .X,
        c.SDLK_Y => .Y,
        c.SDLK_Z => .Z,
        c.SDLK_LEFTBRACKET => .LEFT_BRACKET,
        c.SDLK_BACKSLASH => .BACKSLASH,
        c.SDLK_RIGHTBRACKET => .RIGHT_BRACKET,
        c.SDLK_GRAVE => .GRAVE_ACCENT,
        // c.SDLK_WORLD_1 => .WORLD_1,
        // c.SDLK_WORLD_2 => .WORLD_2,
        c.SDLK_ESCAPE => .ESCAPE,
        c.SDLK_RETURN => .ENTER,
        c.SDLK_TAB => .TAB,
        c.SDLK_BACKSPACE => .BACKSPACE,
        c.SDLK_INSERT => .INSERT,
        c.SDLK_DELETE => .DELETE,
        c.SDLK_RIGHT => .RIGHT,
        c.SDLK_LEFT => .LEFT,
        c.SDLK_DOWN => .DOWN,
        c.SDLK_UP => .UP,
        c.SDLK_PAGEUP => .PAGE_UP,
        c.SDLK_PAGEDOWN => .PAGE_DOWN,
        c.SDLK_HOME => .HOME,
        c.SDLK_END => .END,
        c.SDLK_CAPSLOCK => .CAPS_LOCK,
        c.SDLK_SCROLLLOCK => .SCROLL_LOCK,
        c.SDLK_NUMLOCKCLEAR => .NUM_LOCK,
        c.SDLK_PRINTSCREEN => .PRINT_SCREEN,
        c.SDLK_PAUSE => .PAUSE,
        c.SDLK_F1 => .F1,
        c.SDLK_F2 => .F2,
        c.SDLK_F3 => .F3,
        c.SDLK_F4 => .F4,
        c.SDLK_F5 => .F5,
        c.SDLK_F6 => .F6,
        c.SDLK_F7 => .F7,
        c.SDLK_F8 => .F8,
        c.SDLK_F9 => .F9,
        c.SDLK_F10 => .F10,
        c.SDLK_F11 => .F11,
        c.SDLK_F12 => .F12,
        c.SDLK_F13 => .F13,
        c.SDLK_F14 => .F14,
        c.SDLK_F15 => .F15,
        c.SDLK_F16 => .F16,
        c.SDLK_F17 => .F17,
        c.SDLK_F18 => .F18,
        c.SDLK_F19 => .F19,
        c.SDLK_F20 => .F20,
        c.SDLK_F21 => .F21,
        c.SDLK_F22 => .F22,
        c.SDLK_F23 => .F23,
        c.SDLK_F24 => .F24,
        // c.SDLK_F25 => .F25,
        c.SDLK_KP_0 => .KP_0,
        c.SDLK_KP_1 => .KP_1,
        c.SDLK_KP_2 => .KP_2,
        c.SDLK_KP_3 => .KP_3,
        c.SDLK_KP_4 => .KP_4,
        c.SDLK_KP_5 => .KP_5,
        c.SDLK_KP_6 => .KP_6,
        c.SDLK_KP_7 => .KP_7,
        c.SDLK_KP_8 => .KP_8,
        c.SDLK_KP_9 => .KP_9,
        c.SDLK_KP_DECIMAL => .KP_DECIMAL,
        c.SDLK_KP_DIVIDE => .KP_DIVIDE,
        c.SDLK_KP_MULTIPLY => .KP_MULTIPLY,
        c.SDLK_KP_MINUS => .KP_SUBTRACT,
        c.SDLK_KP_PLUS => .KP_ADD,
        c.SDLK_KP_ENTER => .KP_ENTER,
        c.SDLK_KP_EQUALS => .KP_EQUAL,
        c.SDLK_LSHIFT => .LEFT_SHIFT,
        c.SDLK_LCTRL => .LEFT_CONTROL,
        c.SDLK_LALT => .LEFT_ALT,
        c.SDLK_LGUI => .LEFT_SUPER,
        c.SDLK_RSHIFT => .RIGHT_SHIFT,
        c.SDLK_RCTRL => .RIGHT_CONTROL,
        c.SDLK_RALT => .RIGHT_ALT,
        c.SDLK_RGUI => .RIGHT_SUPER,
        c.SDLK_MENU => .MENU,
        else => .INVALID,
    };

    return keycode;
}
