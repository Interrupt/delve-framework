const std = @import("std");
const debug = @import("../../debug.zig");
const app = @import("../../app.zig");
const platform = @import("../app.zig");
const input = @import("../input.zig");

const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const simgui = sokol.imgui;

var app_config: app.AppConfig = undefined;
var hooks: platform.PlatformHooks = undefined;

pub fn init(cfg: platform.PlatformHooks) void {
    debug.log("Initializing Sokol App backend", .{});
    hooks = cfg;
}

pub fn deinit() void {
    debug.log("Deinitializing Sokol App Backend", .{});
    app_config = undefined;
    hooks = undefined;
}

export fn sokol_init() void {
    debug.log("Sokol app context initializing", .{});

    // TODO: Put the buffer pool size and the shader pool size into a config
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
        .buffer_pool_size = app_config.buffer_pool_size, // sokol default is 128
        .shader_pool_size = app_config.shader_pool_size, // sokol default is 64
        .image_pool_size = app_config.image_pool_size, // sokol default is 128
        .pipeline_pool_size = app_config.pipeline_pool_size, // sokol default is 64
        .sampler_pool_size = app_config.sampler_pool_size, // sokol default is 64
        .attachments_pool_size = app_config.pass_pool_size, // sokol default is 16,
    });

    simgui.setup(.{
        .logger = .{ .func = slog.func },
    });

    debug.log("Sokol setup backend: {}", .{sg.queryBackend()});

    // call the callback that will tell everything else to start up
    hooks.on_init_fn();
}

export fn sokol_cleanup() void {
    hooks.on_cleanup_fn();
    sg.shutdown();
}

export fn sokol_frame() void {
    hooks.on_frame_fn();
}

export fn sokol_input(event: ?*const sapp.Event) void {
    const ev = event.?;

    const imgui_did_handle = simgui.handleEvent(ev.*);
    if (imgui_did_handle)
        return;

    if (ev.type == .MOUSE_DOWN) {
        input.onMouseDown(@intFromEnum(ev.mouse_button));
    } else if (ev.type == .MOUSE_UP) {
        input.onMouseUp(@intFromEnum(ev.mouse_button));
    } else if (ev.type == .MOUSE_MOVE) {
        input.onMouseMoved(ev.mouse_x, ev.mouse_y, ev.mouse_dx, ev.mouse_dy);
    } else if (ev.type == .KEY_DOWN) {
        if (!ev.key_repeat)
            input.onKeyDown(@intFromEnum(ev.key_code));
    } else if (ev.type == .KEY_UP) {
        input.onKeyUp(@intFromEnum(ev.key_code));
    } else if (ev.type == .CHAR) {
        input.onKeyChar(ev.char_code);
    } else if (ev.type == .TOUCHES_BEGAN) {
        for (ev.touches) |touch| {
            if (touch.changed)
                input.onTouchBegin(touch.pos_x, touch.pos_y, touch.identifier);
        }
    } else if (ev.type == .TOUCHES_MOVED) {
        for (ev.touches) |touch| {
            if (touch.changed)
                input.onTouchMoved(touch.pos_x, touch.pos_y, touch.identifier);
        }
    } else if (ev.type == .TOUCHES_ENDED) {
        for (ev.touches) |touch| {
            if (touch.changed)
                input.onTouchEnded(touch.pos_x, touch.pos_y, touch.identifier);
        }
    }
}

pub fn startMainLoop(config: app.AppConfig) void {
    app_config = config;

    debug.log("Sokol app starting main loop", .{});

    sapp.run(.{
        .init_cb = sokol_init,
        .frame_cb = sokol_frame,
        .cleanup_cb = sokol_cleanup,
        .event_cb = sokol_input,
        .width = config.width,
        .height = config.height,
        .icon = .{
            .sokol_default = true,
        },
        .window_title = config.title,
        .logger = .{
            .func = slog.func,
        },
        // .win32_console_attach = true,
    });
}

pub fn getWidth() i32 {
    return sapp.width();
}

pub fn getHeight() i32 {
    return sapp.height();
}

pub fn captureMouse(captured: bool) void {
    sapp.lockMouse(captured);
}

pub fn startImguiFrame() void {
    simgui.newFrame(.{
        .width = sapp.width(),
        .height = sapp.height(),
        .delta_time = sapp.frameDuration(),
        .dpi_scale = sapp.dpiScale(),
    });
}

pub fn renderImgui() void {
    simgui.render();
}

pub fn exit() void {
    sapp.quit();
}

pub fn getDpiScale() f32 {
    sapp.dpiScale();
}
