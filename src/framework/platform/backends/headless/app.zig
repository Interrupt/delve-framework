const std = @import("std");
const main_app = @import("../../../app.zig");
const platform = @import("../../app.zig");
const debug = @import("../../../debug.zig");
const input = @import("../../input.zig");

var app_config: main_app.AppConfig = undefined;

pub const NullAppConfig = struct {
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

    should_quit: bool = false,

    pub fn init(cfg: NullAppConfig) void {
        debug.log("Creating Headless App backend", .{});

        app = App{
            .on_init_fn = cfg.on_init_fn,
            .on_frame_fn = cfg.on_frame_fn,
            .on_cleanup_fn = cfg.on_cleanup_fn,
            .on_resize_fn = cfg.on_resize_fn,
        };
    }

    pub fn deinit() void {
        debug.log("Headless App Backend stopping", .{});
    }

    pub fn startMainLoop(config: main_app.AppConfig) void {
        app_config = config;

        debug.log("Headless app starting main loop", .{});

        // Always set a target fps
        if (config.target_fps == null) {
            platform.setTargetFPS(60);
        }

        app.on_init_fn();

        while (!app.should_quit) {
            // should tick at a fixed rate here
            app.on_frame_fn();
        }

        app.on_cleanup_fn();
    }

    pub fn getWidth() i32 {
        return 1024;
    }

    pub fn getHeight() i32 {
        return 768;
    }

    pub fn captureMouse(captured: bool) void {
        _ = captured;
    }

    pub fn getClipboardSize() ?i32 {
        return null;
    }

    pub fn startImguiFrame() void {}

    pub fn renderImgui() void {}

    pub fn exit() void {
        app.should_quit = true;
    }
};
