const std = @import("std");
const zaudio = @import("zaudio");
const debug = @import("../debug.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

var zaudio_engine: ?*zaudio.Engine = null;

pub const Sound = struct {
    is_music: bool = false,
    zaudio_sound: *zaudio.Sound,

    pub fn destroy(self: *Sound) void {
        self.zaudio_sound.destroy();
    }
};

pub fn init() !void {
    debug.log("Audio system initializing", .{});

    zaudio.init(allocator);
    zaudio_engine = try zaudio.Engine.create(null);
}

pub fn deinit() void {
    if(zaudio_engine) |engine|
        engine.destroy();

    zaudio.deinit();
}

pub fn playMusic(filename: [:0]const u8, volume: f32) ?Sound {
    const zaudio_sound = zaudio_engine.?.createSoundFromFile(
        filename,
        .{ .flags = .{ .stream = true, .async_load = true } },
    ) catch {
        debug.log("Could not load music file!", .{});
        return null;
    };

    zaudio_sound.setVolume(volume);

    zaudio_sound.start() catch {
        debug.log("Could not start music!", .{});
        return null;
    };

    return Sound { .is_music = true, .zaudio_sound = zaudio_sound };
}

pub fn playSound(filename: [:0]const u8, volume: f32) ?Sound {
    const zaudio_sound = zaudio_engine.?.createSoundFromFile(
        filename,
        .{ .flags = .{ .async_load = true } },
    ) catch {
        debug.log("Could not load sound file!", .{});
        return null;
    };

    zaudio_sound.setVolume(volume);

    zaudio_sound.start() catch {
        debug.log("Could not start sound!", .{});
        return null;
    };

    return Sound { .zaudio_sound = zaudio_sound };
}
