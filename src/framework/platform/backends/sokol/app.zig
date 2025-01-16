const std = @import("std");
const main_app = @import("../../../app.zig");
const debug = @import("../../../debug.zig");
// const gfx = @import("graphics.zig");
const input = @import("../../input.zig");
// const modules = @import("../modules.zig");

const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const simgui = sokol.imgui;

var app_config: main_app.AppConfig = undefined;

pub const SokolAppConfig = struct {
    on_init_fn: *const fn () void,
    on_frame_fn: *const fn () void,
    on_cleanup_fn: *const fn () void,
    on_resize_fn: *const fn () void,
    // maybe an on_event fn?
};

// keep a static version of the app around
var app: App = undefined;

pub const App = struct {
    on_init_fn: *const fn () void,
    on_frame_fn: *const fn () void,
    on_cleanup_fn: *const fn () void,
    on_resize_fn: *const fn () void,

    pub fn init(cfg: SokolAppConfig) void {
        debug.log("Creating Sokol App backend", .{});

        app = App{
            .on_init_fn = cfg.on_init_fn,
            .on_frame_fn = cfg.on_frame_fn,
            .on_cleanup_fn = cfg.on_cleanup_fn,
            .on_resize_fn = cfg.on_resize_fn,
        };
    }

    pub fn deinit() void {
        debug.log("Sokol App Backend stopping", .{});
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
        app.on_init_fn();
    }

    export fn sokol_cleanup() void {
        app.on_cleanup_fn();
        sg.shutdown();
    }

    export fn sokol_frame() void {
        app.on_frame_fn();
    }

    export fn sokol_input(event: ?*const sapp.Event) void {
        const ev = event.?;

        const imgui_did_handle = simgui.handleEvent(ev.*);
        if (imgui_did_handle)
            return;

        switch (ev.type) {
            .MOUSE_DOWN => {
                input.onMouseDown(@intFromEnum(ev.mouse_button));
            },
            .MOUSE_UP => {
                input.onMouseUp(@intFromEnum(ev.mouse_button));
            },
            .MOUSE_MOVE => {
                input.onMouseMoved(ev.mouse_x, ev.mouse_y, ev.mouse_dx, ev.mouse_dy);
            },
            .KEY_DOWN => {
                if (!ev.key_repeat)
                    input.onKeyDown(@intFromEnum(ev.key_code));
            },
            .KEY_UP => {
                input.onKeyUp(@intFromEnum(ev.key_code));
            },
            .CHAR => {
                input.onKeyChar(ev.char_code);
            },
            .TOUCHES_BEGAN => {
                for (ev.touches) |touch| {
                    if (touch.changed)
                        input.onTouchBegin(touch.pos_x, touch.pos_y, touch.identifier);
                }
            },
            .TOUCHES_MOVED => {
                for (ev.touches) |touch| {
                    if (touch.changed)
                        input.onTouchMoved(touch.pos_x, touch.pos_y, touch.identifier);
                }
            },
            .TOUCHES_ENDED => {
                for (ev.touches) |touch| {
                    if (touch.changed)
                        input.onTouchEnded(touch.pos_x, touch.pos_y, touch.identifier);
                }
            },
            .RESIZED => {
                app.on_resize_fn();
            },
            else => {},
        }
    }

    pub fn startMainLoop(config: main_app.AppConfig) void {
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
};

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
