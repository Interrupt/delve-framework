const std = @import("std");
const app = @import("../app.zig");
const audio = @import("../platform/audio.zig");
const debug = @import("../debug.zig");
const modules = @import("../modules.zig");

var music_test: ?audio.Sound = null;
var sound_test: ?audio.Sound = null;

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

    music_test = audio.playMusic("sample-9s.mp3", 0.25);
    // sound_test = audio.playSound("sample-9s.mp3", 0.25);
}

fn on_tick(tick: u64) void {
    _ = tick;
}

fn on_cleanup() void {
    debug.log("Audio example module cleaning up", .{});

    if(music_test != null)
        music_test.?.destroy();

    if(sound_test != null)
        sound_test.?.destroy();
}
