const std = @import("std");
const debug = @import("debug.zig");
const images = @import("images.zig");
const meshes = @import("graphics/mesh.zig");
const modules = @import("modules.zig");
const colors = @import("colors.zig");
const fonts = @import("fonts.zig");
const scripting = @import("scripting/manager.zig");

// Main systems
const app_backend = @import("platform/app.zig");
const input = @import("platform/input.zig");
const audio = @import("platform/audio.zig");

pub var assets_path: [:0]const u8 = "assets";

pub const AppConfig = struct {
    title: [:0]const u8 = "Delve Framework",

    width: i32 = 960,
    height: i32 = 540,

    enable_audio: bool = false,

    target_fps: ?i32 = null,
    use_fixed_timestep: bool = false,
    fixed_timestep_delta: f32 = 1.0 / 60.0,

    // maximum sizes for graphics buffers
    buffer_pool_size: i32 = 512,
    shader_pool_size: i32 = 512,
    pipeline_pool_size: i32 = 512,
    image_pool_size: i32 = 256,
    sampler_pool_size: i32 = 128,
    pass_pool_size: i32 = 32,
};

var app_config: AppConfig = undefined;

pub fn setAssetsPath(path: [:0]const u8) !void {
    assets_path = path;
}

pub fn start(config: AppConfig) !void {
    app_config = config;

    debug.init();

    debug.log("Delve Framework Starting!", .{});

    // App backend init
    try app_backend.init();

    // TODO: Handle how the assets path works!

    // Change the working dir to where the assets are
    // debug.log("Assets Path: {s}", .{assets_path});
    // const chdir_res = std.c.chdir(assets_path);
    // if (chdir_res == -1) return error.Oops;

    // Kick off the game loop! This will also start and stop the subsystems.
    debug.log("Main loop starting", .{});
    app_backend.startMainLoop(config);
}

pub fn startSubsystems() !void {
    try images.init();
    try colors.init();
    try input.init();
    try fonts.init();
    try meshes.init();

    if (app_config.enable_audio)
        try audio.init();
}

pub fn stopSubsystems() void {
    modules.deinit();
    colors.deinit();
    input.deinit();
    fonts.deinit();
    meshes.deinit();
    images.deinit();

    if (app_config.enable_audio)
        audio.deinit();
}
