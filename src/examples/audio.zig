const std = @import("std");
const builtin = @import("builtin");
const delve = @import("delve");
const app = delve.app;

const audio = delve.platform.audio;
const colors = delve.colors;
const debug = delve.debug;
const graphics = delve.platform.graphics;
const input = delve.platform.input;
const modules = delve.modules;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

var music_test: ?audio.Sound = null;
var sound_test: ?audio.Sound = null;

// -- This example shows off the the audio paths --

pub fn main() !void {
    // Pick the allocator to use depending on platform
    if (builtin.os.tag == .wasi or builtin.os.tag == .emscripten) {
        // Web builds hack: use the C allocator to avoid OOM errors
        // See https://github.com/ziglang/zig/issues/19072
        try delve.init(std.heap.c_allocator);
    } else {
        try delve.init(gpa.allocator());
    }

    try registerModule();

    // make sure to set enable_audio to true when starting!
    try app.start(app.AppConfig{ .title = "Delve Framework - Sprite Batch Example", .enable_audio = true });
}

pub fn registerModule() !void {
    const audioExample = modules.Module{
        .name = "audio_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .draw_fn = on_draw,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(audioExample);
}

fn on_init() !void {
    debug.log("Audio example module initializing", .{});

    audio.enableSpatialAudio(true);
    audio.setListenerPosition(.{ 0.0, 0.0, 0.0 });
    audio.setListenerDirection(.{ 1.0, 0.0, 0.0 });
    audio.setListenerWorldUp(.{ 0.0, 1.0, 0.0 });

    music_test = audio.playMusic("assets/sample-9s.mp3", 0.5, true);

    graphics.setClearColor(colors.light_grey);

    if (music_test != null) {
        music_test.?.setPosition(.{ -1.0, 0.0, 3.0 }, .{ 1.0, 0.0, 0.0 }, .{ 0.0, 0.0, 0.0 });
    }
}

fn on_tick(delta: f32) void {
    _ = delta;

    if (input.isMouseButtonJustPressed(input.MouseButtons.LEFT)) {
        sound_test = audio.playSound("assets/sample-shoot.wav", 0.1);
    }

    if (input.isKeyJustPressed(.ESCAPE))
        delve.platform.app.exit();
}

fn on_draw() void {
    graphics.setDebugTextScale(1);
    graphics.setDebugTextColor(colors.Color.new(0.6, 0.6, 0.6, 1.0));
    graphics.drawDebugText(4, 8, "Music should be playing.");
    graphics.drawDebugText(4, 32, "Click to play sounds.");
}

fn on_cleanup() !void {
    debug.log("Audio example module cleaning up", .{});

    // This would get cleaned up automatically, but we can request it too
    if (music_test != null) {
        music_test.?.requestDestroy();
    }
}
