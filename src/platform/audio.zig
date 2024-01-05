const std = @import("std");
const zaudio = @import("zaudio");
const debug = @import("../debug.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

var zaudio_engine: ?*zaudio.Engine = null;

/// A sound that is loaded and can be adjusted
pub const Sound = struct {
    is_playing: bool = false,
    is_music: bool = false,
    is_looping: bool = false,
    volume: f32 = 1.0,
    pitch: f32 = 1.0,
    pan: f32 = 1.0,

    // the actual zaudio sound. don't muck with this directly!
    zaudio_sound: ?*zaudio.Sound,

    /// Destroys and cleans up this sound
    pub fn destroy(self: *Sound) void {
        if(self.zaudio_sound) |sound|
           sound.destroy();
    }

    /// Starts playing this sound
    pub fn start(self: *Sound) void {
        if(self.zaudio_sound) |sound| {
            sound.start() catch {
                debug.log("Could not start sound!", .{});
                return;
            };
            self.is_playing = true;
        }
    }

    /// Stops this sound
    pub fn stop(self: *Sound) void {
        if(self.zaudio_sound) |sound| {
            sound.stop() catch {
                debug.log("Could not stop sound!", .{});
                return;
            };
            self.is_playing = false;
        }
    }

    /// Makes this sound loop, default is to not
    pub fn setLooping(self: *Sound, looping: bool) void {
        if(self.zaudio_sound) |sound| {
            sound.setLooping(looping);
            self.is_looping = true;
        }
    }

    /// Sets the volume for this sound
    pub fn setVolume(self: *Sound, volume: f32) void {
        if(self.zaudio_sound) |sound| {
            sound.setVolume(volume);
            self.volume = volume;
        }
    }

    /// Sets the pitch for this sound
    pub fn setPitch(self: *Sound, pitch: f32) void {
        if(self.zaudio_sound) |sound| {
            sound.setPitch(pitch);
            self.pitch = pitch;
        }
    }

    /// Sets the panning for this sound
    pub fn setPan(self: *Sound, pan: f32) void {
        if(self.zaudio_sound) |sound| {
            sound.setPan(pan);
            self.pan = pan;
        }
    }
};

/// Starts the audio subsystem
pub fn init() !void {
    debug.log("Audio system initializing", .{});

    zaudio.init(allocator);
    zaudio_engine = try zaudio.Engine.create(null);
}

/// Stops and cleans up the audio subsystem
pub fn deinit() void {
    if(zaudio_engine) |engine|
        engine.destroy();

    zaudio.deinit();
}

/// Loads and plays a piece of music
pub fn playMusic(filename: [:0]const u8, volume: f32, loop: bool) ?Sound {
    var sound = loadSound(filename, true) catch {
        debug.log("Could not load music file! ({s})", .{ filename });
        return null;
    };

    sound.setVolume(volume);
    sound.setLooping(loop);
    sound.start();

    return sound;
}

/// Loads and plays a sound effect
pub fn playSound(filename: [:0]const u8, volume: f32) ?Sound {
    var sound = loadSound(filename, false) catch {
        debug.log("Could not load sound file! ({s})", .{ filename });
        return null;
    };

    sound.setVolume(volume);
    sound.start();

    return sound;
}

/// Loads a sound. Streaming is best for longer samples like music
pub fn loadSound(filename: [:0]const u8, stream: bool) !Sound {
    const zaudio_sound = try zaudio_engine.?.createSoundFromFile(
        filename,
        .{ .flags = .{ .stream = stream, .async_load = true } },
    );

    return Sound { .zaudio_sound = zaudio_sound };
}
