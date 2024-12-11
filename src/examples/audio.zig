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
    audio.setListenerPosition(delve.math.Vec3.zero);
    audio.setListenerDirection(delve.math.Vec3.z_axis.scale(-1));
    audio.setListenerWorldUp(delve.math.Vec3.y_axis);

    music_test = audio.playSound("assets/sample-9s.mp3", .{
        .volume = 0.5,
        .stream = true,
        .loop = true,
        .position = delve.math.Vec3.new(0, 0, 0), // could also set .is_3d = true
        .distance_rolloff = 0.5,
    });

    graphics.setClearColor(colors.light_grey);
}

fn on_tick(delta: f32) void {
    _ = delta;

    const mouse_pos = input.getMousePosition();
    const app_width: f32 = @floatFromInt(delve.platform.app.getWidth());
    const app_height: f32 = @floatFromInt(delve.platform.app.getHeight());

    if (input.isMouseButtonJustPressed(input.MouseButtons.LEFT)) {
        sound_test = audio.playSound("assets/sample-shoot.wav", .{ .volume = 0.1 });
    }

    audio.setListenerPosition(delve.math.Vec3.new(
        ((mouse_pos.x / app_width) * 32.0) - 16.0,
        ((mouse_pos.y / app_height) * -32.0) + 16.0,
        0,
    ));

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
