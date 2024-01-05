const std = @import("std");
const app = @import("../app.zig");
const debug = @import("../debug.zig");
const modules = @import("../modules.zig");
const zaudio = @import("zaudio");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

var audio_engine: ?*zaudio.Engine = null;
var music_sample: ?*zaudio.Sound = null;

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

    zaudio.init(allocator);
    audio_engine = zaudio.Engine.create(null) catch {
        debug.log("Could not initialise audio engine!", .{});
        return;
    };

    music_sample = audio_engine.?.createSoundFromFile(
        "sample-9s.mp3",
        .{ .flags = .{ .stream = true, .async_load = true } },
    ) catch {
        debug.log("Could not load sound file!", .{});
        return;
    };

    music_sample.?.setVolume(0.25);
    music_sample.?.setPitch(1.0);
    music_sample.?.setLooping(true);

    music_sample.?.start() catch {
        debug.log("Could not start music sample!", .{});
    };
}

fn on_tick(tick: u64) void {
    _ = tick;
}

fn on_cleanup() void {
    debug.log("Audio example module cleaning up", .{});

    if(music_sample) |music|
        music.destroy();

    if(audio_engine) |engine|
        engine.destroy();

    zaudio.deinit();
}
