const std = @import("std");
const app = @import("../app.zig");
const audio = @import("../platform/audio.zig");
const input = @import("../platform/input.zig");
const debug = @import("../debug.zig");
const modules = @import("../modules.zig");

var music_test: ?audio.Sound = null;
var sound_test: ?audio.Sound = null;

// -- This is a module that exercises the audio paths --

pub fn registerModule() !void {
    const audioExample = modules.Module {
        .name = "audio_example",
        .init_fn = on_init,
        .tick_fn = on_tick,
        .cleanup_fn = on_cleanup,
    };

    try modules.registerModule(audioExample);
}

fn on_init() void {
    debug.log("Audio example module initializing", .{});

    audio.enableSpatialAudio(true);
    audio.setListenerPosition(.{0.0, 0.0, 0.0});
    audio.setListenerDirection(.{1.0, 0.0, 0.0});
    audio.setListenerWorldUp(.{0.0, 1.0, 0.0});

    music_test = audio.playMusic("sample-9s.mp3", 0.5, true);

    if(music_test != null) {
        music_test.?.setPosition(.{-1.0, 0.0, 3.0}, .{1.0, 0.0, 0.0}, .{0.0, 0.0, 0.0});
    }
}

fn on_tick(tick: u64) void {
    _ = tick;

    if(input.isMouseButtonJustPressed(0)) {
        sound_test = audio.playSound("sample-shoot.wav", 0.1);
    }
}

fn on_cleanup() void {
    debug.log("Audio example module cleaning up", .{});

    // This would get cleaned up automatically, but we can request it too
    if(music_test != null) {
        music_test.?.requestDestroy();
    }
}
