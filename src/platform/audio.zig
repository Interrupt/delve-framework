const std = @import("std");
const zaudio = @import("zaudio");
const debug = @import("../debug.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

var zaudio_engine: ?*zaudio.Engine = null;

/// A sound that is loaded and can be adjusted
pub const Sound = struct {
    // if this was loaded as music or not
    is_music: bool = false,

    // the actual zaudio sound. don't muck with this directly!
    zaudio_sound: ?*zaudio.Sound,

    /// Destroys and cleans up this sound
    pub fn destroy(self: *Sound) void {
        if(self.zaudio_sound) |sound|
           sound.destroy();

        self.zaudio_sound = null;
    }

    /// Starts playing this sound
    pub fn start(self: *Sound) void {
        if(self.zaudio_sound) |sound| {
            sound.start() catch {
                debug.log("Could not start sound!", .{});
                return;
            };
        }
    }

    /// Stops this sound
    pub fn stop(self: *Sound) void {
        if(self.zaudio_sound) |sound| {
            sound.stop() catch {
                debug.log("Could not stop sound!", .{});
                return;
            };
        }
    }

    /// Makes this sound loop, default is to not
    pub fn setLooping(self: *Sound, looping: bool) void {
        if(self.zaudio_sound) |sound| {
            sound.setLooping(looping);
        }
    }

    /// Sets the volume for this sound
    pub fn setVolume(self: *Sound, volume: f32) void {
        if(self.zaudio_sound) |sound| {
            sound.setVolume(volume);
        }
    }

    /// Sets the pitch for this sound
    pub fn setPitch(self: *Sound, pitch: f32) void {
        if(self.zaudio_sound) |sound| {
            sound.setPitch(pitch);
        }
    }

    /// Sets the panning for this sound
    pub fn setPan(self: *Sound, pan: f32) void {
        if(self.zaudio_sound) |sound| {
            sound.setPan(pan);
        }
    }

    /// Sets the position of this sound
    pub fn setPosition(self: *Sound, pos: [3]f32) f32 {
        if(self.zaudio_sound) |sound| {
            // Make sure this sound is spatialized! Will be absolute by default
            if(sound.getPositioning() != zaudio.Positioning.relative)
                sound.setPositioning(zaudio.Positioning.relative);

            sound.setPosition(pos);
        }
    }

    /// Sets the velocity of this sound
    pub fn setVelocity(self: *Sound, vel: [3]f32) f32 {
        if(self.zaudio_sound) |sound| {
            sound.setVelocity(vel);
        }
    }

    /// Gets if the sound is playing
    pub fn getIsPlaying(self: *Sound) bool {
        if(self.zaudio_sound) |sound| {
            return sound.isPlaying();
        }
        return false;
    }

    /// Whether or not the sound has played all the way through
    pub fn getIsDone(self: *Sound) bool {
        if(self.zaudio_sound) |sound| {
            return sound.isAtEnd();
        }
        return false;
    }

    /// Gets if the sound is looping
    pub fn getLooping(self: *Sound) bool {
        if(self.zaudio_sound) |sound| {
            return sound.getLooping();
        }
        return false;
    }

    /// Gets the current volume
    pub fn getVolume(self: *Sound) f32 {
        if(self.zaudio_sound) |sound| {
            return sound.getVolume();
        }
        return 1.0;
    }

    /// Gets the current pitch
    pub fn getPitch(self: *Sound) f32 {
        if(self.zaudio_sound) |sound| {
            return sound.getPitch();
        }
        return 1.0;
    }

    /// Gets the current pan
    pub fn getPan(self: *Sound) f32 {
        if(self.zaudio_sound) |sound| {
            return sound.getPan();
        }
        return 1.0;
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

/// Sets the position of our listener for spatial audio
pub fn setListenerPosition(pos: [3]f32) void {
   if(zaudio_engine) |engine| {
        engine.setListenerPosition(pos);
    }
}

/// Sets the direction of our listener for spatial audio
pub fn setListenerDirection(dir: [3]f32) void {
   if(zaudio_engine) |engine| {
        engine.setListenerDirection(dir);
    }
}

/// Sets the velocity of our listener for spatial audio
pub fn setListenerVelocity(vel: [3]f32) void {
   if(zaudio_engine) |engine| {
        engine.setListenerVelocity(vel);
    }
}

/// Sets the 'up' value for the listener
pub fn setListenerWorldUp(up: [3]f32) void {
   if(zaudio_engine) |engine| {
        engine.setListenerWorldUp(up);
    }
}

/// Enables spatial audio
pub fn enableSpatialAudio() void {
    if(zaudio_engine) |engine| {
        engine.setListenerEnabled(true);
    }
}
